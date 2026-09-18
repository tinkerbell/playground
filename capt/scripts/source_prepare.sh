#!/usr/bin/env bash

set -euo pipefail

# Work out which Tinkerbell source tree a playground builds from, and record it.
#
# Everything downstream is keyed on the resolved commit rather than the ref that
# was asked for: `main` moves, a commit does not, so tagging images with the
# commit is what lets a second run discover its images are already published and
# skip the build entirely.
#
# A local repo is treated two different ways on purpose:
#   - with no ref, it is built WHERE IT SITS, so uncommitted work is what gets
#     tested. That is the point of pointing at a working tree.
#   - with a ref, it is cloned into the cache and checked out there. Checking out
#     a ref in someone's working tree would move them off whatever they had.
#
# Resolution is memoised into a file rather than recomputed per lookup: the
# Taskfile reads several of these fields, and each one would otherwise be
# another fetch.
#
# Usage: source_prepare.sh <repo> <ref> <dest-yaml>

declare -r CACHE_DIR="${XDG_CACHE_HOME:-${HOME}/.cache}/capt-playground/src"

# Where a `source:` block that names only a ref builds from.
declare -r DEFAULT_REPO="https://github.com/tinkerbell/tinkerbell"

function cache_dir_for() {
	declare -r repo="$1"

	printf '%s/%s' "$CACHE_DIR" "$(printf '%s' "$repo" | sha256sum | cut -c1-12)"
}

function is_local_repo() {
	declare -r repo="$1"

	[[ -d $repo ]]
}

# Clone once, then fetch. Concurrent playgrounds may resolve the same repo at
# the same moment, and git leaves a half-written tree behind if two of them
# write it at once.
function sync_checkout() {
	declare -r repo="$1" ref="$2" dir="$3"

	mkdir -p "$(dirname "$dir")"

	exec 9>"${dir}.lock"
	flock 9

	if [[ ! -d "${dir}/.git" ]]; then
		rm -rf "$dir"
		git clone --quiet "$repo" "$dir"
	fi

	# A swallowed failure here resolves against whatever the cache last saw, so
	# a moved branch would be reported as a successful run of the wrong commit.
	if ! git -C "$dir" fetch --quiet --force --tags origin '+refs/heads/*:refs/remotes/origin/*'; then
		echo "source: cannot refresh ${repo}; the cached checkout may be stale" >&2
		return 1
	fi

	declare resolved
	if [[ -n $ref ]]; then
		# A branch has to be matched against the remote: the local branch of the
		# same name is whatever the last checkout left behind.
		resolved="$(git -C "$dir" rev-parse --verify --quiet "origin/${ref}^{commit}" ||
			git -C "$dir" rev-parse --verify --quiet "${ref}^{commit}" || true)"

		if [[ -z $resolved ]]; then
			echo "source: cannot resolve ref '${ref}' in ${repo}" >&2
			return 1
		fi
	else
		# No ref means the repo's default branch, which a cached clone is only
		# sitting on until either end moves. set-head re-reads which branch that
		# is, because the symref is written at clone time and not updated since.
		git -C "$dir" remote set-head --auto origin >/dev/null
		resolved="$(git -C "$dir" rev-parse --verify --quiet 'origin/HEAD^{commit}' || true)"

		if [[ -z $resolved ]]; then
			echo "source: cannot resolve the default branch of ${repo}" >&2
			return 1
		fi
	fi
	git -C "$dir" checkout --quiet --detach "$resolved"

	exec 9>&-
}

function worktree_is_dirty() {
	declare -r dir="$1"

	[[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]
}

# The repo owns what a build is called, so ask it rather than reinventing the
# scheme. It reports uncommitted work as `+dirty`, and `+` is not legal in a
# container tag.
function version_of() {
	declare -r dir="$1"

	(cd "$dir" && go run --buildvcs=true ./script/version/) | tr '+' '-'
}

function main() {
	declare -r repo_in="${1:-$DEFAULT_REPO}" ref="$2" dest="$3"

	declare repo dir dirty=false
	if is_local_repo "$repo_in"; then
		repo="$(realpath "$repo_in")"
	else
		repo="$repo_in"
	fi

	if is_local_repo "$repo" && [[ -z $ref ]]; then
		dir="$repo"
		worktree_is_dirty "$dir" && dirty=true
	else
		dir="$(cache_dir_for "$repo")"
		sync_checkout "$repo" "$ref" "$dir"
	fi

	# Assigned separately from `declare`, which returns its own exit status and
	# would otherwise swallow a failure here into an empty version -- and an
	# empty version becomes an image tag of ":".
	declare commit version
	commit="$(git -C "$dir" rev-parse HEAD)"
	version="$(version_of "$dir")"

	if [[ -z $version ]]; then
		echo "source: ${repo} at ${ref:-HEAD} produced no version; too old to build from?" >&2
		return 1
	fi

	mkdir -p "$(dirname "$dest")"
	src_repo="$repo" src_ref="$ref" src_dir="$dir" \
		src_commit="$commit" src_version="$version" src_dirty="$dirty" \
		yq -n '
			.repo = strenv(src_repo) |
			.ref = strenv(src_ref) |
			.dir = strenv(src_dir) |
			.commit = strenv(src_commit) |
			.version = strenv(src_version) |
			.dirty = (strenv(src_dirty) == "true")
		' >"$dest"
}

main "$@"
