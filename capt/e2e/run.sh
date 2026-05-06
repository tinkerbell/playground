#!/usr/bin/env bash
# Matrix test orchestrator for the CAPT playground.
#
# Loops over user-selected combos, generates config.yaml via CUE,
# creates/validates/deletes the playground for each combo, and prints
# a summary table.
#
# Usage:
#   ./e2e/run.sh [FLAGS] [COMBO ...| all]
#   ./e2e/run.sh --cleanup
#
# Flags:
#   --list             List available combos and exit
#   --cleanup          Delete any active playground and restore config.yaml
#   --labels FILTER    Ginkgo --label-filter (default: "provisioning")
#   --artifacts DIR    Artifact directory (default: e2e/artifacts)
#   --spares N         Override spare VM count (default: 0)
#   --mirror-host HOST Registry mirror hostname (required for mirror combos)
#   --no-teardown     Keep the playground running after tests complete
#   --dry-run          Render configs and print what would run, but skip task/ginkgo
#
# Examples:
#   ./e2e/run.sh --list
#   ./e2e/run.sh single-nomirror-netboot
#   ./e2e/run.sh --labels "provisioning" --mirror-host reg.example.com all

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CAPT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
E2E_DIR="$SCRIPT_DIR"
BIN_DIR="$CAPT_DIR/bin"

# Ginkgo CLI — installed to the same bin/ as other tools
GINKGO_VERSION="v2.28.1"
GINKGO="$BIN_DIR/ginkgo"

ensure_ginkgo() {
	local versioned="$BIN_DIR/ginkgo-$GINKGO_VERSION"
	if [[ ! -x $versioned ]]; then
		echo "Installing ginkgo $GINKGO_VERSION to $BIN_DIR"
		GOBIN="$BIN_DIR" go install "github.com/onsi/ginkgo/v2/ginkgo@$GINKGO_VERSION"
		mv "$BIN_DIR/ginkgo" "$versioned"
	fi
	ln -sf "ginkgo-$GINKGO_VERSION" "$GINKGO"
}

# Defaults
LABELS="provisioning"
ARTIFACTS_DIR="$E2E_DIR/artifacts"
SPARES=0
MIRROR_HOST=""
DRY_RUN=false
NO_TEARDOWN=false
COMBOS=()

# --- Argument parsing ---

while [[ $# -gt 0 ]]; do
	case "$1" in
	-h | --help)
		cat <<'EOF'
Usage: ./e2e/run.sh [FLAGS] [COMBO ...| all]
       ./e2e/run.sh --cleanup
       ./e2e/run.sh --list

Flags:
  -h, --help           Show this help and exit
  --list               List available combos and exit
  --cleanup            Delete any active playground and restore config.yaml
  --labels FILTER      Ginkgo --label-filter (default: "provisioning")
  --artifacts DIR      Artifact directory (default: e2e/artifacts)
  --spares N           Override spare VM count (default: 0)
  --mirror-host HOST   Registry mirror hostname (required for mirror combos)
  --no-teardown        Keep the playground running after tests complete
  --dry-run            Render configs and print what would run, but skip task/ginkgo

Examples:
  ./e2e/run.sh --list
  ./e2e/run.sh single-nomirror-netboot
  ./e2e/run.sh --no-teardown single-nomirror-netboot
  ./e2e/run.sh --labels "provisioning" --mirror-host reg.example.com all
  ./e2e/run.sh --cleanup
EOF
		exit 0
		;;
	--list)
		cd "$CAPT_DIR"
		cue eval ./e2e/cue -e comboNames --out json | jq -r '.[]'
		exit 0
		;;
	--cleanup)
		echo "Cleaning up playground and restoring config..."
		cd "$CAPT_DIR"
		if ! task delete-playground 2>&1; then
			echo "WARN: 'task delete-playground' exited non-zero ($?); continuing cleanup." >&2
		fi
		if [[ -f "$CAPT_DIR/config.yaml.e2e-backup" ]]; then
			cp "$CAPT_DIR/config.yaml.e2e-backup" "$CAPT_DIR/config.yaml"
			rm -f "$CAPT_DIR/config.yaml.e2e-backup"
			echo "Restored config.yaml from backup."
		fi
		echo "Cleanup complete."
		exit 0
		;;
	--labels)
		LABELS="$2"
		shift 2
		;;
	--artifacts)
		ARTIFACTS_DIR="$2"
		shift 2
		;;
	--spares)
		SPARES="$2"
		shift 2
		;;
	--mirror-host)
		MIRROR_HOST="$2"
		shift 2
		;;
	--dry-run)
		DRY_RUN=true
		shift
		;;
	--no-teardown)
		NO_TEARDOWN=true
		shift
		;;
	-*)
		echo "Unknown flag: $1" >&2
		exit 1
		;;
	all)
		mapfile -t COMBOS < <(cd "$CAPT_DIR" && cue eval ./e2e/cue -e comboNames --out json | jq -r '.[]')
		shift
		;;
	*)
		COMBOS+=("$1")
		shift
		;;
	esac
