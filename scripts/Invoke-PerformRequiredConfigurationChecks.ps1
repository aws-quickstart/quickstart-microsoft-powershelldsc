[CmdletBinding()]
param(
    [string]$Instance,
    [string]$Region
    )

try {
    Write-Verbose "Calling PerformRequiredConfigurationChecks method with flag 1"
    Invoke-CimMethod -Namespace root/Microsoft/Windows/DesiredStateConfiguration -ClassName MSFT_DSCLocalConfigurationManager -Method PerformRequiredConfigurationChecks -Arguments @{Flags = [System.UInt32]1} -ErrorAction Stop
}
catch {
    $_ | Write-AWSQuickStartException
}