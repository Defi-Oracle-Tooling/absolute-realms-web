#!/usr/bin/env bash
# list-all-vm-sizes.sh: Retrieve Azure VM sizes for all regions in a subscription and output as JSON.

set -euo pipefail
trap 'echo "[ERROR] An unexpected error occurred. Exiting." >&2' ERR
trap 'echo "[INFO] Script interrupted by user." >&2; exit 1' INT TERM

# Load environment variables from .env (if present)
# shellcheck source=.env
if [ -f .env ]; then
  echo "Loading environment variables from .env..."
  set -o allexport && source .env && set +o allexport
fi

## Usage: list-all-vm-sizes.sh [subscription-id] [output-file]
## Subscription ID and other settings can also be set in .env:
##   AZURE_SUBSCRIPTION_ID, AZURE_VM_SIZES_LOCATION, AZURE_API_VERSION, AZURE_VM_SIZES_URL
# Determine subscription ID (argument overrides .env)
if [ $# -ge 1 ]; then
  SUBSCRIPTION_ID="$1"
else
  SUBSCRIPTION_ID="${AZURE_SUBSCRIPTION_ID:-}"
fi
if [ -z "$SUBSCRIPTION_ID" ]; then
  echo "Error: Subscription ID must be provided as argument or in AZURE_SUBSCRIPTION_ID" >&2
  exit 1
fi
# Determine output file; default to timestamped JSON file if not provided
OUTPUT_FILE="${2:-}"
if [ -z "$OUTPUT_FILE" ]; then
  ts=$(date '+%Y%m%d-%H%M%S')
  OUTPUT_FILE="all-vm-sizes-${ts}.json"
  echo "No output file specified; defaulting to $OUTPUT_FILE" >&2
fi
export SUBSCRIPTION_ID
echo "Using subscription ID: $SUBSCRIPTION_ID" >&2

  # Check for required commands: jq and curl
for cmd in jq curl; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "Error: '$cmd' is required but not found. Install $cmd and try again." >&2
    exit 1
  fi
done

  # Ensure bearer token is available

# Always fetch a fresh Azure bearer token via CLI to avoid stale tokens
echo "Fetching Azure access token via Azure CLI..." >&2
AZURE_BEARER_TOKEN=$(az account get-access-token --subscription "$SUBSCRIPTION_ID" --query accessToken -o tsv)
export AZURE_BEARER_TOKEN

# Retry helper: retry commands on failure with exponential backoff
retry() {
  local n=1 max=3 delay=1
  while true; do
    if "$@"; then
      break
    else
      if [ $n -lt $max ]; then
        echo "Command failed (attempt $n/$max). Retrying in $delay seconds..." >&2
        sleep $delay
        n=$((n+1))
        delay=$((delay*2))
      else
        echo "Command failed after $n attempts." >&2
        return 1
      fi
    fi
  done
}
# Export retry so xargs subshells can see it
# Export retry so subshells can see it
export -f retry
# REST API settings (override via .env variables)
API_VERSION="${AZURE_API_VERSION:-2024-11-01}"
# Determine BASE_URL template; ensure '{region}' placeholder present
default_base_url="https://management.azure.com/subscriptions/${SUBSCRIPTION_ID}/providers/Microsoft.Compute/locations/{region}/vmSizes"
if [ -n "${AZURE_VM_SIZES_URL:-}" ]; then
  # Strip any query params
  raw_url="${AZURE_VM_SIZES_URL}"
  base_url_template="${raw_url%%\?*}"
  if [[ "$base_url_template" == *"{region}"* ]]; then
    BASE_URL="$base_url_template"
  else
    echo "Warning: AZURE_VM_SIZES_URL override missing '{region}' placeholder; using default URL template." >&2
    BASE_URL="$default_base_url"
  fi
else
  BASE_URL="$default_base_url"
fi
export API_VERSION BASE_URL

### Fetch available regions (exclude staging/test suffixes)
# Fetch raw region list
echo "Fetching list of Azure regions..." >&2
mapfile -t raw_regions < <(az account list-locations \
  --query "[?(!contains(name, 'stage') && !contains(name, 'test'))].name" \
  --output tsv)

# Known valid Azure regions for VMs (from azure_check_region)
VALID_REGIONS=(
  eastus eastus2 westus centralus northcentralus southcentralus northeurope westeurope
  eastasia southeastasia japaneast japanwest australiaeast australiasoutheast australiacentral
  brazilsouth southindia centralindia westindia canadacentral canadaeast westus2 westcentralus
  uksouth ukwest koreacentral koreasouth francecentral southafricanorth uaenorth
  switzerlandnorth germanywestcentral norwayeast westus3 swedencentral qatarcentral
  polandcentral italynorth israelcentral spaincentral mexicocentral malaysiawest
  newzealandnorth indonesiacentral chilecentral
)
# Filter to only valid regions
regions=()
for r in "${raw_regions[@]}"; do
  for v in "${VALID_REGIONS[@]}"; do
    if [[ "$r" == "$v" ]]; then
      regions+=("$r")
      break
    fi
  done
done


# Process regions serially to ensure valid JSON output
echo "Processing regions serially..." >&2
all_entries=()
for region in "${regions[@]}"; do
  echo "Processing region: $region" >&2
  token=$(az account get-access-token --subscription "$SUBSCRIPTION_ID" --query accessToken -o tsv)
  raw_endpoint="${BASE_URL//\{region\}/$region}"
  endpoint="${raw_endpoint%%\?*}"
  response=$(retry curl -s -w "HTTPSTATUS:%{http_code}" \
    -H "Authorization: Bearer $token" \
    "$endpoint?api-version=$API_VERSION")
  http_status="${response##*HTTPSTATUS:}"
  body="${response%HTTPSTATUS:*}"
  if [[ "$http_status" -lt 200 || "$http_status" -ge 300 ]]; then
    echo "Error: Failed to fetch sizes for region $region (HTTP $http_status)" >&2
    continue
  fi
  # Extract VM size names, skip if jq fails
  sizes=$(echo "$body" | jq 'if has("value") then [.value[].name] else [.[].name] end' 2>/dev/null)
  if [ -z "$sizes" ] || [ "$sizes" = "null" ]; then
    echo "Warning: No VM sizes found or invalid JSON for region $region" >&2
    continue
  fi
  entry=$(printf '{"region": "%s", "sizes": %s}' "$region" "$sizes")
  all_entries+=("$entry")
done

# Combine entries into a single JSON array
all_sizes_json=$(printf '%s\n' "${all_entries[@]}" | jq -s '.')

# Output
if [ -n "$OUTPUT_FILE" ]; then
  echo "$all_sizes_json" > "$OUTPUT_FILE"
  echo "Results written to $OUTPUT_FILE"
else
  echo "$all_sizes_json"
fi
