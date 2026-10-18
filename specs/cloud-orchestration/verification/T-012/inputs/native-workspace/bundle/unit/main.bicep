// All billable choices and existing references are explicit owner inputs.
targetScope = 'resourceGroup'
param vmName string
param location string
param vmSize string
param imageId string
param adminUsername string
param adminPublicKey string
param subnetId string
param identityId string
param dataCollectionRuleId string
param vaultName string
param backupPolicyId string

resource nic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${vmName}-nic'
  location: location
  properties: {
    enableIPForwarding: false
    ipConfigurations: [{
      name: 'private'
      properties: {
        privateIPAllocationMethod: 'Dynamic'
        subnet: { id: subnetId }
      }
    }]
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: vmName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${identityId}': {} }
  }
  properties: {
    hardwareProfile: { vmSize: vmSize }
    storageProfile: {
      imageReference: { id: imageId }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'Standard_LRS' }
        deleteOption: 'Detach'
      }
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [{
            path: '/home/${adminUsername}/.ssh/authorized_keys'
            keyData: adminPublicKey
          }]
        }
      }
    }
    networkProfile: { networkInterfaces: [{ id: nic.id }] }
  }
}

resource monitor 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: vm
  name: 'AzureMonitorLinuxAgent'
  location: location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: false
    enableAutomaticUpgrade: false
    settings: {
      authentication: {
        managedIdentity: {
          'identifier-name': 'mi_res_id'
          'identifier-value': identityId
        }
      }
    }
  }
}

resource association 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: '${vmName}-monitor'
  scope: vm
  properties: { dataCollectionRuleId: dataCollectionRuleId }
}

resource backup 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-04-01' = {
  name: '${vaultName}/Azure/iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${vmName}/vm;iaasvmcontainerv2;${resourceGroup().name};${vmName}'
  properties: {
    protectedItemType: 'Microsoft.Compute/virtualMachines'
    sourceResourceId: vm.id
    policyId: backupPolicyId
  }
}
