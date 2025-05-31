#!/usr/bin/env python3
"""
vm-arch-mermaidgen.py: Generate a Mermaid diagram for VM deployment architecture based on best-value VM and region coverage.
- Input: CSV from vm-pricing-join.py
- Output: Markdown file with Mermaid diagram
"""
import csv
import sys

def main():
    if len(sys.argv) < 2:
        print("Usage: vm-arch-mermaidgen.py <input-csv> [output-md]", file=sys.stderr)
        sys.exit(1)
    input_csv = sys.argv[1]
    output_md = sys.argv[2] if len(sys.argv) > 2 else input_csv.replace('.csv', '-arch.md')
    with open(input_csv, newline='') as f:
        reader = list(csv.DictReader(f))
    if not reader:
        print("No data in input CSV.", file=sys.stderr)
        sys.exit(1)
    # Find best value VM
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
    # Mermaid diagram
    with open(output_md, 'w') as f:
        f.write("""# Azure VM Deployment Architecture (Mermaid)

```mermaid
flowchart TD
    subgraph Azure_Region["{region}"]
        VM["{vm_size}\n{vcpu} vCPU, {memory_gb} GB RAM\n${price_per_hour}/hr"]
        Storage[(Managed Disk)]
        NIC((Network Interface))
        VNet((Virtual Network))
        Subnet((Subnet))
        VM --> NIC --> Subnet --> VNet
        VM --> Storage
    end
```
""".format(
            region=best_value['region'] if best_value else 'unknown',
            vm_size=best_value['vm_size'] if best_value else 'unknown',
            vcpu=best_value['vcpu'] if best_value else '?',
            memory_gb=best_value['memory_gb'] if best_value else '?',
            price_per_hour=best_value['price_per_hour'] if best_value else '?'
        ))
    print(f"Mermaid architecture diagram written to {output_md}")

if __name__ == "__main__":
    main()
