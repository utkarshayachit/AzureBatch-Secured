

param vmCount int = 1
param vmObject object

param subnetId string
param tags object = {}

param managedIdentityName string

resource mi 'Microsoft.ManagedIdentity/userAssignedIdentities@2018-11-30' existing = {
  name: managedIdentityName
}

resource nicNameVMResource 'Microsoft.Network/networkInterfaces@2020-05-01' = [for i in range(0, vmCount): {
  name: '${vmObject.nicName}${i + 1}'
  location: resourceGroup().location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetId
          }
        }
      }
    ]
  }
}]

output nicDetail array = [for i in range(0, vmCount) : {
  nicName: '${vmObject.nicName}${i + 1}'
  privateIp: reference('${vmObject.nicName}${i + 1}', '2020-05-01', 'Full').properties.ipConfigurations[0].properties.privateIPAddress
}]



resource vmResource 'Microsoft.Compute/virtualMachines@2019-07-01' = [for i in range(0, vmCount): {
  name: '${vmObject.vmName}${i + 1}'
  location: resourceGroup().location
  dependsOn:[
    nicNameVMResource
  ]
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${mi.id}': {}
    }
  }
  tags: tags
  properties: {
    hardwareProfile: {
      vmSize: vmObject.vmSize
    }
    osProfile: vmObject.osProfile
    storageProfile: {
      imageReference: vmObject.imageReference
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: resourceId('Microsoft.Network/networkInterfaces', '${vmObject.nicName}${i + 1}')
        }
      ]
    }
  }
}]
