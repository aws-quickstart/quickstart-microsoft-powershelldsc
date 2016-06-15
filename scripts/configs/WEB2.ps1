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
            NodeName = 'WEB2'
            CertificateFile = 'C:\dsc.cer'
        }
    )
}

$Pass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
$Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBiosName\administrator", $Pass

Configuration WEB2Config {
    Import-DscResource -ModuleName xNetworking, xComputerManagement

    Node WEB2 {
        xDnsServerAddress DnsServerAddress { 
            Address        = $ADServer2PrivateIp, $ADServer1PrivateIp
            InterfaceAlias = 'Ethernet' 
            AddressFamily  = 'IPv4' 
        }

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
            DestinationPath = "c:\inetpub\wwwroot\index.html"
            Contents = "<h1>Hello World</h1>"
            DependsOn = "[WindowsFeature]IIS"
        }
    }
}

WEB2Config -ConfigurationData $ConfigurationData
Start-DscConfiguration -Path .\WEB2Config -Wait -Verbose