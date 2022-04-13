#!/usr/bin/env bash
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

if ! [ -d "${data}" ]; then
	init_args=(--chain-id "${network}")
	if [ -n "${accountid}" ]; then
		init_args+=(--account-id "${accountid}")
	fi

	# Set up genesis
	mkdir -p "${data}" "${data}/data"
	if ! [ "${network}" = "localnet" ]; then
		curl -o "${data}/genesis.json" "${genesis_url}"
	fi

	# Initialize data dir
	"${neard}" --home "${data}" init "${init_args[@]}"

	# Set up genesis and config
	if ! [ "${network}" = "localnet" ]; then
		mkdir -p "${data}" "${data}/data"
		curl -o "${data}/config.json" "${config_url}"
	fi

	# Download database dump to speed up syncing
	if ! [ "${network}" = "localnet" ]; then
		dump_version="$(s5cmd --no-sign-request cat "s3://near-protocol-public/backups/${network}/rpc/latest")"
		s5cmd --no-sign-request cp "s3://near-protocol-public/backups/${network}/rpc/${dump_version}/*" "${data}/data"
	fi
fi

systemd-run --user --pty --unit="neard-${network}" "${neard}" --home "${data}" run

# vim: ft=bash
