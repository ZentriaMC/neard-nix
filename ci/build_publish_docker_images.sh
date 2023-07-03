#!/usr/bin/env bash
set -euo pipefail

# nix develop .#ci --command "./ci/build_publish_docker_images.sh"

repo="${DOCKER_REPOSITORY:-docker.io/zentria/neard-nix}"
current_system="$(nix-instantiate --eval -E --json 'builtins.currentSystem' | jq -r '.')"
system="${current_system/-darwin/-linux}"
sign_images=0

nix_flags=(
        --extra-experimental-features "nix-command flakes"
        --extra-trusted-public-keys "zentria-near.cachix.org-1:BKvOv13hKSkWX5RZpLs9Da5b5ZCySBdYFWukCvR5YVY="
        --extra-substituters "https://zentria-near.cachix.org"
	--system "${system}"
)

skopeo_flags=(
	--insecure-policy
)

if [ -n "${COSIGN_KEY+x}" ] && [ "${COSIGN_SKIP:-false}" = "false" ]; then
	# we usually have password for cosign key as well, ensure that it's around
	: "${COSIGN_PASSWORD+x}"

	sum="$(COSIGN_PASSWORD="$(echo -n "${COSIGN_PASSWORD}" | base64 -d)" cosign public-key --key <(echo -n "${COSIGN_KEY}" | base64 -d) | sha256sum - | cut -d' ' -f1)"
	echo "Signing images with key '${sum}' (sha256)"

	sign_images=1
fi

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

	digest_file="./digest.txt"
	skopeo_image_args=(
		--digestfile "${digest_file}"
		docker-archive:"${tarball}"
		"docker://${repo}:${tag}"
	)

	skopeo "${skopeo_flags[@]}" copy "${skopeo_image_args[@]}"

	if (( sign_images )); then
		annotations=(
			-a "repo=${Z_GITHUB_REPO:-unset}"
			-a "workflow=${Z_GITHUB_WORKFLOW:-unset}"
			-a "ref=${Z_GITHUB_REF:-unset}"
		)

		COSIGN_PASSWORD="$(echo -n "${COSIGN_PASSWORD}" | base64 -d)" cosign sign \
			--key <(echo -n "${COSIGN_KEY}" | base64 -d) \
			--tlog-upload=false \
			"${annotations[@]}" \
			"${repo}@$(< "${digest_file}")"
	fi
done
