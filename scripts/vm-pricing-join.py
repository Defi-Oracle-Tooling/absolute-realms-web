#!/usr/bin/env python3
"""
vm-pricing-join.py: Join Azure VM size/region CSV with up-to-date pricing from Azure Retail Prices API.
- Input: CSV from vm-quota-csv.sh (with at least region,vm_size columns)
- Output: CSV with added columns for price (per hour, per month), currency, and offer details
"""
import csv
import json
import requests
import sys
from collections import defaultdict

PRICES_API = "https://prices.azure.com/api/retail/prices"

# Map region short names to Azure API region names if needed
REGION_MAP = defaultdict(lambda: None, {
    # Add mappings if needed, e.g. 'uksouth': 'UK South'
})

def fetch_vm_prices(region):
    """Fetch all VM prices for a region from Azure Retail Prices API."""
    prices = []
    next_url = f"{PRICES_API}?$filter=serviceName eq 'Virtual Machines' and armRegionName eq '{region}'"
    while next_url:
        resp = requests.get(next_url)
        resp.raise_for_status()
        data = resp.json()
        prices.extend(data.get('Items', []))
        next_url = data.get('NextPageLink')
    return prices

def build_price_index(prices):
    """Index prices by SKU (productName or skuName)."""
    index = defaultdict(list)
    for item in prices:
        # Use skuName (e.g. 'Standard_D2s_v3') as key
        key = item.get('skuName') or item.get('productName')
        if key:
            index[key].append(item)
    return index

def main():
    if len(sys.argv) < 2:
        print("Usage: vm-pricing-join.py <input-csv> [output-csv]", file=sys.stderr)
        sys.exit(1)
    input_csv = sys.argv[1]
    output_csv = sys.argv[2] if len(sys.argv) > 2 else input_csv.replace('.csv', '-pricing.csv')

    # Read input CSV
    with open(input_csv, newline='') as f:
        reader = list(csv.DictReader(f))
    if not reader:
        print("No data in input CSV.", file=sys.stderr)
        sys.exit(1)

    # Collect all regions and VM sizes
    regions = set(row['region'] for row in reader)
    vm_sizes = set(row['vm_size'] for row in reader)

    # Fetch and index prices for all regions
    region_price_index = {}
    for region in regions:
        print(f"Fetching prices for region: {region}", file=sys.stderr)
        prices = fetch_vm_prices(region)
        region_price_index[region] = build_price_index(prices)

    # Prepare output
    fieldnames = list(reader[0].keys()) + ['price_per_hour', 'price_per_month', 'currency', 'offerId', 'retailPrice', 'unitPrice']
    with open(output_csv, 'w', newline='') as f:
        writer = csv.DictWriter(f, fieldnames=fieldnames)
        writer.writeheader()
        for row in reader:
            region = row['region']
            size = row['vm_size']
            price_info = None
            for item in region_price_index.get(region, {}).get(size, []):
                if item.get('unitPrice') and item.get('unitOfMeasure', '').lower() == '1 hour':
                    price_info = item
                    break
            if price_info:
                row['price_per_hour'] = price_info['unitPrice']
                row['price_per_month'] = round(price_info['unitPrice'] * 730, 2)
                row['currency'] = price_info.get('currencyCode', '')
                row['offerId'] = price_info.get('offerId', '')
                row['retailPrice'] = price_info.get('retailPrice', '')
                row['unitPrice'] = price_info.get('unitPrice', '')
            else:
                row['price_per_hour'] = ''
                row['price_per_month'] = ''
                row['currency'] = ''
                row['offerId'] = ''
                row['retailPrice'] = ''
                row['unitPrice'] = ''
            writer.writerow(row)
    print(f"Pricing joined. Output: {output_csv}")

if __name__ == "__main__":
    main()
