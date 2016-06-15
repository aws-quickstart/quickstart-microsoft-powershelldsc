param(
    [string]$DomainDNSName,
    [string]$DomainNetBiosName,
    [string]$AdminPassword,
    [string]$ADServer1PrivateIp,
    [string]$ADServer2PrivateIp,
    [string]$PrivateSubnet1CIDR,
    [string]$PrivateSubnet2CIDR
    )

Import-Module $psscriptroot\IPHelper.psm1

Configuration LCMConfig {
    LocalConfigurationManager {
        RebootNodeIfNeeded = $true
        CertificateID = (Get-ChildItem Cert:\LocalMachine\My)[0].Thumbprint
    }
}

LCMConfig
Set-DscLocalConfigurationManager -Path .\LCMConfig

$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = 'DC2'
            CertificateFile = 'C:\dsc.cer'
        }
    )
}

$Pass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBiosName\administrator", $Pass

Configuration DC2Config {
    Import-DscResource -ModuleName xNetworking, xActiveDirectory, xComputerManagement

    Node DC2 {
        cIPAddress DC2IPAddress {
            InterfaceAlias = 'Ethernet'
            IPAddress = $ADServer2PrivateIp
            DefaultGateway = (Get-AWSDefaultGateway -IPAddress $ADServer2PrivateIp)
            SubnetMask = (Get-AWSSubnetMask -SubnetCIDR $PrivateSubnet2CIDR)         
        }

        xDnsServerAddress DnsServerAddress { 
            Address        = $ADServer1PrivateIp
            InterfaceAlias = 'Ethernet' 
            AddressFamily  = 'IPv4' 
            DependsOn = '[cIPAddress]DC2IPAddress'
        }

        WindowsFeature ADDSInstall {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
            DependsOn = '[cIPAddress]DC2IPAddress'
        }

        WindowsFeature ADDSToolsInstall {
            Ensure = 'Present'
            Name = 'RSAT-ADDS-Tools'
        }

        xADDomainController ActiveDirectory {
            DomainName = $DomainDNSName
            DomainAdministratorCredential = $Credential
            SafemodeAdministratorPassword = $Credential
            DependsOn = '[WindowsFeature]ADDSInstall'
        }
    }
}

DC2Config -ConfigurationData $ConfigurationData
Start-DscConfiguration -Path .\DC2Config -Wait -Verbose