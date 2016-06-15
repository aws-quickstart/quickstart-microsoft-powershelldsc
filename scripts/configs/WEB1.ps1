param(
    [string]$DomainDNSName,
    [string]$DomainNetBiosName,
    [string]$AdminPassword,
    [string]$ADServer1PrivateIp,
    [string]$ADServer2PrivateIp
    )

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
            NodeName = 'WEB1'
            CertificateFile = 'C:\dsc.cer'
        }
    )
}

$Pass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBiosName\administrator", $Pass

Configuration WEB1Config {
    Import-DscResource -ModuleName xNetworking, xComputerManagement

    Node WEB1 {
        xDnsServerAddress DnsServerAddress { 
            Address        = $ADServer1PrivateIp, $ADServer2PrivateIp
            InterfaceAlias = 'Ethernet' 
            AddressFamily  = 'IPv4' 
        }

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
}

WEB1Config -ConfigurationData $ConfigurationData
Start-DscConfiguration -Path .\WEB1Config -Wait -Verbose