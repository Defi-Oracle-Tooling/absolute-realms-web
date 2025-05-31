#!/usr/bin/env bash
# list-all-vm-sizes.sh: Retrieve Azure VM sizes for all regions in a subscription and output as JSON.

set -euo pipefail

# Load environment variables from .env (if present)
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
OUTPUT_FILE="${2:-}"
export SUBSCRIPTION_ID

  # Check for jq
if ! command -v jq &>/dev/null; then
  echo "Error: 'jq' is required but not found. Install jq and try again." >&2
  exit 1
fi

  # Ensure bearer token is available

echo "Fetching list of Azure regions..."
  # Ensure bearer token is available
  if [ -z "${AZURE_BEARER_TOKEN:-}" ]; then
    echo "AZURE_BEARER_TOKEN not found; fetching via Azure CLI..."
    AZURE_BEARER_TOKEN=$(az account get-access-token --subscription "$SUBSCRIPTION_ID" --query accessToken -o tsv)
  fi

# Fetch list of Azure regions into a bash array
echo "Fetching list of Azure regions..."
mapfile -t regions < <(az account list-locations \
  --query "[].name" \
  --output tsv)

# Process regions in parallel (adjust -P for concurrency)
echo "Processing regions in parallel (8 at a time)..."
all_entries=$(printf '%s\n' "${regions[@]}" | \
  xargs -P 8 -n1 bash -c '
    region="$1"
    printf "Processing region: %s\n" "$region"
    sizes=$(az vm list-sizes \
      --location "$region" \
      --subscription "$SUBSCRIPTION_ID" \
      --query "[].name" \
      --output json)
    printf "{\"region\": \"%s\", \"sizes\": %s}\n" "$region" "$sizes"
  ' _)

# Combine entries into a single JSON array
all_sizes_json=$(printf '%s\n' "$all_entries" | jq -s '.')

# Output
if [ -n "$OUTPUT_FILE" ]; then
  echo "$all_sizes_json" > "$OUTPUT_FILE"
  echo "Results written to $OUTPUT_FILE"
else
  echo "$all_sizes_json"
fi
