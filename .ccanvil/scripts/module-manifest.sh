#!/usr/bin/env bash
# module-manifest.sh — BTS-239 module-manifest substrate.
#
# Verbs:
#   extract <path>   Parse # @manifest blocks → JSON array (one object per block).
#   validate         Walk allowlist, drift-check each entry → exit 0 on clean / 2 on drift.
#   query <expr>     <key>:<value> substring filter against the index.
#   index            Regenerate .ccanvil/state/manifests.json from all sources.

set -uo pipefail

# Validate a `failure-mode` value: must have non-empty id; remaining segments
# must be `key=value`; `exit=N` must be numeric.
_validate_failure_mode_value() {
  local val="$1" path="$2" lineno="$3"
  local first="${val%%|*}"
  first="${first# }"; first="${first% }"
  if [[ -z "$first" ]]; then
    echo "MALFORMED: $path:$lineno: failure-mode missing id" >&2
    return 2
  fi
  if [[ "$val" == *"|"* ]]; then
    local rest="${val#*|}"
    local oldIFS="$IFS"
    IFS='|'
    # shellcheck disable=SC2206
    local segs=($rest)
    IFS="$oldIFS"
    local seg
    for seg in "${segs[@]}"; do
      seg="${seg# }"; seg="${seg% }"
      [[ -z "$seg" ]] && continue
      if [[ ! "$seg" =~ ^[a-zA-Z][a-zA-Z0-9_-]*=.+ ]]; then
        echo "MALFORMED: $path:$lineno: failure-mode segment '$seg' not key=value" >&2
        return 2
      fi
      if [[ "$seg" =~ ^exit=(.+)$ ]]; then
        local n="${BASH_REMATCH[1]}"
        if ! [[ "$n" =~ ^[0-9]+$ ]]; then
          echo "MALFORMED: $path:$lineno: failure-mode exit=$n not numeric" >&2
          return 2
        fi
      fi
    done
  fi
  return 0
}

cmd_extract() {
  local path="${1:-}"
  if [[ -z "$path" ]]; then
    echo "Usage: module-manifest.sh extract <path>" >&2
    return 2
  fi
  if [[ ! -f "$path" ]]; then
    echo "ERROR: file not found: $path" >&2
    return 2
  fi

  # Read file into indexed array (bash 3.2 compatible — no mapfile).
  local lines=()
  local idx=0 line
  while IFS= read -r line || [[ -n "$line" ]]; do
    lines[idx]="$line"
    idx=$((idx+1))
  done < "$path"
  local total="$idx"

  local tmp
  tmp=$(mktemp)
  # shellcheck disable=SC2064
  trap "rm -f '$tmp'" RETURN

  local in_block=0 block_start_lineno=0 block_data=""
  local i

  for ((i=0; i<total; i++)); do
    line="${lines[i]}"
    local lineno=$((i+1))

    if [[ "$line" =~ ^#[[:space:]]*@manifest[[:space:]]*$ ]]; then
      if [[ "$in_block" -eq 1 ]]; then
        _compose_block "$path" "$block_start_lineno" "$block_data" "$i" "$tmp" "$total" || return 2
      fi
      in_block=1
      block_start_lineno=$lineno
      block_data=""
      continue
    fi

    if [[ "$in_block" -eq 1 ]]; then
      if [[ "$line" =~ ^#[[:space:]]+([a-zA-Z][a-zA-Z0-9_-]*):[[:space:]]*(.*)$ ]]; then
        local key="${BASH_REMATCH[1]}"
        local val="${BASH_REMATCH[2]}"
        if [[ "$key" == "failure-mode" ]]; then
          _validate_failure_mode_value "$val" "$path" "$lineno" || return 2
        fi
        block_data+="$key"$'\t'"$val"$'\n'
      else
        _compose_block "$path" "$block_start_lineno" "$block_data" "$i" "$tmp" "$total" || return 2
        in_block=0
        block_data=""
      fi
    fi
  done

  if [[ "$in_block" -eq 1 ]]; then
    _compose_block "$path" "$block_start_lineno" "$block_data" "$total" "$tmp" "$total" || return 2
  fi

  jq -s '.' < "$tmp"
}

# Compose JSON for one block. Caller-side wrapper that uses globally-visible
# `lines` array (set by cmd_extract). Avoids bash-4 nameref dependency.
# Args: path block_start_lineno block_data block_end_idx tmpfile total
_compose_block() {
  local path="$1" block_start="$2" block_data="$3" block_end_idx="$4" tmp="$5" total="$6"

  # Find fn_id: scan from block_end_idx forward in the global `lines` array.
  local fn_id="" j stripped
  for ((j=block_end_idx; j<total; j++)); do
    local l="${lines[j]}"
    stripped="${l// /}"
    [[ -z "$stripped" ]] && continue
    [[ "$l" =~ ^# ]] && continue
    if [[ "$l" =~ ^([a-zA-Z_][a-zA-Z0-9_]*)\(\)[[:space:]]*(\{)?[[:space:]]*$ ]]; then
      fn_id="${BASH_REMATCH[1]}"
    fi
    break
  done
  [[ -z "$fn_id" ]] && fn_id="$(basename "$path" .sh)"

  jq -n --arg id "$fn_id" --arg data "$block_data" '
    def scalar_keys: ["id", "purpose", "routes-by"];
    def is_scalar(k): scalar_keys | index(k);

    {id: $id} as $base
    | $data
    | split("\n")
    | map(select(. != ""))
    | map(split("\t"))
    | map({key: .[0], val: .[1]})
    | reduce .[] as $entry ($base;
        if is_scalar($entry.key) then
          . + {($entry.key): $entry.val}
        else
          . + {($entry.key): ((.[$entry.key] // []) + [$entry.val])}
        end
      )
  ' >> "$tmp"
}

cmd="${1:-}"
shift || true
case "$cmd" in
  extract)  cmd_extract "$@" ;;
  validate) echo "TODO: validate not implemented yet (BTS-239 Step 4-5)" >&2; exit 1 ;;
  query)    echo "TODO: query not implemented yet (BTS-239 Step 3)" >&2; exit 1 ;;
  index)    echo "TODO: index not implemented yet (BTS-239 Step 2)" >&2; exit 1 ;;
  "")       echo "Usage: module-manifest.sh {extract|validate|query|index} [args]" >&2; exit 2 ;;
  *)        echo "Usage: module-manifest.sh {extract|validate|query|index} [args]" >&2; exit 2 ;;
esac
