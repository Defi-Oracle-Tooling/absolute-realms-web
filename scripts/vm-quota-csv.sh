#!/usr/bin/env bash
# vm-quota-csv.sh: Generate/update a CSV, JSON, or Markdown of Azure VM sizes, quotas, and region support.

set -euo pipefail
trap 'err "An unexpected error occurred. Exiting."' ERR
trap 'err "Script interrupted by user."; exit 1' INT TERM

# --- Logging functions (moved up for early use) ---
log() { echo "[INFO] $*"; }
warn() { echo "[WARN] $*" >&2; }
err() { echo "[ERROR] $*" >&2; }

show_help() {
  cat <<EOF
Usage: $0 [options]
Options:
  --regions <list>   Comma-separated Azure regions
  --output <file>    Output file name
  --fields <list>    Comma-separated fields (region,vm_size,quota,regions_supporting_instance,family_series,vcpu,memory_gb)
  --format <fmt>     Output format: csv (default), json, md
  --filter <regex>   Only include VM sizes matching regex
  --exclude <regex>  Exclude VM sizes matching regex
  --parallel <n>     Number of parallel region jobs (default: 4)
  --cache-dir <dir>  Directory for per-region cache (default: .vm_quota_cache)
  --refresh          Refresh cache for all regions
  --upload <url>     Upload output to Azure Blob (container URL)
  --email <addr>     Send notification email (requires 'mail' command)
  --webhook <url>    POST output to webhook URL (requires 'curl')
  --help             Show this help message
EOF
}

# --- Defaults ---
PARALLEL_JOBS=4
CACHE_DIR=".vm_quota_cache"
REFRESH_CACHE=0
UPLOAD_URL=""
EMAIL_NOTIFY=""
WEBHOOK_NOTIFY=""
default_regions="southeastasia,northeurope,swedencentral,uksouth,westeurope,southafricanorth,centralindia,eastasia,indonesiacentral,japaneast,japanwest,koreacentral,malaysiawest,newzealandnorth,canadacentral,francecentral,germanywestcentral,italynorth,norwayeast,polandcentral,spaincentral,switzerlandnorth,mexicocentral,uaenorth,brazilsouth,chilecentral,israelcentral,qatarcentral,koreasouth,southindia,westindia,canadaeast,ukwest,uaecentral,brazilsoutheast"
default_output="vm-sizes-quotas-$(date '+%Y%m%d-%H%M%S').csv"
default_fields="region,vm_size,quota,regions_supporting_instance,family_series,vcpu,memory_gb"
default_format="csv"
filter_regex=""
exclude_regex=""

# --- Argument Parsing ---
REGIONS="$default_regions"
OUTPUT="$default_output"
FIELDS="$default_fields"
FORMAT="$default_format"
while [[ $# -gt 0 ]]; do
  case $1 in
    --parallel) PARALLEL_JOBS="$2"; shift;;
    --cache-dir) CACHE_DIR="$2"; shift;;
    --refresh) REFRESH_CACHE=1;;
    --upload) UPLOAD_URL="$2"; shift;;
    --email) EMAIL_NOTIFY="$2"; shift;;
    --webhook) WEBHOOK_NOTIFY="$2"; shift;;
    --regions) REGIONS="$2"; shift;;
    --output) OUTPUT="$2"; shift;;
    --fields) FIELDS="$2"; shift;;
    --format) FORMAT="$2"; shift;;
    --filter) filter_regex="$2"; shift;;
    --exclude) exclude_regex="$2"; shift;;
    --help) show_help; exit 0;;
    *) err "Unknown option: $1"; show_help; exit 1;;
  esac
  shift
done

IFS=',' read -ra REGION_LIST <<< "$REGIONS"
IFS=',' read -ra FIELD_LIST <<< "$FIELDS"

# --- Dependency Checks ---
for cmd in az jq; do
  if ! command -v "$cmd" &>/dev/null; then
    err "'$cmd' is required but not found. Install $cmd and try again."
    exit 1
  fi
done

# --- Region Data Collection (Parallel, Cached, Progress) ---
region_worker() {
  local region="$1"
  local idx="$2"
  local total="$3"
  local cache_sku="$CACHE_DIR/$region-skus.json"
  local cache_usage="$CACHE_DIR/$region-usage.json"

  printf "[PROGRESS] [%d/%d] Processing region: %s\n" "$idx" "$total" "$region"
  if [[ $REFRESH_CACHE -eq 1 || ! -f "$cache_sku" ]]; then
    az vm list-skus --location "$region" --resource-type virtualMachines -o json 2> >(grep -v 'az.sess' >&2) > "$cache_sku" || echo "[ERROR] Failed to fetch skus for $region" >&2
  fi
  if [[ $REFRESH_CACHE -eq 1 || ! -f "$cache_usage" ]]; then
    az vm list-usage --location "$region" -o json 2> >(grep -v 'az.sess' >&2) > "$cache_usage" || echo "[ERROR] Failed to fetch usage for $region" >&2
  fi
}

