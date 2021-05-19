#!/usr/bin/env bash
set -euo pipefail

b="$(realpath -- ./result/bin/neard)"

d="$(realpath -- ./data)"
if ! [ -d "${d}" ]; then
	mkdir -p "${d}"
	"${b}" --home "${d}" testnet
fi

pids=()

for home in "${d}"/*; do
	num="$(basename -- "${home}")"
	rpc="127.0.0.1:300${num/node/}"
	net="127.0.0.1:2763${num/node/}"

	bootnodes=()
	if ! [ "${num}" = "node0" ]; then
		bootnodes+=(--boot-nodes "$(jq -r '.public_key' < "${d}"/node0/node_key.json)@127.0.0.1:27630")
	fi

	"${b}" --home "${home}" run --network-addr "${net}" --rpc-addr "${rpc}" "${bootnodes[@]}" &
	pid="${!}"
	pids+=(${pid})
done

wait "${pids[@]}"
