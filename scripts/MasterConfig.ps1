param(
    [string]$DomainDNSName,
    [string]$DomainNetBiosName,
    [string]$AdminPassword,
    [string]$ADServer1PrivateIp,
    [string]$ADServer2PrivateIp,
    [string]$PrivateSubnet1CIDR,
    [string]$PrivateSubnet2CIDR,
    [string]$DMZ1CIDR,
    [string]$DMZ2CIDR,
    [string]$Region,
    [string]$VpcId
    )

#Get the FQDN of the Load Balancer
$PullServer = Get-ELBLoadBalancer -Region $Region | Where-Object {$_.VpcId -eq $VpcId} | select -ExpandProperty DnsName

#Helper functions
Import-Module $psscriptroot\Get-EC2InstanceGuid.psm1
Import-Module $psscriptroot\IPHelper.psm1

#Node Configuration Settings
$ConfigurationData = @{
    AllNodes = @(
        @{
            NodeName = '*'
            CertificateFile = 'C:\inetpub\wwwroot\dsc.cer'
            Thumbprint = (Get-ChildItem Cert:\LocalMachine\My | Where-Object { $_.Subject -eq "CN=$PullServer" })[0].Thumbprint
        },
        @{
            NodeName = 'RDGW1'
            Guid = (Get-EC2InstanceGuid -InstanceName RDGW1)
            AvailabilityZone = 'AZ1'
        },
        @{
            NodeName = 'RDGW2'
            Guid = (Get-EC2InstanceGuid -InstanceName RDGW2)
            AvailabilityZone = 'AZ2'
        },
        @{
            NodeName = 'WEB1'
            Guid = (Get-EC2InstanceGuid -InstanceName WEB1)
            AvailabilityZone = 'AZ1'
        },
        @{
            NodeName = 'WEB2'
            Guid = (Get-EC2InstanceGuid -InstanceName WEB2)
            AvailabilityZone = 'AZ2'
        },
        @{
            NodeName = 'DC1'
            Guid = (Get-EC2InstanceGuid -InstanceName DC1)
        },
        @{
            NodeName = 'DC2'
            Guid = (Get-EC2InstanceGuid -InstanceName DC2)
        }
    )
}

#Credentials used for creating & joining the AD Domain
$Pass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBiosName\administrator", $Pass

#Master Configuration for all nodes in deployment
Configuration ServerBase {
    Import-DscResource -ModuleName xNetworking, xActiveDirectory, xComputerManagement

    Node $AllNodes.Where{$_.AvailabilityZone -eq 'AZ1'}.NodeName {
        xDnsServerAddress DnsServerAddress { 
            Address        = $ADServer1PrivateIp, $ADServer2PrivateIp
            InterfaceAlias = 'Ethernet' 
            AddressFamily  = 'IPv4' 
        }                         
    }

    Node $AllNodes.Where{$_.AvailabilityZone -eq 'AZ2'}.NodeName {
        xDnsServerAddress DnsServerAddress { 
            Address        = $ADServer2PrivateIp, $ADServer1PrivateIp
            InterfaceAlias = 'Ethernet' 
            AddressFamily  = 'IPv4' 
        }                         
    }

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

    Node RDGW1 {
        WindowsFeature RDGateway {
            Name = 'RDS-Gateway'
            Ensure = 'Present'
        }

        WindowsFeature RDGatewayTools {
            Name = 'RSAT-RDS-Gateway'
            Ensure = 'Present'
        }

        xComputer JoinDomain {
            Name = 'RDGW1'
            DomainName = $DomainDNSName
            Credential = $Credential
            DependsOn = "[xDnsServerAddress]DnsServerAddress"
        }
    }

    Node RDGW2 {
        WindowsFeature RDGateway {
            Name = 'RDS-Gateway'
            Ensure = 'Present'
        }

        WindowsFeature RDGatewayTools {
            Name = 'RSAT-RDS-Gateway'
            Ensure = 'Present'
        }

        xComputer JoinDomain {
            Name = 'RDGW2'
            DomainName = $DomainDNSName
            Credential = $Credential
            DependsOn = "[xDnsServerAddress]DnsServerAddress"
        }
    }

    Node WEB1 {
        xComputer JoinDomain {
            Name = 'WEB1'
            DomainName = $DomainDNSName
            Credential = $Credential
            DependsOn = "[xDnsServerAddress]DnsServerAddress"
        }

        WindowsFeature IIS {
            Ensure = 'Present'
            Name = 'Web-Server'
        }

        WindowsFeature AspNet45 {
            Ensure = 'Present'
            Name = 'Web-Asp-Net45'
        }

        WindowsFeature IISConsole {
            Ensure = 'Present'
            Name = 'Web-Mgmt-Console'            
        }

        File default {
            DestinationPath = "c:\inetpub\wwwroot\index.html"
            Contents = "<h1>Hello World</h1>"
            DependsOn = "[WindowsFeature]IIS"
        }
    }

    Node WEB2 {
        xComputer JoinDomain {
            Name = 'WEB2'
            DomainName = $DomainDNSName
            Credential = $Credential
            DependsOn = "[xDnsServerAddress]DnsServerAddress"
        }

        WindowsFeature IIS {
            Ensure = 'Present'
            Name = 'Web-Server'
        }

        WindowsFeature AspNet45 {
            Ensure = 'Present'
            Name = 'Web-Asp-Net45'
        }

        WindowsFeature IISConsole {
            Ensure = 'Present'
            Name = 'Web-Mgmt-Console'            
        }

        File default {
            DestinationPath = "c:\inetpub\wwwroot\index.aspx"
            Contents = "<h1>Hello World</h1>"
            DependsOn = "[WindowsFeature]IIS"
        }
    }
}

#Compile and rename the MOF files
$mofFiles = ServerBase -ConfigurationData $ConfigurationData

foreach($mofFile in $mofFiles) {
   $guid = ($ConfigurationData.AllNodes | Where-Object {$_.NodeName -eq $mofFile.BaseName}).Guid
   $dest = "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration\$($guid).mof"
   Move-Item -Path $mofFile.FullName -Destination $dest
   New-DSCCheckSum $dest
}