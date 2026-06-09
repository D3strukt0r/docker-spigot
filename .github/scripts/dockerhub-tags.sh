#!/usr/bin/env bash
#
# Print all tag names of a PUBLIC Docker Hub repository as a JSON array,
# following pagination. Returns [] if the repo doesn't exist yet (e.g. right
# after a wipe), so callers can treat "everything is missing".
#
# Usage: dockerhub-tags.sh <namespace/repo>
#   .github/scripts/dockerhub-tags.sh d3strukt0r/spigot
#
# Used by docker.yml's `missing` selector to diff the buildable set against
# what's already published.
set -euo pipefail

repo="${1:?usage: dockerhub-tags.sh <namespace/repo>}"
url="https://hub.docker.com/v2/repositories/${repo}/tags?page_size=100"
out='[]'

while [ -n "$url" ] && [ "$url" != null ]; do
  resp="$(curl -fsSL "$url" 2>/dev/null)" || break   # 404 (no repo) → stop, return what we have
  names="$(jq -c '[.results[]?.name]' <<<"$resp" 2>/dev/null || echo '[]')"
  out="$(jq -nc --argjson a "$out" --argjson b "$names" '$a + $b')"
  url="$(jq -r '.next // ""' <<<"$resp" 2>/dev/null || echo '')"
done

jq -cn --argjson a "$out" '$a | unique'
