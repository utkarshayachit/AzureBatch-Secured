param principalId string = 'f520d84c-3fd3-4cc8-88d4-2ed25b00d27a'
param roleDefinitionName string = 'Contributor'
param location string = resourceGroup().location

var query = '[?principalId==\'${principalId}\' && roleDefinitionName==\'${roleDefinitionName}\'].{name:name}'
var scriptContent = 'az login -i > /dev/null 2>&1 && az role assignment list --scope ${subscription().id} -o json --query "${query}"'

resource myManagedIdentify 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: uniqueString(resourceGroup().id, deployment().name)
  location: location
}

module mdl '../../modules/azRoles/roleAssignmentSubscription.bicep' = {
  scope: subscription()
  name: 'dpl-roleassignment'
  params: {
    builtInRoleType: 'Reader'
    principalId: myManagedIdentify.properties.principalId
  }
}

resource script 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'testRoleAssignment'
  location: location
  kind: 'AzureCLI'
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${ myManagedIdentify.id}': {}
    }
  }

  properties: {
    azCliVersion: '2.39.0'
    retentionInterval: 'P1D'
    // scriptContent: '${scriptContent} 2>&1 | jq -c \'{"result": (. | length | (if . > 0 then true else false end))}\' | tee $AZ_SCRIPTS_OUTPUT_PATH'
    scriptContent: '${scriptContent} 2>&1 | jq -c \'{"result": . }\' | tee $AZ_SCRIPTS_OUTPUT_PATH'
    cleanupPreference: 'OnSuccess'
  }
}

output result object  = script.properties.outputs
