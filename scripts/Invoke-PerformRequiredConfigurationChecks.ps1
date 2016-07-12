[CmdletBinding()]
param()

try {
    Update-DscConfiguration -Wait -Verbose
}
catch {
    $_ | Write-AWSQuickStartException
}