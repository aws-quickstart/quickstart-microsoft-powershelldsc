[CmdletBinding()]
param(
    [string]
    $Password,

    [string]
    $PullServer1PrivateIp,

    [string]
    $InstanceName
)

try {
    Write-Verbose "Downloading http://$PullServer1PrivateIp/dsc.pfx"
    ((new-object net.webclient).DownloadFile(
        "http://$PullServer1PrivateIp/dsc.pfx",
        'c:\cfn\scripts\dsc.pfx'        
    ))

    if($InstanceName -eq 'PULL2') {
        Write-Verbose "Downloading http://$PullServer1PrivateIp/dsc.cer.zip"
        ((new-object net.webclient).DownloadFile(
            "http://$PullServer1PrivateIp/dsc.cer.zip",
            'c:\inetpub\wwwroot\dsc.cer'        
        ))    
    }

    Write-Verbose "Creating secure password"
    $pass = ConvertTo-SecureString $Password -AsPlainText -Force -ErrorAction Stop

    Write-Verbose "Importing dsc.pfx into personal store"
    Import-PfxCertificate -FilePath c:\cfn\scripts\dsc.pfx -CertStoreLocation Cert:\LocalMachine\My -Password $pass -ErrorAction Stop

    Write-Verbose "Importing dsc.pfx into trusted root store"
    Import-PfxCertificate –FilePath c:\cfn\scripts\dsc.pfx -CertStoreLocation Cert:\LocalMachine\Root -Password $pass -ErrorAction Stop
}

catch {
    $_ | Write-AWSQuickStartException
}

