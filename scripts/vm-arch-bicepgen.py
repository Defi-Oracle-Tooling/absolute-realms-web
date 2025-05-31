#!/usr/bin/env python3
"""
vm-arch-bicepgen.py: Generate a Bicep template for deploying a recommended VM size in a selected region.
- Input: CSV from vm-pricing-join.py or vm-quota-csv.sh
- Output: Bicep template file for Azure deployment
"""
import csv
import sys

BICEP_TEMPLATE = '''
param location string = '{region}'
param vmName string = 'myVM'
param adminUsername string = 'azureuser'
param adminPassword string

resource vm 'Microsoft.Compute/virtualMachines@2023-03-01' = {{
  name: vmName
  location: location
  properties: {{
    hardwareProfile: {{
      vmSize: '{vm_size}'
    }}
    osProfile: {{
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
    }}
    storageProfile: {{
      imageReference: {{
        publisher: 'Canonical'
        offer: 'UbuntuServer'
        sku: '18.04-LTS'
        version: 'latest'
      }}
      osDisk: {{
        createOption: 'FromImage'
      }}
    }}
    networkProfile: {{
      networkInterfaces: [{{
        id: nic.id
      }}]
    }}
  }}
}}

resource nic 'Microsoft.Network/networkInterfaces@2023-04-01' = {{
  name: '${{vmName}}-nic'
  location: location
  properties: {{
    ipConfigurations: [{{
      name: 'ipconfig1'
      properties: {{
        subnet: {{ id: subnet.id }}
        privateIPAllocationMethod: 'Dynamic'
      }}
    }}]
  }}
}}

resource vnet 'Microsoft.Network/virtualNetworks@2023-04-01' = {{
  name: '${{vmName}}-vnet'
  location: location
  properties: {{
    addressSpace: {{ addressPrefixes: [ '10.0.0.0/16' ] }}
    subnets: [{{
      name: 'default'
      properties: {{ addressPrefix: '10.0.0.0/24' }}
    }}]
  }}
}}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2023-04-01' = {{
  parent: vnet
  name: 'default'
  properties: {{}}
}}
'''

def main():
    if len(sys.argv) < 3:
        print("Usage: vm-arch-bicepgen.py <input-csv> <output-bicep> [region] [vm_size]", file=sys.stderr)
        sys.exit(1)
    input_csv = sys.argv[1]
    output_bicep = sys.argv[2]
    region = sys.argv[3] if len(sys.argv) > 3 else None
    vm_size = sys.argv[4] if len(sys.argv) > 4 else None

    # Added support for additional VM configurations
    if len(sys.argv) > 5:
        os_disk_size = sys.argv[5]
        BICEP_TEMPLATE = BICEP_TEMPLATE.replace("osDisk: { createOption: 'FromImage' }", f"osDisk: {{ createOption: 'FromImage', diskSizeGB: {os_disk_size} }}")

    # Pick best value VM if not specified
    with open(input_csv, newline='') as f:
        reader = list(csv.DictReader(f))
    if not reader:
        print("No data in input CSV.", file=sys.stderr)
        sys.exit(1)
    if not region or not vm_size:
        # Use best value logic from summary script
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
        if not best_value:
            print("No suitable VM found for Bicep generation.", file=sys.stderr)
            sys.exit(1)
        region = best_value['region']
        vm_size = best_value['vm_size']
    # Write Bicep file
    with open(output_bicep, 'w') as f:
        f.write(BICEP_TEMPLATE.format(region=region, vm_size=vm_size))
    print(f"Bicep template generated for {vm_size} in {region}: {output_bicep}")

if __name__ == "__main__":
    main()
