@description('The name of the VM')
param vmName string = 'mySqlVM'

@description('The virtual machine size.')
param vmSize string = 'Standard_B2s'

@description('Specify the name of an existing VNet in the same resource group')
param VirtualNetworkName string

@description('Specify the resrouce group of the existing VNet')
param VnetResourceGroup string = resourceGroup().name

@description('Specify the name of the Subnet Name')
param SubnetName string

@description('Windows Server and SQL Offer')
@allowed([
  'sql2019-ws2019'
  'sql2017-ws2019'
  'sql2019-ws2022'
  'SQL2016SP1-WS2016'
  'SQL2016SP2-WS2016'
  'SQL2014SP3-WS2012R2'
  'SQL2014SP2-WS2012R2'
])
param Offer string = 'sql2019-ws2022'

@description('SQL Server Sku')
@allowed([
  'standard-gen2'
  'enterprise-gen2'
  'SQLDEV-gen2'
  'web-gen2'
  'enterprisedbengineonly-gen2'
])
param sqlSku string = 'standard-gen2'

@description('The admin user name of the VM')
param adminUsername string

@description('The admin password of the VM')
@secure()
param adminPassword string

@description('SQL Server Workload Type')
@allowed([
  'General'
  'OLTP'
  'DW'
])
param storageWorkloadType string = 'General'

@description('Amount of data disks (1TB each) for SQL Data files')
@minValue(1)
@maxValue(8)
param sqlDataDisksCount int = 1

@description('Path for SQL Data files. Please choose drive letter from F to Z, and other drives from A to E are reserved for system')
param dataPath string = 'F:\\SQLData'

@description('Amount of data disks (1TB each) for SQL Log files')
@minValue(1)
@maxValue(8)
param sqlLogDisksCount int = 1

@description('Path for SQL Log files. Please choose drive letter from F to Z and different than the one used for SQL data. Drive letter from A to E are reserved for system')
param logPath string = 'G:\\SQLLog'

@description('Location for all resources.')
param location string = resourceGroup().location

@description('Security Type of the Virtual Machine.')
@allowed([
  'Standard'
  'TrustedLaunch'
])
param securityType string = 'TrustedLaunch'

var securityProfileJson = {
  uefiSettings: {
    secureBootEnabled: true
    vTpmEnabled: true
  }
  securityType: securityType
}

var networkInterfaceName = '${vmName}-nic'
var networkSecurityGroupName = '${vmName}-nsg'
var networkSecurityGroupRules = [
  {
    name: 'RDP'
    properties: {
      priority: 300
      protocol: 'Tcp'
      access: 'Allow'
      direction: 'Inbound'
      sourceAddressPrefix: '*'
      sourcePortRange: '*'
      destinationAddressPrefix: '*'
      destinationPortRange: '3389'
    }
  }
]
var publicIpAddressName = '${vmName}-publicip-${uniqueString(vmName)}'
var publicIpAddressType = 'Dynamic'
var publicIpAddressSku = 'Basic'
var diskConfigurationType = 'NEW'
var nsgId = networkSecurityGroup.id
var subnetRef = resourceId(VnetResourceGroup, 'Microsoft.Network/virtualNetWorks/subnets', VirtualNetworkName, SubnetName)
var dataDisksLuns = range(0, sqlDataDisksCount)
var logDisksLuns = range(sqlDataDisksCount, sqlLogDisksCount)
var dataDisks = {
  createOption: 'Empty'
  caching: 'ReadOnly'
  writeAcceleratorEnabled: false
  storageAccountType: 'Premium_LRS'
  diskSizeGB: 1023
}
var tempDbPath = 'G:\\SQLTemp'
var extensionName = 'GuestAttestation'
var extensionPublisher = 'Microsoft.Azure.Security.WindowsAttestation'
var extensionVersion = '1.0'
var maaTenantName = 'GuestAttestation'

resource publicIpAddress 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: publicIpAddressSku
  }
  properties: {
    publicIPAllocationMethod: publicIpAddressType
  }
}

resource networkSecurityGroup 'Microsoft.Network/networkSecurityGroups@2022-01-01' = {
  name: networkSecurityGroupName
  location: location
  properties: {
    securityRules: networkSecurityGroupRules
  }
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-01-01' = {
  name: networkInterfaceName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAllocationMethod: 'Dynamic'
          publicIPAddress: {
            id: publicIpAddress.id
          }
        }
      }
    ]
    enableAcceleratedNetworking: true
    networkSecurityGroup: {
      id: nsgId
    }
  }
}

resource vm 'Microsoft.Compute/virtualMachines@2022-03-01' = {
  name: vmName
  location: location
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      dataDisks: [for j in range(0, length(range(0, (sqlDataDisksCount + sqlLogDisksCount)))): {
        lun: range(0, (sqlDataDisksCount + sqlLogDisksCount))[j]
        createOption: dataDisks.createOption
        caching: ((range(0, (sqlDataDisksCount + sqlLogDisksCount))[j] >= sqlDataDisksCount) ? 'None' : dataDisks.caching)
        writeAcceleratorEnabled: dataDisks.writeAcceleratorEnabled
        diskSizeGB: dataDisks.diskSizeGB
        managedDisk: {
          storageAccountType: dataDisks.storageAccountType
        }
      }]
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'Premium_LRS'
        }
      }
      imageReference: {
        publisher: 'MicrosoftSQLServer'
        offer: Offer
        sku: sqlSku
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      windowsConfiguration: {
        enableAutomaticUpdates: true
        provisionVMAgent: true
      }
    }
    securityProfile: ((securityType == 'TrustedLaunch') ? securityProfileJson : null)
  }
}

resource vmName_extension 'Microsoft.Compute/virtualMachines/extensions@2022-03-01' = if ((securityType == 'TrustedLaunch') && ((securityProfileJson.uefiSettings.secureBootEnabled == true) && (securityProfileJson.uefiSettings.vTpmEnabled == true))) {
  parent: vm
  name: extensionName
  location: location
  properties: {
    publisher: extensionPublisher
    type: extensionName
    typeHandlerVersion: extensionVersion
    autoUpgradeMinorVersion: true
    enableAutomaticUpgrade: true
    settings: {
      AttestationConfig: {
        MaaSettings: {
          maaEndpoint: ''
          maaTenantName: maaTenantName
        }
        AscSettings: {
          ascReportingEndpoint: ''
          ascReportingFrequency: ''
        }
        useCustomToken: 'false'
        disableAlerts: 'false'
      }
    }
  }
}

resource Microsoft_SqlVirtualMachine_sqlVirtualMachines_virtualMachine 'Microsoft.SqlVirtualMachine/sqlVirtualMachines@2022-07-01-preview' = {
  name: vmName
  location: location
  properties: {
    virtualMachineResourceId: vm.id
    sqlManagement: 'Full'
    sqlServerLicenseType: 'PAYG'
    storageConfigurationSettings: {
      diskConfigurationType: diskConfigurationType
      storageWorkloadType: storageWorkloadType
      sqlDataSettings: {
        luns: dataDisksLuns
        defaultFilePath: dataPath
      }
      sqlLogSettings: {
        luns: logDisksLuns
        defaultFilePath: logPath
      }
      sqlTempDbSettings: {
        defaultFilePath: tempDbPath
      }
    }
  }
}

output hostname string = vm.properties.osProfile.computerName
