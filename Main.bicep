targetScope='subscription'
// General
param location string 
param Seed string
param MyObjectId string
@secure()
param adminPassword string

// Resource Group
param HubRgName string = '${Seed}-Demo'

// Virtual Network
param HubVnetName string = 'VNet-${Seed}'
param HubVnetAddressPrefix string 
param PEsubnetName string = 'PE-Subnet'
param PEsubnetAddressPrefix string
param DMZsubnetName string = 'DMZ-Subnet'
param DMZsubnetAddressPrefix string
param BastionSubnetAddressPrefix string
param FirewallSubnetAddressPrefix string
param FirewallManagementSubnetAddressPrefix string
param GatewaySubnetAddressPrefix string
param BastionHostName string = 'Bastion-${Seed}'
param BastionPublicIpName string = 'BastionPublicIp-${Seed}'

param WinCommand string = ''
param LinCommand string = ''
param LinNum int = 0
param WinNum int = 0
param WinVMname string = 'WinVM-${Seed}'
param LinVMname string = 'LinVM-${Seed}'
param CustomDnsServer string =''
param rnd string = substring(uniqueString(utcNow()),0,5)
param vmsize string = 'Standard_B4s_v2'

param WorskspaceName string = 'LA-${Seed}'
param publicNetworkAccess string = 'Enabled'

param KVname string = 'KV-${Seed}'
//param SSHPublickey string


// Hub Resource Group Deploy
resource HubRG 'Microsoft.Resources/resourceGroups@2021-01-01' existing = {
  name: HubRgName
}

// Hub Virtual Network Deploy
module HubDeploy 'src/HubDeploy.bicep' = {
  name: 'HubVnet'
  scope: HubRG
  params: {
    location: location
    Seed: Seed
    MyObjectId: MyObjectId
    adminPassword: adminPassword
    HubVnetName: HubVnetName
    BastionSubnetAddressPrefix: BastionSubnetAddressPrefix
    FirewallSubnetAddressPrefix: FirewallSubnetAddressPrefix
    FirewallManagementSubnetAddressPrefix: FirewallManagementSubnetAddressPrefix
    GatewaySubnetAddressPrefix: GatewaySubnetAddressPrefix
    HubVnetAddressPrefix: HubVnetAddressPrefix
    PEsubnetAddressPrefix: PEsubnetAddressPrefix
    PEsubnetName: PEsubnetName
    DMZsubnetAddressPrefix: DMZsubnetAddressPrefix
    DMZsubnetName: DMZsubnetName
    BastionHostName: BastionHostName
    BastionPublicIpName: BastionPublicIpName
  }
 }

 module LAW './src/LAworkspace.bicep' ={
  dependsOn: [HubDeploy]
  name: WorskspaceName
  scope: HubRG
  params: {
    WorkspaceName: WorskspaceName
    publicNetworkAccess : publicNetworkAccess
  }
}
 
module SqlVM 'src/SQLVM.bicep' = [for i in range(1, WinNum): {
  dependsOn: [HubDeploy]
  name: 'SQL-${Seed}-${rnd}-${i}'
  scope: HubRG
  params: {
    vmName: 'SQL-${i}'
    adminUsername: 'gdradmin'
    adminPassword: adminPassword   
    VirtualNetworkName: HubVnetName
    SubnetName: DMZsubnetName
    location: location
    vmSize: vmsize
    Offer:  'sql2019-ws2019'
    sqlSku: 'standard-gen2'
  }
}]
/*
module AKS 'src/AKS.bicep' = {
  dependsOn: [LAW]
  name: 'AKS-${Seed}'
  scope: HubRG
  params: {
    location: location
    clusterName: 'AKS-${Seed}'
    LAWName: WorskspaceName
    Seed: Seed
    SSHPublicKey: SSHPublickey
  }
}*/

output SqlVMsName array = [for i in range(0,WinNum):{
  name: SqlVM[i].outputs.hostname
}]
output HubVnetName string = HubVnetName
output PEsubnetName string = PEsubnetName
output KvName string =  KVname
//output AKSName string = AKS.name
output laWname string = WorskspaceName
