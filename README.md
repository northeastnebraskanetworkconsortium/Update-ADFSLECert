# Update-ADFSLECert
This script uses Posh-ACME and Let's Encrypt to update ADFS service communications certificate.  Please note this script is designed to be used on an existing ADFS server, not during the initial setup of ADFS.
## How To Use:

### First Time Setup

If running Windows 2012 / Windows 2012 R2, you must first install PowerShell 5.1, available at [https://aka.ms/WMF5Download](https://aka.ms/WMF5Download).

#### PowerShell version

This script is designed to run on PowerShell 5.1 or greater.  There have been issues on some PowerShell Core, so it is recommended not to use PowerShell Core at this time.  

#### Install Posh-ACME module

Run command to install Posh-ACME:
```powershell
Install-Module -Name Posh-ACME -Scope AllUsers -AcceptLicense
```

#### Request initial certificate
The script is designed to handle the renewals automatically, so you need to request the initial certificate manually.  In PowerShell:

```powershell
New-PACertificate -Domain sts.example.com -AcceptTOS -Contact me@example.com -DnsPlugin Cloudflare -PluginArgs @{CFAuthEmail="me@example.com";CFAuthKey='xxx'}

# If ADFS is not currently installed, stop and do not run the following script until after ADFS is installed and working
# After the above completes, run the following
$MainDomain = 'sts.example.com'

# the '-UseExisting' flag is useful when the certifcate is not yet expired
./Update-ADFSLECert.ps1 -MainDomain $MainDomain -UseExisting
```
### Normal Use
To normally run it:

```powershell
./Update-ADFSLECert.ps1 -MainDomain $MainDomain
```

### Force Renewals

You can force a renewal with the '-ForceRenew' switch:

```powershell
./Update-ADFSLECert.ps1 -MainDomain $MainDomain -ForceRenew
```
### Other Notes

#### Switch Mutual Exclusivity

The '-ForceRenew' and '-UseExisting' switches are mutually exclusive, with '-UseExisting' superceeding '-ForceRenew'.

#### Logging

This script is set to automatically log the process and create a persistent log file in the same directory the script is located.  The name of the log file is UpdateADFS.txt

#### Accessing the certificate(s) directly

Upon a successful request, you can directly access the certificates by visiting the following directory

```powershell
# Issue this command to enter into the Let's Encrypt directory
cd ~\appdata\Local\Posh-ACME\acme-v02.api.letsencrypt.org\

# Next, do a 'cd', then press Tab to auto populate the next directory.  This directory represents your account number.
cd [Tab]

# Perform the 'cd' - Tab again, which will enter into the next directory, which should be the name of the certificate you requested.
cd [Tab]

# Open Windows Explorer to access the certificates via GUI, if desired
start .\
```

### ADFS-LetsEncrypt-Renewal.xml

This XML file is a sample scheduled task that can be imported into the Windows Task Scheduler to handle the automatic renewal process.  There are a few modifications that will need to be made following the import:
- General Tab
    - Change User or Group
        - Use administrator account, either local or domain
- Triggers
    - Change date / time (optional)
- Actions
    - Edit Task
        - Add arguments
            - Change sts.example.com to FQDN of ADFS server
        - Start in
            - Replace with path of actual location of the script

### Troubleshooting

#### Windows 2012 R2

Windows 2012 R2 / ADFS 3.0 does not particularly like certificates with a Cryptography Next Generation (CNG) private key.  As a result, you will likely experience errors when attempting to run the script.  My experiences in troubleshooting this have been inconsistent.  However, after executing the initial run (with the -UseExsiting switch) and receiving an error message, I have found that I can usually get it to work following these steps:
- Use MMC to verify the Let's Encrypt certificate is successfully imported into the certificate store
- Copy the Let's Encrypt certificate thumbprint
- Use Windows Powershell (not Powershell 7) and manually set the certificate thumbprint, using the following command
  ```powershell
  Set-ADFSSSLCertificate -Thumbprint xxxxxx
  ```
- Reboot the server

This seems to help get around the CNG private key issue, for some reason.
