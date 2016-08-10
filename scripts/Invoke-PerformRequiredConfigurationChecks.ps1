[CmdletBinding()]
param()

try {
    $ErrorActionPreference = "Stop"

    Update-DscConfiguration -Wait -Verbose
}
catch {
    $_ | Write-AWSQuickStartException
}