Param(
    [string]$MainDomain,
    [string]$ProxyHostName,
    [string]$ProxyUserName = $env:USERNAME,
    [string]$ProxyIdentityPath = "$HOME\.ssh\id_rsa",
    [switch]$UseExisting,
    [switch]$ForceRenew
)

function Logging {
    param([string]$Message)
    Write-Host $Message
    $Message >> $LogFile
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

Import-Module PKI
Import-Module ADFS
Import-Module Posh-Acme
$LogFile = '.\UpdateADFS.log'
Get-Date | Out-File $LogFile -Append
if($UseExisting) {
    Logging -Message "Using Existing Certificate"
    $cert = get-pacertificate -MainDomain $MainDomain
}
else {
    if($ForceRenew) {
        Logging -Message "Starting Forced Certificate Renewal"
        $cert = Submit-Renewal -MainDomain $MainDomain -Force
    }
    else {
        Logging -Message "Starting Certificate Renewal"
        $cert = Submit-Renewal -MainDomain $MainDomain
    }
    Logging -Message "...Renew Complete!"
}

if($cert){
    Logging -Message "Importing certificate to Cert:\LocalMachine\My"
    Import-PfxCertificate -FilePath $cert.PfxFullChain -CertStoreLocation Cert:\LocalMachine\My -Password ('poshacme' | ConvertTo-SecureString -AsPlainText -Force)
    Logging -Message "Updating ADFS Certificate"
    Set-AdfsSslCertificate -Thumbprint $cert.Thumbprint -Member FPS-SSO
    Set-AdfsCertificate -CertificateType Service-Communications -Thumbprint $cert.Thumbprint
    
    Logging -Message "Restarting adfssrv"
    Restart-Service adfssrv
    
    # Remove old certs
    ls Cert:\LocalMachine\My | ? Subject -eq "CN=$MainDomain" | ? NotAfter -lt $(get-date) | remove-item -Force

    # Create session to ADFS Proxy Server
    if($ProxyHostName){
        $session = New-PSSession -HostName $ProxyHostName -UserName $ProxyUserName -IdentityFilePath $ProxyIdentityPath
        Copy-Item $cert.PFXFullChain C:\ -ToSession $session
        Invoke-Command -Session $session -ScriptBlock{param ($cert);Import-PfxCertificate -FilePath C:\fullchain.pfx -CertStoreLocation Cert:\LocalMachine\My -Password ('poshacme' | ConvertTo-SecureString -AsPlainText -Force);Set-WebApplicationProxySslCertificate -Thumbprint $cert.Thumbprint} -ArgumentList $cert
        Exit-PSSession
    }
}else{
    Logging -Message "No need to update ADFS certifcate" 
}
