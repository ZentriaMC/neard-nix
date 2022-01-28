#!/usr/bin/env nix-shell
#!nix-shell -i bash -p aria2 curl
# shellcheck shell=bash
set -euo pipefail

network="testnet"
accountid=""
data="$(realpath ./data)/node0"

#network="mainnet"
#accountid="zentria.poolv1.near"
#data="$(realpath ./mainnet_data)/node0"

#network="localnet"
#accountid=""
#data="$(realpath ./localnet_data)/node0"

neard="$(realpath -- ./result/bin/neard)"
config_url="https://s3-us-west-1.amazonaws.com/build.nearprotocol.com/nearcore-deploy/${network}/config.json"
genesis_url="https://s3-us-west-1.amazonaws.com/build.nearprotocol.com/nearcore-deploy/${network}/genesis.json"
dump_url="https://near-protocol-public.s3-accelerate.amazonaws.com/backups/${network}/rpc/data.tar"

if ! [ -d "${data}" ]; then
	init_args=(--chain-id "${network}")
	if [ -n "${accountid}" ]; then
		init_args+=(--account-id "${accountid}")
	fi

	# Initialize data dir
	"${neard}" --home "${data}" init "${init_args[@]}"

	# Set up genesis and config
	if ! [ "${network}" = "localnet" ]; then
		mkdir -p "${data}" "${data}/data"
		curl -o "${data}/genesis.json" "${genesis_url}"
		curl -o "${data}/config.json" "${config_url}"
	fi

	# Download database dump to speed up syncing
	if ! [ "${network}" = "localnet" ]; then
		aria2c --dir="${data}" --continue=true --max-connection-per-server=16 --lowest-speed-limit=10M --max-tries=2147483647 "${dump_url}"
		pv "${data}/data.tar" | tar -C "${data}/data" -xf -
		rm "${data}/data.tar"
	fi
fi

systemd-run --user --pty --unit="neard-${network}" "${neard}" --home "${data}" run

# vim: ft=bash
