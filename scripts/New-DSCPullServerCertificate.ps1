[CmdletBinding()]
param(
    [string]
    $Password,

    [string]
    $Region,

    [string]
    $VpcId
)

try {
    Write-Verbose "Creating c:\inetpub\wwwroot"
    New-Item -ItemType Directory -Path c:\inetpub\wwwroot -ErrorAction Stop

    Write-Verbose "Getting ELB Name"
    $DomainDNSName = Get-ELBLoadBalancer -Region $Region | Where-Object {$_.VpcId -eq $VpcId} | select -ExpandProperty DnsName

    Write-Verbose "Creating Certificate"

    $name = new-object -com "X509Enrollment.CX500DistinguishedName.1"
    $name.Encode("CN=$DomainDNSName", 0)

    $key = new-object -com "X509Enrollment.CX509PrivateKey.1"
    $key.ProviderName = "Microsoft RSA SChannel Cryptographic Provider"
    $key.KeySpec = 1
    $key.Length = 1024
    $key.SecurityDescriptor = "D:PAI(A;;0xd01f01ff;;;SY)(A;;0xd01f01ff;;;BA)(A;;0x80120089;;;NS)"
    $key.MachineContext = 1
    $key.ExportPolicy = 0x1
    $key.Create()

    $serverauthoid = new-object -com "X509Enrollment.CObjectId.1"
    $serverauthoid.InitializeFromValue("1.3.6.1.5.5.7.3.1")
    $ekuoids = new-object -com "X509Enrollment.CObjectIds.1"
    $ekuoids.add($serverauthoid)
    $ekuext = new-object -com "X509Enrollment.CX509ExtensionEnhancedKeyUsage.1"
    $ekuext.InitializeEncode($ekuoids)

    $cert = new-object -com "X509Enrollment.CX509CertificateRequestCertificate.1"
    $cert.InitializeFromPrivateKey(2, $key, "")
    $cert.Subject = $name
    $cert.Issuer = $cert.Subject
    $cert.NotBefore = get-date
    $cert.NotAfter = $cert.NotBefore.AddDays(730)
    $cert.X509Extensions.Add($ekuext)
    $cert.Encode()

    $enrollment = new-object -com "X509Enrollment.CX509Enrollment.1"
    $enrollment.InitializeFromRequest($cert)
    $certdata = $enrollment.CreateRequest(0)
    $enrollment.InstallResponse(2, $certdata, 0, "")

    Write-Verbose "Exporting Certificates"

    $certificate = Get-ChildItem cert:\localmachine\my -ErrorAction Stop | Where-Object { $_.Subject -eq "CN=$DomainDNSName" }

    $mypwd = ConvertTo-SecureString -String $Password -Force –AsPlainText -ErrorAction Stop
    Export-PfxCertificate $certificate.PSPath -FilePath c:\inetpub\wwwroot\dsc.pfx -Password $mypwd -ErrorAction Stop
    Export-Certificate -Cert $certificate -FilePath c:\inetpub\wwwroot\dsc.cer -ErrorAction Stop
    Copy-Item -Path c:\inetpub\wwwroot\dsc.cer -Destination c:\inetpub\wwwroot\dsc.cer.zip -ErrorAction Stop
    Import-PfxCertificate –FilePath c:\inetpub\wwwroot\dsc.pfx -CertStoreLocation Cert:\LocalMachine\Root -Password $mypwd -ErrorAction Stop
    Import-PfxCertificate –FilePath c:\inetpub\wwwroot\dsc.pfx -CertStoreLocation Cert:\LocalMachine\My -Password $mypwd -ErrorAction Stop
}
catch {
    $_ | Write-AWSQuickStartException
}