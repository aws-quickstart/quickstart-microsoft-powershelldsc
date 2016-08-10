param(
    [string]$DomainNetBiosName,
    [string]$AdminPassword
)

try {
    $ErrorActionPreference = "Stop"

    Remove-Item $env:systemRoot/system32/configuration/pending.mof -force
    Get-Process *wmi* | stop-process -force
    Restart-Service winrm -force

    $Pass = ConvertTo-SecureString $AdminPassword -AsPlainText -Force
    $Credential = New-Object System.Management.Automation.PSCredential -ArgumentList "$DomainNetBiosName\administrator", $Pass

    Start-DscConfiguration -Path C:\windows\system32\dc1config -Wait -Verbose -Credential $Credential -ErrorVariable ev
}
catch {
    $_ | Write-AWSQuickStartException
}
