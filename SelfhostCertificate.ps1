# ==============================
# CONFIGURATION
# ==============================

$CertName = "SmartAPI"
$CN = "localhost"
# Cloudflare HTTPS supported ports
$AllowedPorts = @(443,2053,2083,2087,2096,8443)

do {
    Write-Host ""
    Write-Host "Choose Cloudflare HTTPS port:"
    Write-Host "1) 443"
    Write-Host "2) 2053"
    Write-Host "3) 2083"
    Write-Host "4) 2087"
    Write-Host "5) 2096"
    Write-Host "6) 8443"
    Write-Host ""

    $choice = Read-Host "Select option (1-6)"

    switch ($choice) {
        "1" { $Port = 443 }
        "2" { $Port = 2053 }
        "3" { $Port = 2083 }
        "4" { $Port = 2087 }
        "5" { $Port = 2096 }
        "6" { $Port = 8443 }
        default { 
            $Port = $null
            Write-Host "Invalid selection. Please choose a number between 1 and 6." -ForegroundColor Red
        }
    }

} until ($Port)
$AppId = "{0}" -f ([guid]::NewGuid().ToString("B"))
$OpenSSLPath = "C:\Program Files\OpenSSL-Win64\bin"

# ==============================
# LOGGING SETUP
# ==============================

$LogFile = Join-Path $PSScriptRoot ("SelfhostCertificate_{0}.log" -f (Get-Date -Format "yyyyMMdd_HHmmss"))

function Write-Log {
    param([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "$timestamp - $Message"
    Add-Content -Path $LogFile -Value $line
    Write-Host $line
}

# ==============================
# CHECK / INSTALL OPENSSL (LOCAL INSTALLER)
# ==============================

$InstallerName = "Win64OpenSSL_Light-3_6_1.exe"
$InstallerPath = Join-Path $PSScriptRoot $InstallerName
$OpenSSLPath = "C:\Program Files\OpenSSL-Win64\bin"
$OpenSSLExe = Join-Path $OpenSSLPath "openssl.exe"

if (!(Test-Path $OpenSSLExe)) {

    Write-Log "OpenSSL not found. Installing from local installer..."

    if (!(Test-Path $InstallerPath)) {
        Write-Log "ERROR: Installer not found in script folder."
        throw "OpenSSL installer missing."
    }

    Start-Process `
        -FilePath $InstallerPath `
        -ArgumentList "/silent /verysilent /sp- /suppressmsgboxes" `
        -Wait

    Start-Sleep -Seconds 3

    if (!(Test-Path $OpenSSLExe)) {
        Write-Log "ERROR: OpenSSL installation failed."
        throw "OpenSSL installation failed."
    }

    Write-Log "OpenSSL installed successfully."
}
else {
    Write-Log "OpenSSL already installed."
}

# ==============================
# GENERATE RANDOM PASSWORD
# ==============================

$PasswordPlain = -join ((48..57 + 65..90 + 97..122) | Get-Random -Count 20 | ForEach-Object {[char]$_})
$PasswordSecure = ConvertTo-SecureString $PasswordPlain -AsPlainText -Force

Write-Log "Generated certificate password."

# ==============================
# MOVE TO OPENSSL FOLDER
# ==============================

Set-Location $OpenSSLPath

Write-Log "Go to SSL location"

# ==============================
# GENERATE PRIVATE KEY
# ==============================

.\openssl.exe genpkey `
    -algorithm RSA `
    -pkeyopt rsa_keygen_bits:4096 `
    -out "$CertName.key" `
    -aes256 `
    -pass pass:$PasswordPlain

Write-Log "Generate private key"

# ==============================
# CREATE CSR
# ==============================

.\openssl.exe req `
    -new `
    -key "$CertName.key" `
    -out "$CertName.csr" `
    -subj "/C=PT/ST=Lisbon/L=Lisbon/O=Smartdigit/OU=Smartdigit/CN=$CN" `
    -passin pass:$PasswordPlain

Write-Log "Generate csr"

# ==============================
# CREATE SELF-SIGNED CERT
# ==============================

.\openssl.exe x509 `
    -req `
    -days 36500 `
    -in "$CertName.csr" `
    -signkey "$CertName.key" `
    -out "$CertName.crt" `
    -passin pass:$PasswordPlain

Write-Log "Generate self-signed cert"

# ==============================
# EXPORT TO PFX
# ==============================

.\openssl.exe pkcs12 `
    -export `
    -out "$CertName.p12" `
    -inkey "$CertName.key" `
    -in "$CertName.crt" `
    -passin pass:$PasswordPlain `
    -passout pass:$PasswordPlain

Write-Log "Export to PFX"

# ==============================
# DELETE OLD CERTIFICATES
# ==============================

$oldCert = Get-ChildItem Cert:\LocalMachine\My |
           Where-Object { $_.Subject -like "*CN=$CN*" } |
           Sort-Object NotAfter -Descending |
           Select-Object -First 1

if ($oldCert) {
    Remove-Item "Cert:\LocalMachine\My\$($oldCert.Thumbprint)" -Force
    Remove-Item "Cert:\LocalMachine\Root\$($oldCert.Thumbprint)" -Force -ErrorAction SilentlyContinue
}

Write-Log "Old certificate delted from My and Trusted Root."

# ==============================
# IMPORT CERTIFICATE
# ==============================

$cert = Import-PfxCertificate `
    -FilePath "$OpenSSLPath\$CertName.p12" `
    -CertStoreLocation Cert:\LocalMachine\My `
    -Password $PasswordSecure `
    -Exportable

Import-Certificate `
    -FilePath "$OpenSSLPath\$CertName.crt" `
    -CertStoreLocation Cert:\LocalMachine\Root | Out-Null

Write-Log "Certificate imported to My and Trusted Root."

# ==============================
# GET THUMBPRINT
# ==============================

$thumbprint = (Get-ChildItem Cert:\LocalMachine\My |
    Where-Object { $_.Subject -like "*CN=$CN*" } |
    Sort-Object NotAfter -Descending |
    Select-Object -First 1).Thumbprint

Write-Log "Thumbprint: $thumbprint"

# ==============================
# BIND CERTIFICATE
# ==============================

netsh http delete sslcert ipport=0.0.0.0:$Port 2>$null

netsh http add sslcert `
    ipport=0.0.0.0:$Port `
    certhash=$thumbprint `
    appid=$AppId

Write-Log "SSL binding created."

# ==============================
# FIREWALL RULES
# ==============================

netsh advfirewall firewall delete rule name="Allow $CertName $Port" 2>$null

netsh advfirewall firewall add rule `
    name="Allow $CertName $Port" `
    dir=in `
    action=allow `
    protocol=TCP `
    localport=$Port

Write-Log "Firewall rule added."

# ==============================
# CLEANUP GENERATED FILES
# ==============================

Remove-Item "$OpenSSLPath\$CertName.key" -Force -ErrorAction SilentlyContinue
Remove-Item "$OpenSSLPath\$CertName.csr" -Force -ErrorAction SilentlyContinue
Remove-Item "$OpenSSLPath\$CertName.crt" -Force -ErrorAction SilentlyContinue
Remove-Item "$OpenSSLPath\$CertName.p12" -Force -ErrorAction SilentlyContinue

Write-Log "Temporary certificate files removed."

Write-Log "SSL setup completed successfully."