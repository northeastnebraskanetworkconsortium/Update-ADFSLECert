
Param(
    [string]$MainDomain,
    [switch]$UseExsiting,
    [switch]$ForceRenew
)

function Logging {
    param([string]$Message)
    Write-Host $Message
    $Message >> $LogFile
}

Import-Module PKI -SkipEditionCheck
Import-Module ADFS -SkipEditionCheck
Import-Module Posh-Acme
$LogFile = '.\UpdateADFS.log'
Get-Date | Out-File $LogFile -Append
if($UseExsiting) {
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
    Set-AdfsSslCertificate -Thumbprint $cert.Thumbprint
    
    Logging -Message "Restarting adfssrv"
    Restart-Service adfssrv
    
    # Remove old certs
    ls Cert:\LocalMachine\My | ? Subject -eq "CN=$MainDomain" | ? NotAfter -lt $(get-date) | remove-item -Force
}else{
    Logging -Message "No need to update ADFS certifcate" 
}