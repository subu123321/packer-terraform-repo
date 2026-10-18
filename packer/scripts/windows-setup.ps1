# Customizes the Windows Server 2025 base image: IIS, Git, Google Chrome.
$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

function Invoke-WithRetry {
    param([scriptblock]$Script, [int]$Tries = 3)
    for ($i = 1; $i -le $Tries; $i++) {
        try { & $Script; return }
        catch {
            if ($i -eq $Tries) { throw }
            Write-Output "Attempt $i failed: $($_.Exception.Message). Retrying..."
            Start-Sleep -Seconds (10 * $i)
        }
    }
}

# ---------------- 1. IIS web server ----------------
Write-Output '>> Installing IIS'
$iis = Install-WindowsFeature -Name Web-Server -IncludeManagementTools
if (-not $iis.Success) { throw 'IIS installation failed' }
New-NetFirewallRule -DisplayName 'HTTP-In-80' -Direction Inbound -Protocol TCP `
    -LocalPort 80 -Action Allow -ErrorAction SilentlyContinue | Out-Null

# ---------------- 2. Git (via Chocolatey) ----------------
Write-Output '>> Installing Chocolatey + Git'
Invoke-WithRetry {
    Set-ExecutionPolicy Bypass -Scope Process -Force
    Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
}
$choco = 'C:\ProgramData\chocolatey\bin\choco.exe'
Invoke-WithRetry {
    & $choco install git -y --no-progress
    if ($LASTEXITCODE -notin 0, 1641, 3010) { throw "choco install git failed: $LASTEXITCODE" }
}

# ---------------- 3. Google Chrome (official enterprise MSI) ----------------
Write-Output '>> Installing Google Chrome'
$msi = "$env:TEMP\chrome.msi"
Invoke-WithRetry {
    Invoke-WebRequest -UseBasicParsing -OutFile $msi `
        -Uri 'https://dl.google.com/dl/chrome/install/googlechromestandaloneenterprise64.msi'
}
$p = Start-Process msiexec.exe -ArgumentList "/i `"$msi`" /qn /norestart" -Wait -PassThru
if ($p.ExitCode -notin 0, 3010) { throw "Chrome MSI install failed: $($p.ExitCode)" }
Remove-Item $msi -Force

# ---------------- 4. Verify (the build fails here if anything is missing) ----------------
Write-Output '>> Verifying'
$env:Path = [Environment]::GetEnvironmentVariable('Path', 'Machine')

$gitExe    = 'C:\Program Files\Git\cmd\git.exe'
$chromeExe = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
if (-not (Test-Path $gitExe))    { throw 'Git not found after install' }
if (-not (Test-Path $chromeExe)) { throw 'Chrome not found after install' }

$gitVersion    = (& $gitExe --version)
$chromeVersion = (Get-Item $chromeExe).VersionInfo.ProductVersion
$iisVersion    = (Get-ItemProperty HKLM:\SOFTWARE\Microsoft\InetStp).VersionString
if ((Get-Service W3SVC).Status -eq $null) { throw 'IIS service (W3SVC) missing' }

# ---------------- 5. Proof of what is inside the image ----------------
New-Item -ItemType Directory -Force -Path 'C:\ProgramData\image-info' | Out-Null
@"
Golden image : windows-2025
Version      : $env:IMAGE_VERSION
Built by     : Packer
IIS          : $iisVersion
Git          : $gitVersion
Chrome       : $chromeVersion
"@ | Set-Content -Path 'C:\ProgramData\image-info\installed-tools.txt' -Encoding UTF8

# IIS home page lists the tools, so http://<vm-ip> proves the image contents
$html = @"
<!DOCTYPE html>
<html><head><title>Windows Server 2025 Golden Image</title></head>
<body style="font-family:Segoe UI,Arial,sans-serif">
<h1>Windows Server 2025 golden image</h1>
<p>Built by Packer, image version <b>$env:IMAGE_VERSION</b></p>
<table border="1" cellpadding="6" style="border-collapse:collapse">
<tr><th align="left">IIS</th><td>$iisVersion</td></tr>
<tr><th align="left">Git</th><td>$gitVersion</td></tr>
<tr><th align="left">Google Chrome</th><td>$chromeVersion</td></tr>
</table>
</body></html>
"@
Set-Content -Path 'C:\inetpub\wwwroot\index.html' -Value $html -Encoding UTF8

Get-Content 'C:\ProgramData\image-info\installed-tools.txt'
Write-Output 'Windows customization complete.'
