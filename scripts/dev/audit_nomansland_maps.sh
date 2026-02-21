#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "${ROOT_DIR}"

EXPECTED_SBASE_SORTED='["c1","c2","c3","c4","c5","l2","l3","l4","l5","l6","p1h1","p2h6","r1","r2","r3","r4","r5"]'
EXPECTED_GBASE_SORTED='["c1","c2","c3","c4","l2","l3","l4","l5","p1h1","p2h5","r1","r2","r3","r4"]'
EXPECTED_SN6_SORTED='["npc1","npc2","npc3","npc4","npc5","p1h1","p1h2","p1h3","p1h4","p1h5","p1h6","p2h1","p2h2","p2h3","p2h4","p2h5","p2h6"]'

fail_count=0
warn_count=0

fail() {
	local msg="$1"
	echo "[FAIL] ${msg}"
	fail_count=$((fail_count + 1))
}

warn() {
	local msg="$1"
	echo "[WARN] ${msg}"
	warn_count=$((warn_count + 1))
}

json_get() {
	local file="$1"
	shift
	jq -er "$@" "${file}" 2>/dev/null
}

base_file_for_variant() {
	local variant_id="$1"
	local search_dirs=(
		"maps/nomansland"
		"maps/_future/nomansland"
	)
	local base_id=""
	if [[ "${variant_id}" == *__TB ]]; then
		base_id="${variant_id%__TB}"
	elif [[ "${variant_id}" == *__T ]]; then
		base_id="${variant_id%__T}"
	elif [[ "${variant_id}" == *__B ]]; then
		base_id="${variant_id%__B}"
	else
		return 1
	fi
	for dir in "${search_dirs[@]}"; do
		if [[ -f "${dir}/${base_id}.json" ]]; then
			echo "${dir}/${base_id}.json"
			return 0
		fi
	done
	return 1
}

expected_kind_owner_for_variant_node() {
	local suffix="$1"
	local node_id="$2"
	case "${suffix}" in
		T)
			case "${node_id}" in
				l2) echo "tower|P1"; return 0 ;;
				r5) echo "tower|P2"; return 0 ;;
			esac
			;;
		B)
			case "${node_id}" in
				l4) echo "barracks|P1"; return 0 ;;
				r3) echo "barracks|P2"; return 0 ;;
			esac
			;;
		TB)
			case "${node_id}" in
				l2) echo "tower|P1"; return 0 ;;
				r5) echo "tower|P2"; return 0 ;;
				l4) echo "barracks|P1"; return 0 ;;
				r3) echo "barracks|P2"; return 0 ;;
			esac
			;;
	esac
	return 1
}

validate_variant_integrity() {
	local file="$1"
	local id="$2"
	local suffix="$3"
	local base_file
	if ! base_file="$(base_file_for_variant "${id}")"; then
		fail "${file}: variant ${id} has no matching base file"
		return
	fi

	local grid_v grid_b defaults_v defaults_b occ_v occ_b pos_v pos_b
	grid_v="$(json_get "${file}" '.grid | @json')" || { fail "${file}: invalid .grid"; return; }
	grid_b="$(json_get "${base_file}" '.grid | @json')" || { fail "${base_file}: invalid .grid"; return; }
	defaults_v="$(json_get "${file}" '.defaults | @json')" || { fail "${file}: invalid .defaults"; return; }
	defaults_b="$(json_get "${base_file}" '.defaults | @json')" || { fail "${base_file}: invalid .defaults"; return; }
	occ_v="$(json_get "${file}" '.occluders | @json')" || { fail "${file}: invalid .occluders"; return; }
	occ_b="$(json_get "${base_file}" '.occluders | @json')" || { fail "${base_file}: invalid .occluders"; return; }
	pos_v="$(json_get "${file}" '[.nodes[] | {id, pos}] | @json')" || { fail "${file}: invalid node positions"; return; }
	pos_b="$(json_get "${base_file}" '[.nodes[] | {id, pos}] | @json')" || { fail "${base_file}: invalid node positions"; return; }
	if [[ "${grid_v}" != "${grid_b}" ]]; then
		fail "${file}: .grid differs from base ${base_file}"
	fi
	if [[ "${defaults_v}" != "${defaults_b}" ]]; then
		fail "${file}: .defaults differs from base ${base_file}"
	fi
	if [[ "${occ_v}" != "${occ_b}" ]]; then
		fail "${file}: .occluders differs from base ${base_file}"
	fi
	if [[ "${pos_v}" != "${pos_b}" ]]; then
		fail "${file}: node positions/order differ from base ${base_file}"
	fi

	local node_ids
	node_ids="$(jq -r '.nodes[].id' "${base_file}")"
	while IFS= read -r node_id; do
		[[ -z "${node_id}" ]] && continue
		local base_kind base_owner var_kind var_owner
		base_kind="$(json_get "${base_file}" --arg id "${node_id}" '.nodes[] | select(.id==$id) | .kind')" || { fail "${base_file}: missing node ${node_id}"; continue; }
		base_owner="$(json_get "${base_file}" --arg id "${node_id}" '.nodes[] | select(.id==$id) | .owner')" || { fail "${base_file}: missing owner ${node_id}"; continue; }
		var_kind="$(json_get "${file}" --arg id "${node_id}" '.nodes[] | select(.id==$id) | .kind')" || { fail "${file}: missing node ${node_id}"; continue; }
		var_owner="$(json_get "${file}" --arg id "${node_id}" '.nodes[] | select(.id==$id) | .owner')" || { fail "${file}: missing owner ${node_id}"; continue; }

		if expected="$(expected_kind_owner_for_variant_node "${suffix}" "${node_id}" 2>/dev/null)"; then
			local exp_kind="${expected%%|*}"
			local exp_owner="${expected##*|}"
			if [[ "${var_kind}" != "${exp_kind}" || "${var_owner}" != "${exp_owner}" ]]; then
				fail "${file}: node ${node_id} expected ${exp_kind}/${exp_owner}, got ${var_kind}/${var_owner}"
			fi
		else
			if [[ "${var_kind}" != "${base_kind}" || "${var_owner}" != "${base_owner}" ]]; then
				fail "${file}: node ${node_id} changed unexpectedly (${base_kind}/${base_owner} -> ${var_kind}/${var_owner})"
			fi
		fi
	done <<< "${node_ids}"
}

