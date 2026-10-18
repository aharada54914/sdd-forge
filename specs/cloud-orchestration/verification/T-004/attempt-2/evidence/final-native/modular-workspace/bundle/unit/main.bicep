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
module workload './modules/private.bicep' = {
  name: 'private-unit'
  params: {
    settings: {
      vmName: vmName
      location: location
      vmSize: vmSize
      imageId: imageId
      adminUsername: adminUsername
      adminPublicKey: adminPublicKey
      subnetId: subnetId
      identityId: identityId
      dataCollectionRuleId: dataCollectionRuleId
      vaultName: vaultName
      backupPolicyId: backupPolicyId
    }
  }
}
