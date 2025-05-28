targetScope = 'subscription'

param environmentName string
param location string
param resourceGroupName string

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: resourceGroupName
  location: location
  tags: {
    'azd-env-name': environmentName
  }
}

output RESOURCE_GROUP_ID string = resourceGroup.id
