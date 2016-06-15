function Get-EC2InstanceGuid {
    [CmdletBinding()]
    param(
        $InstanceName
    )

    try {
        Write-Verbose "Downloading CFN Template"
        $wc = new-object System.Net.WebClient
        $template = $wc.DownloadString('https://s3.amazonaws.com/quickstart-reference/microsoft/powershelldsc/latest/templates/Template_1_DSC.template') | ConvertFrom-Json
    
        Write-Verbose "Retrieving instance guid"
        $guid = $template.Resources.$InstanceName.Properties.Tags.where{$_.key -eq 'guid'}.value

        Write-Output $guid    
    }
    catch {
        $_ | Write-AWSQuickStartException
    }
}