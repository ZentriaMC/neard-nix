#!/usr/bin/env bash
set -euo pipefail

# nix develop .#ci --command "./ci/build_publish_docker_images.sh"

repo="${DOCKER_REPOSITORY:-ghcr.io/zentriamc/neard-nix/neard}"
current_system="$(nix-instantiate --eval -E --json 'builtins.currentSystem' | jq -r '.')"
system="${current_system/-darwin/-linux}"

nix_flags=(
        --extra-experimental-features "nix-command flakes"
        --extra-trusted-public-keys "zentria-near.cachix.org-1:BKvOv13hKSkWX5RZpLs9Da5b5ZCySBdYFWukCvR5YVY="
        --extra-substituters "https://zentria-near.cachix.org"
	--system "${system}"
)

skopeo_flags=(
	--insecure-policy
)

if ! [ "${current_system}" = "${system}" ]; then
	echo ">>> Building for '${system}' on '${current_system}'"
	nix_flags+=(--max-jobs 0)
	skopeo_flags+=(--override-os linux)
fi

root="$(git rev-parse --show-toplevel)"
drvs=(
        neardDockerImage
        neardRcDockerImage
)

for drv in "${drvs[@]}"; do
	tag="$(nix-instantiate --argstr system "${system}" --argstr drv "${drv}" --eval --json -E '{ system, drv }: let flake = builtins.getFlake (toString ./.); in flake.packages.${system}.${drv}.imageTag' | jq -r '.')"
	tarball="$(nix "${nix_flags[@]}" build -L --json "${root}#${drv}" | jq -r '.[] | .outputs.out')"
	skopeo "${skopeo_flags[@]}" copy docker-archive:"${tarball}" "docker://${repo}:${tag}"
done
