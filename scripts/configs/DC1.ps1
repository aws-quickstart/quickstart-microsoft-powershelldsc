param(
    [string]$DomainDNSName,
    [string]$DomainNetBiosName,
    [string]$AdminPassword,
    [string]$ADServer1PrivateIp,
    [string]$ADServer2PrivateIp,
    [string]$PrivateSubnet1CIDR,
    [string]$PrivateSubnet2CIDR,
    [string]$DMZ1CIDR,
    [string]$DMZ2CIDR
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
            NodeName = 'DC1'
            CertificateFile = 'C:\dsc.cer'
        }
    )
}

$Pass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBiosName\administrator", $Pass

Configuration DC1Config {
    Import-DscResource -ModuleName xNetworking, xActiveDirectory, xComputerManagement

    Node DC1 {
        cIPAddress DCIPAddress {
            InterfaceAlias = 'Ethernet'
            IPAddress = $ADServer1PrivateIp
            DefaultGateway = (Get-AWSDefaultGateway -IPAddress $ADServer1PrivateIp)
            SubnetMask = (Get-AWSSubnetMask -SubnetCIDR $PrivateSubnet1CIDR)         
        }

        xDnsServerAddress DnsServerAddress { 
            Address        = $ADServer1PrivateIp
            InterfaceAlias = 'Ethernet' 
            AddressFamily  = 'IPv4' 
            DependsOn = '[cIPAddress]DCIPAddress'
        } 

        WindowsFeature ADDSInstall {
            Ensure = 'Present'
            Name = 'AD-Domain-Services'
            DependsOn = '[cIPAddress]DCIPAddress'
        }

        WindowsFeature ADDSToolsInstall {
            Ensure = 'Present'
            Name = 'RSAT-ADDS-Tools'
        }

        xADDomain ActiveDirectory {
            DomainName = $DomainDNSName
            DomainAdministratorCredential = $Credential
            SafemodeAdministratorPassword = $Credential
            DependsOn = '[WindowsFeature]ADDSInstall'
        }

        cADSubnet AZ1Subnet1 {
            Name = $PrivateSubnet1CIDR
            Site = 'Default-First-Site-Name'
            Credential = $Credential
            DependsOn = '[xADDomain]ActiveDirectory'
        }

        cADSubnet AZ1Subnet2 {
            Name = $DMZ1CIDR
            Site = 'Default-First-Site-Name'
            Credential = $Credential
            DependsOn = '[xADDomain]ActiveDirectory'
        }

        cADSite AZ2Site {
            Name = 'AZ2'
            DependsOn = '[WindowsFeature]ADDSInstall'
            Credential = $Credential
        }

        cADSubnet AZ2Subnet1 {
            Name = $PrivateSubnet2CIDR
            Site = 'AZ2'
            Credential = $Credential
            DependsOn = '[cADSite]AZ2Site'
        }

        cADSubnet AZ2Subnet2 {
            Name = $DMZ2CIDR
            Site = 'AZ2'
            Credential = $Credential
            DependsOn = '[cADSite]AZ2Site'
        }

        cADSiteLinkUpdate SiteLinkUpdate {
            Name = 'DEFAULTIPSITELINK'
            SitesIncluded = 'AZ2'
            Credential = $Credential
            DependsOn = '[cADSubnet]AZ2Subnet1'
        }
    }
}

DC1Config -ConfigurationData $ConfigurationData
Start-DscConfiguration -Path .\DC1Config -Wait -Verbose