main() {
  mkdir -p "$CACHE_DIR"
  log "Gathering VM sizes for selected regions (parallel=$PARALLEL_JOBS, cache=$CACHE_DIR)..."
  job_count=0
  total_regions=${#REGION_LIST[@]}
  declare -a region_failures
  for idx in "${!REGION_LIST[@]}"; do
    region="${REGION_LIST[$idx]}"
    region_worker "$region" "$((idx+1))" "$total_regions" &
    job_count=$((job_count+1))
    if (( job_count % PARALLEL_JOBS == 0 )); then wait; fi
  done
  wait

  # --- Data Aggregation ---
  declare -A vm_region_count
  declare -A vm_family
  declare -A vm_vcpu
  declare -A vm_mem
  total_vm_sizes=0
  for region in "${REGION_LIST[@]}"; do
    if [[ ! -f "$CACHE_DIR/skus_$region.json" || ! -f "$CACHE_DIR/usage_$region.json" ]]; then
      warn "Missing cache for $region. Skipping."
      region_failures+=("$region")
      continue
    fi
    skus_json=$(cat "$CACHE_DIR/skus_$region.json")
    sizes=$(echo "$skus_json" | jq -r '[.[] | select(.capabilities[]?.name == "vCPUs") | .name] | unique | .[]')
    for size in $sizes; do
      [[ -n "$filter_regex" && ! "$size" =~ $filter_regex ]] && continue
      [[ -n "$exclude_regex" && "$size" =~ $exclude_regex ]] && continue
      vm_region_count["$size"]=$(( ${vm_region_count["$size"]:-0} + 1 ))
      vm_family["$size"]="${size%%_*}"
      vm_vcpu["$size"]=$(echo "$skus_json" | jq -r --arg name "$size" '.[] | select(.name==$name) | .capabilities[]? | select(.name=="vCPUs") | .value' | head -n1)
      vm_mem["$size"]=$(echo "$skus_json" | jq -r --arg name "$size" '.[] | select(.name==$name) | .capabilities[]? | select(.name=="MemoryGB") | .value' | head -n1)
      total_vm_sizes=$((total_vm_sizes+1))
    done
  done

  # --- Output Header ---
  header=""
  for f in "${FIELD_LIST[@]}"; do header+="$f,"; done
  header=${header%,}
  echo "$header" > "$OUTPUT"

  # --- Collect Quota and Write Rows ---
  log "Collecting quota and writing $FORMAT..."
  rows=()
  for region in "${REGION_LIST[@]}"; do
    if [[ ! -f "$CACHE_DIR/usage_$region.json" || ! -f "$CACHE_DIR/skus_$region.json" ]]; then
      continue
    fi
    usage_json=$(cat "$CACHE_DIR/usage_$region.json")
    skus_json=$(cat "$CACHE_DIR/skus_$region.json")
    sizes=$(echo "$skus_json" | jq -r '[.[] | select(.capabilities[]?.name == "vCPUs") | .name] | unique | .[]')
    for size in $sizes; do
      [[ -n "$filter_regex" && ! "$size" =~ $filter_regex ]] && continue
      [[ -n "$exclude_regex" && "$size" =~ $exclude_regex ]] && continue
      quota=$(echo "$usage_json" | jq -r --arg name "$size" '.[] | select(.name.value|ascii_downcase|startswith($name|ascii_downcase)) | .limit // "N/A"' | head -n1)
      row=""
      for f in "${FIELD_LIST[@]}"; do
        case $f in
          region) row+="$region,";;
          vm_size) row+="$size,";;
          quota) row+="$quota,";;
          regions_supporting_instance) row+="${vm_region_count[$size]},";;
          family_series) row+="${vm_family[$size]},";;
          vcpu) row+="${vm_vcpu[$size]},";;
          memory_gb) row+="${vm_mem[$size]},";;
          *) row+="N/A,";;
        esac
      done
      row=${row%,}
      rows+=("$row")
    done
  done

  # --- Output Formats ---
  if [[ "$FORMAT" == "csv" ]]; then
    printf '%s\n' "${rows[@]}" >> "$OUTPUT"
  elif [[ "$FORMAT" == "json" ]]; then
    jq -Rn --argfile arr <(printf '%s\n' "${rows[@]}" | jq -R -s -c 'split("\n") | map(split(","))') '
      $arr | map({
        region: .[0], vm_size: .[1], quota: .[2], regions_supporting_instance: .[3], family_series: .[4], vcpu: .[5], memory_gb: .[6]
      })' > "$OUTPUT"
  elif [[ "$FORMAT" == "md" ]]; then
    printf '| %s |\n' "${header//,/ | }" >> "$OUTPUT"
    sep="|"
    for _ in "${FIELD_LIST[@]}"; do sep+=" --- |"; done
    printf '%s\n' "$sep" >> "$OUTPUT"
    for row in "${rows[@]}"; do
      printf '| %s |\n' "${row//,/ | }" >> "$OUTPUT"
    done
  else
    err "Unknown format: $FORMAT"; exit 1
  fi

  # --- Integration: upload to Azure Blob if requested ---
  if [[ -n "$UPLOAD_URL" ]]; then
    log "Uploading $OUTPUT to $UPLOAD_URL ..."
    az storage blob upload --overwrite --file "$OUTPUT" --container-name "${UPLOAD_URL#*//}" --name "$(basename "$OUTPUT")"
    upload_status=$?
    if [[ $upload_status -eq 0 ]]; then
      log "Upload successful: $UPLOAD_URL/$(basename "$OUTPUT")"
    else
      err "Upload failed with status $upload_status."
    fi
  fi

  # --- Integration: email notification (optional, requires 'mail') ---
  if [[ -n "$EMAIL_NOTIFY" ]]; then
    if command -v mail &>/dev/null; then
      echo "Azure VM quota report generated: $OUTPUT" | mail -s "Azure VM Quota Report" "$EMAIL_NOTIFY"
      log "Notification email sent to $EMAIL_NOTIFY"
    else
      warn "'mail' command not found, cannot send email notification."
    fi
  fi

  # --- Integration: webhook notification (optional, requires 'curl') ---
  if [[ -n "$WEBHOOK_NOTIFY" ]]; then
    if command -v curl &>/dev/null; then
      curl -X POST -F "file=@$OUTPUT" "$WEBHOOK_NOTIFY"
      log "Webhook notification sent to $WEBHOOK_NOTIFY"
    else
      warn "'curl' command not found, cannot send webhook notification."
    fi
  fi

  # --- Summary Report ---
  echo
  echo "--- Summary Report ---"
  echo "Regions processed: $((total_regions - ${#region_failures[@]})) / $total_regions"
  echo "Total VM sizes processed: $total_vm_sizes"
  if [[ ${#region_failures[@]} -gt 0 ]]; then
    echo "Regions failed/skipped: ${region_failures[*]}"
  fi
  echo "Output file: $OUTPUT"
  if [[ -n "$UPLOAD_URL" ]]; then
    echo "Uploaded to: $UPLOAD_URL/$(basename "$OUTPUT")"
  fi
  if [[ -n "$EMAIL_NOTIFY" ]]; then
    echo "Notification email sent to: $EMAIL_NOTIFY"
  fi
  if [[ -n "$WEBHOOK_NOTIFY" ]]; then
    echo "Webhook notification sent to: $WEBHOOK_NOTIFY"
  fi
  echo
  cat <<EOT
--- Recommendations ---
- To update the output, rerun this script with your desired options.
- Use --help for usage and automation.
- For large region sets, consider running overnight or in a screen/tmux session.
- For more columns (e.g., vCPU, memory), use --fields.
- For automation, pass regions/output/fields/format as CLI args.
- For filtering, use --filter or --exclude with regex.
- For JSON or Markdown, use --format json or --format md.
- For integration, upload the output to storage, email, or webhook as needed.
- For performance, consider parallelization or caching for very large queries.
- For progress, a spinner or progress bar is now included.
- For historical tracking, use a database or versioned CSVs.
- For summary, see the final report above.
EOT
}

main "$@"

for region in "${REGION_LIST[@]}"; do
  skus_json=$(cat "$CACHE_DIR/skus_$region.json")
  sizes=$(echo "$skus_json" | jq -r '[.[] | select(.capabilities[]?.name == "vCPUs") | .name] | unique | .[]')
  for size in $sizes; do
    [[ -n "$filter_regex" && ! "$size" =~ $filter_regex ]] && continue
    [[ -n "$exclude_regex" && "$size" =~ $exclude_regex ]] && continue
    vm_region_count["$size"]=$(( ${vm_region_count["$size"]:-0} + 1 ))
    vm_family["$size"]="${size%%_*}"
    vm_vcpu["$size"]=$(echo "$skus_json" | jq -r --arg name "$size" '.[] | select(.name==$name) | .capabilities[]? | select(.name=="vCPUs") | .value' | head -n1)
    vm_mem["$size"]=$(echo "$skus_json" | jq -r --arg name "$size" '.[] | select(.name==$name) | .capabilities[]? | select(.name=="MemoryGB") | .value' | head -n1)
  done
done