done

if [[ ${#COMBOS[@]} -eq 0 ]]; then
	echo "Usage: $0 [FLAGS] [COMBO ...| all]" >&2
	echo "Run '$0 --list' to see available combos." >&2
	exit 1
fi

# --- Setup ---

mkdir -p "$ARTIFACTS_DIR"
ensure_ginkgo

# Back up original config.yaml to a known location so --cleanup can restore it
if [[ -f "$CAPT_DIR/config.yaml" && ! -f "$CAPT_DIR/config.yaml.e2e-backup" ]]; then
	cp "$CAPT_DIR/config.yaml" "$CAPT_DIR/config.yaml.e2e-backup"
fi

# --- Results tracking ---

declare -a RESULT_NAMES=()
declare -a RESULT_STATUS=()
declare -a RESULT_DURATION=()
declare -a RESULT_DETAIL=()

# --- Run combos ---

for COMBO in "${COMBOS[@]}"; do
	echo ""
	echo "================================================================"
	echo "  COMBO: $COMBO"
	echo "================================================================"
	echo ""

	COMBO_ARTIFACTS="$ARTIFACTS_DIR/$COMBO"
	mkdir -p "$COMBO_ARTIFACTS"
	COMBO_START=$(date +%s)

	# --- Step 1: Render config.yaml from CUE ---

	CUE_TAGS=("-t" "spares=$SPARES")
	if [[ -n $MIRROR_HOST ]]; then
		CUE_TAGS+=("-t" "mirrorHost=$MIRROR_HOST")
	fi

	echo "Rendering config for combo: $COMBO"
	cd "$CAPT_DIR"
	if ! cue export ./e2e/cue -e "combos[\"$COMBO\"]" "${CUE_TAGS[@]}" --out yaml >"$COMBO_ARTIFACTS/config.yaml" 2>&1; then
		echo "FAIL: CUE render failed for $COMBO" >&2
		cat "$COMBO_ARTIFACTS/config.yaml" >&2
		RESULT_NAMES+=("$COMBO")
		RESULT_STATUS+=("FAIL")
		RESULT_DURATION+=("$(($(date +%s) - COMBO_START))s")
		RESULT_DETAIL+=("CUE render failed")
		continue
	fi

	cp "$COMBO_ARTIFACTS/config.yaml" "$CAPT_DIR/config.yaml"

	if $DRY_RUN; then
		echo "[dry-run] Would run: task --yes create-playground"
		echo "[dry-run] Config:"
		cat "$CAPT_DIR/config.yaml"
		RESULT_NAMES+=("$COMBO")
		RESULT_STATUS+=("DRY-RUN")
		RESULT_DURATION+=("0s")
		RESULT_DETAIL+=("-")
		continue
	fi

	# --- Step 2: Create playground ---

	COMBO_STATUS="FAIL"
	COMBO_DETAIL=""

	create_ok=false
	echo "Creating playground for combo: $COMBO"
	if task --yes create-playground >"$COMBO_ARTIFACTS/create.log" 2>&1; then
		create_ok=true
	else
		COMBO_DETAIL="playground creation failed"
		cp "$COMBO_ARTIFACTS/create.log" "$COMBO_ARTIFACTS/create-error.log"
	fi

	if $create_ok; then
		# --- Step 3: Extract kubeconfigs from .state ---

		STATE_FILE="$CAPT_DIR/.state"
		MGMT_KC="$(yq eval '.kind.kubeconfig' "$STATE_FILE")"
		TINK_KC=""
		if [[ "$(yq eval '.externalTinkerbell' "$STATE_FILE")" == "true" ]]; then
			TINK_KC="$(yq eval '.kind.tinkerbell.kubeconfig' "$STATE_FILE")"
		fi
		CLUSTER_NAME="$(yq eval '.clusterName' "$STATE_FILE")"
		OUTPUT_DIR="$(yq eval '.outputDir' "$STATE_FILE")"
		WORKLOAD_KC="$OUTPUT_DIR/$CLUSTER_NAME.kubeconfig"
		NS="$(yq eval '.namespace' "$STATE_FILE")"

		# --- Step 4: Wait for workload kubeconfig ---

		echo "Waiting for workload kubeconfig: $WORKLOAD_KC"
		wk_timeout=300
		wk_elapsed=0
		while [[ ! -f $WORKLOAD_KC ]] && ((wk_elapsed < wk_timeout)); do
			sleep 5
			wk_elapsed=$((wk_elapsed + 5))
		done

		if [[ ! -f $WORKLOAD_KC ]]; then
			COMBO_DETAIL="workload kubeconfig not found after ${wk_timeout}s"
		else
			# --- Step 5: Run Ginkgo tests ---

			echo "Running Ginkgo tests (labels: $LABELS)"
			GINKGO_ARGS=(
				-v
				--label-filter="$LABELS"
				--output-dir="$COMBO_ARTIFACTS"
				--junit-report=junit.xml
			)

			E2E_FLAGS=(
				--
				-e2e.config="$E2E_DIR/test/config/e2e.yaml"
				-e2e.artifacts="$COMBO_ARTIFACTS"
				-e2e.mgmt-kubeconfig="$MGMT_KC"
				-e2e.workload-kubeconfig="$WORKLOAD_KC"
				-e2e.namespace="$NS"
			)
			if [[ -n $TINK_KC ]]; then
				E2E_FLAGS+=(-e2e.tink-kubeconfig="$TINK_KC")
			fi

			if (cd "$E2E_DIR/test" && "$GINKGO" "${GINKGO_ARGS[@]}" ./... "${E2E_FLAGS[@]}") >"$COMBO_ARTIFACTS/ginkgo.log" 2>&1; then
				COMBO_STATUS="PASS"
				COMBO_DETAIL=""
			else
				COMBO_DETAIL="ginkgo tests failed"
			fi
		fi
	fi

	# --- Step 7: Delete playground (unless --no-teardown) ---

	if $NO_TEARDOWN; then
		echo ""
		echo "################################################################"
		echo "# --no-teardown: leaving playground RUNNING for combo: $COMBO"
		echo "# Resources (VMs, kind clusters, BMC container) will persist."
		echo "# Clean up manually with: ./e2e/run.sh --cleanup"
		echo "################################################################"
	else
		echo "Deleting playground for combo: $COMBO"
		if ! task delete-playground >"$COMBO_ARTIFACTS/delete.log" 2>&1; then
			rc=$?
			echo "WARN: teardown failed for $COMBO (exit $rc); see $COMBO_ARTIFACTS/delete.log" >&2
			COMBO_DETAIL="${COMBO_DETAIL:+$COMBO_DETAIL; }teardown failed (exit $rc)"
		fi
	fi

	# --- Record result ---

	COMBO_END=$(date +%s)
	COMBO_ELAPSED="$((COMBO_END - COMBO_START))s"
	RESULT_NAMES+=("$COMBO")
	RESULT_STATUS+=("$COMBO_STATUS")
	RESULT_DURATION+=("$COMBO_ELAPSED")
	RESULT_DETAIL+=("${COMBO_DETAIL:-OK}")
done

# --- Summary ---

echo ""
echo "================================================================"
echo "  MATRIX RESULTS"
echo "================================================================"
echo ""
printf "%-35s %-8s %-10s %s\n" "COMBO" "RESULT" "DURATION" "DETAIL"
printf "%-35s %-8s %-10s %s\n" "-----" "------" "--------" "------"

EXIT_CODE=0
for i in "${!RESULT_NAMES[@]}"; do
	printf "%-35s %-8s %-10s %s\n" \
		"${RESULT_NAMES[$i]}" \
		"${RESULT_STATUS[$i]}" \
		"${RESULT_DURATION[$i]}" \
		"${RESULT_DETAIL[$i]}"
	if [[ ${RESULT_STATUS[$i]} == "FAIL" ]]; then
		EXIT_CODE=1
	fi
done

# Restore original config.yaml and remove backup after a full run
if [[ -f "$CAPT_DIR/config.yaml.e2e-backup" ]]; then
	cp "$CAPT_DIR/config.yaml.e2e-backup" "$CAPT_DIR/config.yaml"
	rm -f "$CAPT_DIR/config.yaml.e2e-backup"
fi

echo ""
exit "$EXIT_CODE"
