
# SelfHostSSL

PowerShell script to automatically generate, install, and bind a self-signed SSL certificate
for local self‑hosted services running behind Cloudflare supported HTTPS ports.

The script automates the full lifecycle of certificate creation and HTTPS configuration.

---

## Features

- Automatic OpenSSL installation (if not already installed)
- Generates a secure **4096-bit RSA certificate**
- Creates **CSR and self‑signed certificate**
- Exports certificate to **PFX**
- Installs certificate into Windows Certificate Store
- Automatically binds the certificate to an HTTPS port
- Creates Windows Firewall rule
- Removes old certificates with the same CN
- Full execution logging
- Supports Cloudflare HTTPS ports

Supported ports:

- 443
- 2053
- 2083
- 2087
- 2096
- 8443

---

## Requirements

- Windows 10 / Windows 11 / Windows Server
- PowerShell
- Administrator privileges
- OpenSSL installer in the same directory as the script

Required file:

```
Win64OpenSSL_Light-3_6_1.exe
```

Download OpenSSL from:

https://slproweb.com/products/Win32OpenSSL.html

---

## How It Works

The script performs the following steps:

1. Prompts the user to select a supported HTTPS port.
2. Verifies if OpenSSL is installed.
3. Installs OpenSSL if necessary.
4. Generates:
   - Private key
   - CSR (Certificate Signing Request)
   - Self-signed certificate
5. Exports the certificate to PFX format.
6. Imports the certificate into the Windows Certificate Store.
7. Removes existing certificates with the same CN.
8. Creates an HTTPS binding using `netsh http`.
9. Adds a Windows Firewall rule.
10. Cleans temporary files.

---

## Usage

Run PowerShell **as Administrator** and execute:

```powershell
.\SelfhostCertificate.ps1
```

You will be prompted to choose a Cloudflare compatible HTTPS port.

Example:

```
Choose Cloudflare HTTPS port:

1) 443
2) 2053
3) 2083
4) 2087
5) 2096
6) 8443
```

After selecting a port, the script automatically configures the certificate and HTTPS binding.

---

## Output

A log file will be generated in the same directory as the script.

Example:

```
SelfhostCertificate_YYYYMMDD_HHMMSS.log
```

Example log entries:

```
OpenSSL installed successfully
Generated certificate password
Generated private key
Generated CSR
Generated self-signed certificate
Certificate imported into Windows store
SSL binding created
Firewall rule added
```

---

## Certificate Details

Default certificate subject:

```
C=PT
ST=Lisbon
L=Lisbon
O=Smartdigit
OU=Smartdigit
CN=localhost
```

Key type:

```
RSA 4096
AES256 encryption
```

Validity:

```
36500 days (100 years)
```

---

## Security Notes

This certificate is **self-signed** and intended for:

- Development environments
- Internal APIs
- Self-hosted services
- Reverse proxy scenarios behind Cloudflare

Do **not use self‑signed certificates for public production services** without proper CA certificates.

---

## Example Use Cases

- Self-hosted APIs
- .NET HTTPS services
- Local reverse proxies
- Development environments
- Internal tools behind Cloudflare

---

## License

MIT License
