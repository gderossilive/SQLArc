param WorkspaceName string
param location string
param Seed string
param VMlist array

resource LAW 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: WorkspaceName
}

resource DCR_VMInsights 'Microsoft.Insights/dataCollectionRules@2022-06-01' = {
  name: 'DCR-VM-${Seed}'
  location: location
  properties: {
//    dataCollectionEndpointId: DCE.id
    dataSources: {
      performanceCounters: [
        {
          name: 'VMInsightsPerfCounters'
          streams: [
            'Microsoft-InsightsMetrics'
          ]
          samplingFrequencyInSeconds: 60
          counterSpecifiers:[
            '\\VmInsights\\DetailedMetrics'
          ]
        }
      ]
      extensions: [
        {
          name: 'DependencyAgentDataSource'
          streams: [
            'Microsoft-ServiceMap'
          ]
          extensionName: 'DependencyAgent'
          extensionSettings: {}

        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          workspaceResourceId: LAW.id
          name: WorkspaceName
        }
      ]
    }
    dataFlows: [
      {
        streams: [
          'Microsoft-InsightsMetrics'
        ]
        destinations: [
          WorkspaceName
        ]
      }
      {
        streams: [
          'Microsoft-ServiceMap'
        ]
        destinations: [
          WorkspaceName
        ]
      }
    ]
  }
}

module DCR_VM_Association 'DCR-VM-Association.bicep' = [for VMName in VMlist:{
  name: 'DCR-${VMName}-${Seed}'
  params: {
    VMName: VMName
//    dataCollectionEndpointId: DCR_VMInsights.id
    dataCollectionRuleId: DCR_VMInsights.id
    Seed: Seed
  }
}]
