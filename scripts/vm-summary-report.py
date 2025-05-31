#!/usr/bin/env python3
"""
vm-summary-report.py: Generate summary statistics and recommendations from the VM quota/pricing CSV.
- Input: CSV from vm-pricing-join.py
- Output: Prints summary (totals, min/max/avg price, best value, region coverage, etc.)
"""
import csv
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: vm-summary-report.py <input-csv>", file=sys.stderr)
        sys.exit(1)
    input_csv = sys.argv[1]
    with open(input_csv, newline='') as f:
        reader = list(csv.DictReader(f))
    if not reader:
        print("No data in input CSV.", file=sys.stderr)
        sys.exit(1)

    total_vms = len(reader)
    regions = set(row['region'] for row in reader)
    sizes = set(row['vm_size'] for row in reader)
    prices = [float(row['price_per_hour']) for row in reader if row.get('price_per_hour')]
    cheapest = min(prices) if prices else None
    most_expensive = max(prices) if prices else None
    avg_price = sum(prices)/len(prices) if prices else None

    print(f"Total VM size/region entries: {total_vms}")
    print(f"Regions covered: {len(regions)}")
    print(f"Unique VM sizes: {len(sizes)}")
    if prices:
        print(f"Cheapest VM per hour: ${cheapest:.4f}")
        print(f"Most expensive VM per hour: ${most_expensive:.2f}")
        print(f"Average VM price per hour: ${avg_price:.4f}")
    else:
        print("No pricing data available.")

    # Example recommendation: best value VM (lowest price per vCPU)
    best_value = None
    best_value_ratio = None
    for row in reader:
        try:
            price = float(row['price_per_hour'])
            vcpu = float(row['vcpu'])
            if vcpu > 0:
                ratio = price / vcpu
                if best_value is None or ratio < best_value_ratio:
                    best_value = row
                    best_value_ratio = ratio
        except Exception:
            continue
    if best_value:
        print(f"Best value VM: {best_value['vm_size']} in {best_value['region']} (${best_value['price_per_hour']}/hr, {best_value['vcpu']} vCPUs, ${best_value_ratio:.4f} per vCPU)")
    print("\n(You can expand this script for more advanced recommendations or export to Markdown/JSON as needed.)")

if __name__ == "__main__":
    main()
