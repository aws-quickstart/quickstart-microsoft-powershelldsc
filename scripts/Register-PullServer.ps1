[CmdletBinding()]
param(
    [string]
    $Region,

    [string]
    $VpcId
)

try {
    Write-Verbose "Getting ELB Name"
    $ELBName = Get-ELBLoadBalancer -Region $Region | Where-Object {$_.VpcId -eq $VpcId} | select -ExpandProperty LoadBalancerName

    Write-Verbose "Getting Instance Id from instance metadata"
    $InstanceId = (new-object System.Net.WebClient).DownloadString(
        'http://169.254.169.254/latest/meta-data/instance-id'
    )

    Write-Verbose "Registering instance with ELB"
    Register-ELBInstanceWithLoadBalancer -Instances $InstanceId -LoadBalancerName $ELBName -Region $Region -ErrorAction Stop
}
catch{
    $_ | Write-AWSQuickStartException
}