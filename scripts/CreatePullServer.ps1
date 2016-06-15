Configuration CreatePullServer {
    param(
        [string[]]$Computername
    )

    Import-DscResource -ModuleName xPSDesiredStateConfiguration

    Node $Computername {
        WindowsFeature DSCServiceFeature {
            Ensure = "Present"
            Name = "DSC-Service"
        }

        xDSCWebService PSDSCPullServer {
            Ensure = "Present"
            EndpointName = "PSDSCPullServer"
            Port = 8080
            PhysicalPath = "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer"
            CertificateThumbPrint = (Get-ChildItem Cert:\LocalMachine\My)[0].Thumbprint
            ModulePath = "$env:ProgramFiles\WindowsPowerShell\DscService\Modules"
            ConfigurationPath = "$env:ProgramFiles\WindowsPowerShell\DscService\Configuration"
            State = "Started"
            DependsOn = "[WindowsFeature]DSCServiceFeature"
        }
    }
}

CreatePullServer -Computername $env:COMPUTERNAME -OutputPath c:\DSC
Start-DscConfiguration -Path c:\DSC -Wait