
param settings object
var name = settings.vmName
resource machine 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: name
  location: settings.location
  tags: { purpose: 'independent-module-case' }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: { '${settings.identityId}': {} }
  }
  properties: {
    hardwareProfile: { vmSize: settings.vmSize }
    storageProfile: {
      imageReference: { id: settings.imageId }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: { storageAccountType: 'StandardSSD_LRS' }
        diskSizeGB: 64
        deleteOption: 'Detach'
      }
    }
    osProfile: {
      computerName: name
      adminUsername: settings.adminUsername
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: { publicKeys: [{ path: '/home/${settings.adminUsername}/.ssh/authorized_keys', keyData: settings.adminPublicKey }] }
      }
    }
    networkProfile: { networkInterfaces: [{ id: connection.id }] }
  }
}
resource connection 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: '${name}-internal'
  location: settings.location
  properties: {
    enableIPForwarding: false
    enableAcceleratedNetworking: true
    ipConfigurations: [{ name: 'internal', properties: { subnet: { id: settings.subnetId }, privateIPAllocationMethod: 'Dynamic' } }]
  }
}
resource telemetry 'Microsoft.Compute/virtualMachines/extensions@2024-07-01' = {
  parent: machine
  name: 'monitorAgent'
  location: settings.location
  properties: {
    publisher: 'Microsoft.Azure.Monitor'
    type: 'AzureMonitorLinuxAgent'
    typeHandlerVersion: '1.0'
    autoUpgradeMinorVersion: false
    enableAutomaticUpgrade: false
    settings: { authentication: { managedIdentity: { 'identifier-name': 'mi_res_id', 'identifier-value': settings.identityId } } }
  }
}
resource monitoring 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  scope: machine
  name: '${name}-signals'
  properties: { dataCollectionRuleId: settings.dataCollectionRuleId }
}
resource protection 'Microsoft.RecoveryServices/vaults/backupFabrics/protectionContainers/protectedItems@2024-04-01' = {
  name: '${settings.vaultName}/Azure/iaasvmcontainer;iaasvmcontainerv2;${resourceGroup().name};${name}/vm;iaasvmcontainerv2;${resourceGroup().name};${name}'
  properties: { protectedItemType: 'Microsoft.Compute/virtualMachines', sourceResourceId: machine.id, policyId: settings.backupPolicyId }
}
