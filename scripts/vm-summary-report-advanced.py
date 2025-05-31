#!/usr/bin/env python3
"""
vm-summary-report-advanced.py: Generate advanced summary, analytics, and recommendations from the VM quota/pricing CSV.
- Input: CSV from vm-pricing-join.py
- Output: Markdown, JSON, and text summary (totals, price trends, top N, region gaps, best value, spot/preemptible, recommendations)
"""
import csv
import sys
import json
from collections import Counter
from statistics import mean

def main():
    if len(sys.argv) < 2:
        print("Usage: vm-summary-report-advanced.py <input-csv> [output-md] [output-json]", file=sys.stderr)
        sys.exit(1)
    input_csv = sys.argv[1]
    output_md = sys.argv[2] if len(sys.argv) > 2 else input_csv.replace('.csv', '-summary.md')
    output_json = sys.argv[3] if len(sys.argv) > 3 else input_csv.replace('.csv', '-summary.json')
    with open(input_csv, newline='') as f:
        reader = list(csv.DictReader(f))
    if not reader:
        print("No data in input CSV.", file=sys.stderr)
        sys.exit(1)

    # Basic stats
    total_vms = len(reader)
    regions = sorted(set(row['region'] for row in reader))
    sizes = sorted(set(row['vm_size'] for row in reader))
    prices = [float(row['price_per_hour']) for row in reader if row.get('price_per_hour')]
    cheapest = min(prices) if prices else None
    most_expensive = max(prices) if prices else None
    avg_price = mean(prices) if prices else None

    # Top N cheapest/most expensive
    top_n = 5
    sorted_by_price = sorted([row for row in reader if row.get('price_per_hour')], key=lambda r: float(r['price_per_hour']))
    cheapest_vms = sorted_by_price[:top_n]
    expensive_vms = sorted_by_price[-top_n:][::-1]

    # Region coverage per VM size
    region_counts = Counter(row['region'] for row in reader)
    size_counts = Counter(row['vm_size'] for row in reader)
    missing_regions = [r for r in regions if region_counts[r] < len(sizes)]

    # Best value VM (lowest price per vCPU)
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

    # Spot/preemptible VMs (if available in pricing data)
    spot_vms = [row for row in reader if 'spot' in row.get('offerId', '').lower() or 'spot' in row.get('skuName', '').lower()]

    # Markdown output
    with open(output_md, 'w') as f:
        f.write(f"# Azure VM Pricing & Quota Summary\n\n")
        f.write(f"**Total VM size/region entries:** {total_vms}\n\n")
        f.write(f"**Regions covered:** {len(regions)}\n\n")
        f.write(f"**Unique VM sizes:** {len(sizes)}\n\n")
        if prices:
            f.write(f"**Cheapest VM per hour:** ${cheapest:.4f}\n\n")
            f.write(f"**Most expensive VM per hour:** ${most_expensive:.2f}\n\n")
            f.write(f"**Average VM price per hour:** ${avg_price:.4f}\n\n")
        else:
            f.write("No pricing data available.\n\n")
        f.write("## Top 5 Cheapest VMs\n\n")
        f.write("| Region | VM Size | Price/hr | vCPU | Memory (GB) |\n|---|---|---|---|---|\n")
        for row in cheapest_vms:
            f.write(f"| {row['region']} | {row['vm_size']} | ${row['price_per_hour']} | {row['vcpu']} | {row['memory_gb']} |\n")
        f.write("\n## Top 5 Most Expensive VMs\n\n")
        f.write("| Region | VM Size | Price/hr | vCPU | Memory (GB) |\n|---|---|---|---|---|\n")
        for row in expensive_vms:
            f.write(f"| {row['region']} | {row['vm_size']} | ${row['price_per_hour']} | {row['vcpu']} | {row['memory_gb']} |\n")
        f.write("\n## Best Value VM\n\n")
        if best_value:
            f.write(f"**{best_value['vm_size']} in {best_value['region']}** (${best_value['price_per_hour']}/hr, {best_value['vcpu']} vCPUs, ${best_value_ratio:.4f} per vCPU)\n\n")
        else:
            f.write("No best value VM found.\n\n")
        if spot_vms:
            f.write("## Spot/Preemptible VMs\n\n")
            f.write("| Region | VM Size | Price/hr |\n|---|---|---|\n")
            for row in spot_vms[:top_n]:
                f.write(f"| {row['region']} | {row['vm_size']} | ${row['price_per_hour']} |\n")
        f.write("\n## Recommendations\n\n")
        f.write("- Consider using the best value VM for cost efficiency.\n")
        f.write("- Use spot/preemptible VMs for non-critical workloads to save costs.\n")
        f.write("- Review region coverage and select regions with the best quota and price.\n")
        f.write("- For high availability, deploy across multiple regions.\n")
        f.write("- Use reserved instances for long-term, steady-state workloads.\n")
        f.write("\n## Visualization Recommendations\n\n")
        f.write("- Use bar charts to compare VM prices across regions.\n")
        f.write("- Use pie charts to show the distribution of VM sizes.\n")
        f.write("- Use line graphs to track price trends over time.\n")
        f.write("\n---\n")
    # JSON output
    summary = {
        'total_vms': total_vms,
        'regions': regions,
        'sizes': sizes,
        'cheapest': cheapest,
        'most_expensive': most_expensive,
        'avg_price': avg_price,
        'top_cheapest': cheapest_vms,
        'top_expensive': expensive_vms,
        'best_value': best_value,
        'best_value_ratio': best_value_ratio,
        'spot_vms': spot_vms[:top_n],
        'recommendations': [
            'Use the best value VM for cost efficiency.',
            'Use spot/preemptible VMs for non-critical workloads.',
            'Review region coverage and select regions with the best quota and price.',
            'For high availability, deploy across multiple regions.',
            'Use reserved instances for long-term, steady-state workloads.'
        ]
    }
    with open(output_json, 'w') as f:
        json.dump(summary, f, indent=2)
    print(f"Advanced summary written to {output_md} and {output_json}")

if __name__ == "__main__":
    main()
