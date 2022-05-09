#!/usr/bin/env bash
set -euo pipefail

# nix develop .#ci --command "./ci/build_publish_cache.sh"

: "${CACHIX_AUTH_TOKEN}"

nix_flags=(
	--extra-experimental-features "nix-command flakes"
	--extra-trusted-public-keys "zentria-near.cachix.org-1:BKvOv13hKSkWX5RZpLs9Da5b5ZCySBdYFWukCvR5YVY="
	--extra-substituters "https://zentria-near.cachix.org"
)

root="$(git rev-parse --show-toplevel)"
cache="zentria-near"
drvs=(
	neard.cargoDeps
	neard
	neard-rc.cargoDeps
	neard-rc
)

# Push Flake inputs to cache
nix flake archive --json \
	| jq -r '.path,(.inputs|to_entries[].value.path)' \
	| cachix push "${cache}"


for drv in "${drvs[@]}"; do
	echo ">>> Building '${drv}'"
	nix "${nix_flags[@]}" build -L --json "${root}#${drv}" \
		| jq -r '.[].outputs | to_entries[].value' \
		| cachix push "${cache}"
done
