[CmdletBinding()]
param()

try {
    $ErrorActionPreference = "Stop"

    # Check to ensure that Pull Server intances behind ELB are ready
    foreach ($item in $(Get-DscLocalConfigurationManager).DownloadManagerCustomData) {
        if ($item.key -eq 'ServerUrl') {
            $PullServerUrl = $item.Value
        }
    }
    if (-not $PullServerUrl) {
        throw "Unable to retrieve a Pull Server URL from Get-DscLocalConfigurationManager"
    }
    $tries = 20
    while (-not $(try{Invoke-RestMethod $PullServerUrl} catch{}) -and $tries -ge 1) {
        $tries--
        Write-Verbose "$PullServerUrl not ready. Sleeping for 30 seconds..."
        Start-Sleep -Seconds 30
    }

    Update-DscConfiguration -Wait -Verbose -ErrorVariable ev
}
catch {
    $_ | Write-AWSQuickStartException
}