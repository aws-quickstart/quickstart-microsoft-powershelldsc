[CmdletBinding()]
param()

try {
    $ErrorActionPreference = "Stop"

    # Check to ensure that Pull Server intances behind ELB are ready
    $PullServerUrl = $(Get-DscLocalConfigurationManager).DownloadManagerCustomData.ServerUrl
    $tries = 20
    while (-not $(try{Invoke-RestMethod $PullServerUrl -UseBasicParsing} catch{}) -and $tries -ge 1) {
        $tries--
        Write-Verbose "$PullServerUrl not ready. Sleeping for 30 seconds..."
        Start-Sleep -Seconds 30
    }

    Update-DscConfiguration -Wait -Verbose -ErrorVariable ev
}
catch {
    $_ | Write-AWSQuickStartException
}