#!/usr/bin/env bash
# Renders the e2e matrix job summary as markdown on stdout.
#
# Usage: e2e-summary.sh <artifacts-dir>
#
# The artifacts directory holds one e2e-<combination>/ per matrix job, as
# download-artifact lays them out. Per-spec detail comes from the report.json
# ginkgo already writes into every artifact, so the matrix jobs upload nothing
# for the sake of this summary.
#
# Environment:
#   COMBINATIONS     JSON array of the combinations the plan job scheduled
#   REQUESTED        the combination(s) the dispatch asked for
#   TINKERBELL_REPO  inputs.tinkerbell_repo, empty when using released artifacts
#   TINKERBELL_REF   inputs.tinkerbell_ref
#   CHART_VERSION    inputs.chart_version, empty when the runner resolved it
#   GITHUB_*         supplied by the runner

set -euo pipefail

# A report node counts as a spec when it is an It; anything else is only
# interesting when it failed, which is how a BeforeSuite blowup gets reported
# instead of vanishing from the table.
readonly JQ_LIB='
  def icon: {passed:"✅",failed:"❌",panicked:"💥",skipped:"⏭️",pending:"⏸️",aborted:"🛑",interrupted:"🛑"}[.] // "❔";
  def bad: .State | IN("failed","panicked","aborted","interrupted");
  def dur: . as $ns | ($ns/1000000000) as $s
    | if $ns <= 0 then "—"
      elif $s >= 60 then "\(($s/60)|floor)m \(($s - 60*(($s/60)|floor))|floor)s"
      elif $s >= 1 then "\((($s*10)|round)/10)s"
      else "\(($ns/1000000)|round)ms" end;
  def name: ((.ContainerHierarchyTexts // []) + [.LeafNodeText // ""])
    | map(select(. != "")) | join(" › ") | if . == "" then "suite setup" else . end;
  def labels: ((((.ContainerHierarchyLabels // []) | flatten) + (.LeafNodeLabels // []))
    | unique | map("`\(.)`") | join(" "));
  def specs: .[0].SpecReports | map(select(.LeafNodeType == "It" or bad));
'

# passed, failed, skipped, pending, suite runtime in ns, suite runtime for humans
readonly JQ_STATS=$JQ_LIB'
  specs as $x
  | [ ($x | map(select(.State == "passed")) | length),
      ($x | map(select(bad)) | length),
      ($x | map(select(.State == "skipped")) | length),
      ($x | map(select(.State == "pending")) | length),
      .[0].RunTime,
      (.[0].RunTime | dur) ] | @tsv'

readonly JQ_FAILED_NAMES=$JQ_LIB'specs | map(select(bad) | name) | .[]'

readonly JQ_TABLE=$JQ_LIB'
  specs as $x
  | ["| | spec | labels | time |", "|---|---|---|---|"]
    + ($x | map("| \(.State | icon) | \(if bad then "**" + name + "**" else name end) | \(labels) | \(.RunTime | dur) |"))
    + (if (.[0].SuiteConfig.LabelFilter // "") == "" then []
       else ["", "Label filter: `\(.[0].SuiteConfig.LabelFilter)`"] end)
    + ($x | map(select(bad) | ["",
        "**\(name)** — `\(.Failure.Location.FileName | sub(".*/capt/"; ""))`:\(.Failure.Location.LineNumber)",
        "", "```",
        ((.Failure.Message // "no message") | split("\n")[0:25] | join("\n")),
        "```"]) | flatten)
  | .[]'

# Describes what Tinkerbell was installed from, linking the ref when the repo is
# a URL we can build a tree link out of.
function source_cell() {
	if [ -z "${TINKERBELL_REPO:-}" ]; then
		if [ -n "${CHART_VERSION:-}" ]; then
			echo "published chart \`$CHART_VERSION\`"
		else
			# Resolved per run, so the exact version is in each config.yaml.
			echo 'published chart, whatever `latest` pointed at'
		fi
		return
	fi

	case "$TINKERBELL_REPO" in
	http*://*)
		local slug=${TINKERBELL_REPO#*://}
		slug=${slug#*/}
		slug=${slug%.git}
		local cell="built from source — [\`$slug\`]($TINKERBELL_REPO)"
		if [ -n "${TINKERBELL_REF:-}" ]; then
			cell="$cell @ [\`$TINKERBELL_REF\`](${TINKERBELL_REPO%.git}/tree/$TINKERBELL_REF)"
		else
			cell="$cell @ default branch"
		fi
		echo "$cell"
		;;
	*)
		# A local checkout, which only means something on the machine that ran it.
		local cell="built from source — \`$TINKERBELL_REPO\`"
		if [ -n "${TINKERBELL_REF:-}" ]; then cell="$cell @ \`$TINKERBELL_REF\`"; fi
		echo "$cell"
		;;
	esac
}

function spec_counts() {
	local p="$1" f="$2" s="$3" pend="$4" cell=""

	if [ "$p" -gt 0 ]; then cell="$cell $p ✅"; fi
	if [ "$f" -gt 0 ]; then cell="$cell $f ❌"; fi
	if [ "$s" -gt 0 ]; then cell="$cell $s ⏭️"; fi
	if [ "$pend" -gt 0 ]; then cell="$cell $pend ⏸️"; fi
	echo "${cell# }"
}

# Reads parent.key out of a generated config.yaml or state.yaml. Both are two
# levels deep and two-space indented, and this runner has no yq.
function yaml_field() {
	local file="$1" parent="$2" key="$3"

	[ -f "$file" ] || return 0
	awk -v parent="$parent:" -v key="  $key:" '
		$0 == parent { inside = 1; next }
		inside && /^[^ ]/ { inside = 0 }
		inside && index($0, key) == 1 { sub(/^[^:]*: */, ""); print; exit }
	' "$file"
}

# What a combination actually installed, which is a fact about the run rather
# than about the dispatch: `latest` is resolved per job, so two combinations in
# one matrix can differ if main moves between them.
function combo_tinkerbell() {
	local dir="$1" version repo ref chart

	version=$(yaml_field "$dir/state.yaml" source version)
	if [ -n "$version" ]; then
		repo=$(yaml_field "$dir/state.yaml" source repo)
		ref=$(yaml_field "$dir/state.yaml" source ref)
		echo "built \`$version\` from \`${repo:-default repo}\` @ \`${ref:-default branch}\`"
		return
	fi

	# state.yaml is written as the playground comes up, so a run that died
	# before that still has the config it was going to use.
	chart=$(yaml_field "$dir/state.yaml" versions chart)
	[ -n "$chart" ] || chart=$(yaml_field "$dir/config.yaml" versions chart)
	[ -n "$chart" ] || return 0
	echo "chart \`$chart\`"
}

function main() {
	declare -r ARTIFACTS="${1:-artifacts}"
	declare -r ROWS=$(mktemp) DETAIL=$(mktemp) FAILS=$(mktemp) VERSIONS=$(mktemp)

	local total=0 won=0 lost=0 gone=0
	local pass_total=0 fail_total=0 skip_total=0 ns_total=0

	# Driven by the plan's list rather than by what was downloaded, so a
	# combination whose runner died still gets a row.
	for combo in $(jq -r '.[]?' <<<"${COMBINATIONS:-[]}"); do
		total=$((total + 1))
		local dir="$ARTIFACTS/e2e-$combo"

		local outcome=missing job="—"
		if [ -f "$dir/result.tsv" ]; then
			IFS=$'\t' read -r _ outcome job <"$dir/result.tsv"
		fi

		local p=0 f=0 s=0 pend=0 ns=0 spec="—"
		if [ -f "$dir/report.json" ]; then
			IFS=$'\t' read -r p f s pend ns spec < <(jq -r "$JQ_STATS" "$dir/report.json")
		fi
		ns=${ns%%.*}
		pass_total=$((pass_total + p))
		fail_total=$((fail_total + f))
		skip_total=$((skip_total + s + pend))
		ns_total=$((ns_total + ns))

		local mark
		case "$outcome" in
		success)
			won=$((won + 1))
			mark="✅ success"
			;;
		missing)
			gone=$((gone + 1))
			mark="⚠️ no artifact"
			;;
		cancelled | skipped) mark="⚪ $outcome" ;;
		*)
			lost=$((lost + 1))
			mark="❌ $outcome"
			;;
		esac

		local counts tinkerbell
		counts=$(spec_counts "$p" "$f" "$s" "$pend")
		tinkerbell=$(combo_tinkerbell "$dir")
		if [ -n "$tinkerbell" ]; then echo "$tinkerbell" >>"$VERSIONS"; fi

		printf '| [%s](#%s) | %s | %s | %s | %s |\n' \
			"$combo" "$combo" "$mark" "$job" "${counts:-—}" "$spec" >>"$ROWS"

		if [ -f "$dir/report.json" ]; then
			while IFS= read -r spec_name; do
				printf -- '- [%s](#%s) — `%s`\n' "$combo" "$combo" "$spec_name" >>"$FAILS"
			done < <(jq -r "$JQ_FAILED_NAMES" "$dir/report.json")
		fi

		# Collapsed when there is nothing to look at, so an all-green run stays
		# one screen and a broken one opens on the failure.
		local open=""
		if [ "$outcome" != success ]; then open=" open"; fi

		{
			echo
			echo "#### $combo"
			echo
			if [ -n "$tinkerbell" ]; then
				echo "Tinkerbell: $tinkerbell"
				echo
			fi
			if [ -f "$dir/report.json" ]; then
				echo "<details$open><summary>$mark · ${counts:-no specs} · $spec</summary>"
				echo
				jq -r "$JQ_TABLE" "$dir/report.json"
				echo
				echo "Artifact \`e2e-$combo\`: \`ginkgo.log\`, \`create.log\`, \`delete.log\`, \`output/\`, \`report.json\`"
				echo
				echo "</details>"
			elif [ "$outcome" = missing ]; then
				echo "Nothing was uploaded: the runner was cancelled or died before the upload step."
			else
				echo "No ginkgo report in the artifact: the run never reached the test phase."
				echo "Look at \`create.log\` in \`e2e-$combo\`."
			fi
		} >>"$DETAIL"
	done

	local combo_line="$won passed"
	if [ "$lost" -gt 0 ]; then combo_line="$combo_line · $lost failed"; fi
	if [ "$gone" -gt 0 ]; then combo_line="$combo_line · $gone with no artifact"; fi
	combo_line="$combo_line of $total"

	local secs=$((ns_total / 1000000000))
	local spec_line="$pass_total passed"
	if [ "$fail_total" -gt 0 ]; then spec_line="$spec_line · $fail_total failed"; fi
	if [ "$skip_total" -gt 0 ]; then spec_line="$spec_line · $skip_total skipped"; fi
	spec_line="$spec_line — $((secs / 60))m $((secs % 60))s in specs"

	# Read back from the artifacts when every combination agrees, because that
	# names the exact version rather than the dispatch's intent.
	local versions count
	versions=$(sort -u "$VERSIONS")
	count=$(grep -c . <<<"$versions" || true)

	echo "## e2e matrix"
	echo
	echo "| | |"
	echo "|---|---|"
	if [ "$count" -eq 1 ]; then
		echo "| **Tinkerbell** | $versions |"
	elif [ "$count" -gt 1 ]; then
		echo "| **Tinkerbell** | varies by combination — see below |"
	else
		echo "| **Tinkerbell** | $(source_cell) |"
	fi
	echo "| **Playground** | [\`$GITHUB_REF_NAME\`]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/tree/$GITHUB_REF_NAME) (\`${GITHUB_SHA:0:7}\`) |"
	echo "| **Requested** | \`${REQUESTED:-all}\` |"
	echo "| **Combinations** | $combo_line |"
	echo "| **Specs** | $spec_line |"

	if [ -s "$FAILS" ]; then
		echo
		echo "### Failures"
		echo
		cat "$FAILS"
	fi

	echo
	echo "### Combinations"
	echo
	if [ "$total" -eq 0 ]; then
		echo "No combinations ran."
		return
	fi
	echo "| combination | result | job | specs | spec time |"
	echo "|---|---|---|---|---|"
	cat "$ROWS"
	cat "$DETAIL"
}

main "$@"