files=()
while IFS= read -r line; do
	files+=("${line}")
done < <(find maps/nomansland maps/_future/nomansland -maxdepth 1 -type f -name 'MAP_nomansland__*.json' | sort)

if [[ "${#files[@]}" -eq 0 ]]; then
	echo "No nomansland map files found."
	exit 0
fi

for file in "${files[@]}"; do
	if ! jq empty "${file}" >/dev/null 2>&1; then
		fail "${file}: invalid JSON"
		continue
	fi

	file_id="$(basename "${file}" .json)"
	id="$(json_get "${file}" '.id')"
	family="$(json_get "${file}" '.family')"
	mode="$(json_get "${file}" '.mode')"
	if [[ "${id}" != "${file_id}" ]]; then
		fail "${file}: id (${id}) does not match filename (${file_id})"
	fi
	if [[ "${family}" != "nomansland" ]]; then
		fail "${file}: family should be nomansland, got ${family}"
	fi
	if [[ "${mode}" != "1p" ]]; then
		warn "${file}: mode expected 1p for current nomansland set, got ${mode}"
	fi

	dupe_ok="$(json_get "${file}" '([.nodes[].id] | length) == ([.nodes[].id] | unique | length)')"
	if [[ "${dupe_ok}" != "true" ]]; then
		fail "${file}: duplicate node ids"
	fi

	actual_sorted="$(json_get "${file}" '[.nodes[].id] | sort | @json')"
	left_count="$(json_get "${file}" '[.nodes[] | select(.id|test("^l[0-9]+$"))] | length')"
	right_count="$(json_get "${file}" '[.nodes[] | select(.id|test("^r[0-9]+$"))] | length')"

	if [[ "${id}" == *"__GBASE__"* ]]; then
		if [[ "${actual_sorted}" != "${EXPECTED_GBASE_SORTED}" ]]; then
			fail "${file}: GBASE node-id set mismatch (likely extra/missing hive)"
		fi
		if [[ "${left_count}" != "4" || "${right_count}" != "4" ]]; then
			fail "${file}: GBASE expected 4 left and 4 right rail nodes, got L=${left_count} R=${right_count}"
		fi
	elif [[ "${id}" =~ __SN[0-9]+__1p($|__) ]]; then
		if [[ "${actual_sorted}" != "${EXPECTED_SN6_SORTED}" ]]; then
			fail "${file}: SN* node-id set mismatch"
		fi
	elif [[ "${id}" == *"__SBASE__"* ]]; then
		if [[ "${actual_sorted}" != "${EXPECTED_SBASE_SORTED}" ]]; then
			fail "${file}: SBASE node-id set mismatch"
		fi
		if [[ "${left_count}" != "5" || "${right_count}" != "5" ]]; then
			fail "${file}: SBASE expected 5 left and 5 right rail nodes, got L=${left_count} R=${right_count}"
		fi
	fi

	if [[ "${id}" == *__TB ]]; then
		validate_variant_integrity "${file}" "${id}" "TB"
	elif [[ "${id}" == *__T ]]; then
		validate_variant_integrity "${file}" "${id}" "T"
	elif [[ "${id}" == *__B ]]; then
		validate_variant_integrity "${file}" "${id}" "B"
	fi
done

echo "Nomansland audit complete: files=${#files[@]} warnings=${warn_count} failures=${fail_count}"
if [[ "${fail_count}" -gt 0 ]]; then
	exit 1
fi
