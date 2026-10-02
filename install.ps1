<#
.SYNOPSIS
  One-shot WSL setup from Windows: installs WSL, creates a Debian distro + Linux user, then runs setup.sh inside it.

.EXAMPLE
  # Easiest: paste into PowerShell
  irm https://raw.githubusercontent.com/asninee/wsl-setup/main/install.ps1 | iex

.EXAMPLE
  # With options
  & ([scriptblock]::Create((irm https://raw.githubusercontent.com/asninee/wsl-setup/main/install.ps1))) -Name dev -UserName me
#>

function Install-WslSetup {
  [CmdletBinding()]
  param(
    [string]$Name = 'Debian',
    [string]$UserName,
    [string]$Repo = 'https://github.com/asninee/wsl-setup.git',
    [string]$Branch = 'main'
  )

  $ErrorActionPreference = 'Continue'
  $env:WSL_UTF8 = '1'
  $OutputEncoding = [Text.UTF8Encoding]::new($false)
  $rawUrl = 'https://raw.githubusercontent.com/asninee/wsl-setup/main/install.ps1'

  function Write-Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }

  # Runs a bash script inside the distro; base64 avoids Windows quoting/CRLF issues while keeping stdin a terminal.
  function Invoke-InDistro([string]$User, [string]$Script) {
    $b64 = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes(($Script -replace "`r", '')))
    & wsl.exe -d $Name -u $User --cd '~' -e bash -c "bash -euo pipefail <(echo $b64 | base64 -d)"
    if ($LASTEXITCODE -ne 0) { throw "Step failed inside '$Name' (exit code $LASTEXITCODE)." }
  }

  function Register-ResumeAfterReboot {
    $cmd = if ($PSCommandPath) { "-File `"$PSCommandPath`"" } else { "-Command `"irm $rawUrl | iex`"" }
    Set-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce' -Name 'wsl-setup' `
      -Value "powershell.exe -NoExit -NoProfile -ExecutionPolicy Bypass $cmd"
  }

  foreach ($v in $Repo, $Branch) {
    if ($v -match "[\s'`"]") { throw "Invalid value '$v' (no spaces or quotes allowed)." }
  }

  # 1. WSL itself
  Write-Step 'Checking WSL'
  & wsl.exe --version *> $null
  if ($LASTEXITCODE -ne 0) {
    Write-Step 'Installing WSL (approve the admin prompt if one appears)'
    & wsl.exe --install --no-distribution
    if ($LASTEXITCODE -ne 0) { throw 'WSL install failed. Make sure virtualization is enabled in your BIOS/UEFI.' }
    Register-ResumeAfterReboot
    Write-Host "`nWSL installed. Restart your PC - setup will continue automatically after you sign in." -ForegroundColor Yellow
    return
  }
  & wsl.exe --update
  if ($LASTEXITCODE -ne 0) { Write-Warning 'wsl --update failed; continuing with the installed version.' }

  # 2. Distro
  $created = $false
  $existing = @(& wsl.exe --list --quiet) | ForEach-Object { $_.Trim() } | Where-Object { $_ }
  if ($existing -contains $Name) {
    Write-Step "Using existing distro '$Name'"
  } else {
    Write-Step "Creating distro '$Name' (Debian)"
    & wsl.exe --install Debian --name $Name --no-launch --web-download
    if ($LASTEXITCODE -ne 0) {
      Register-ResumeAfterReboot
      throw 'Creating the distro failed. If WSL was just installed, restart your PC (setup will resume after sign-in).'
    }
    $created = $true
  }

  # 3. Linux user
  $current = (& wsl.exe -d $Name -u root -e sh -c 'getent passwd 1000 | cut -d: -f1') | Out-String
  $current = $current.Trim()
  $newUser = -not $current
  if ($current) {
    $UserName = $current
    Write-Step "Using existing Linux user '$UserName'"
  } else {
    $suggest = ($env:USERNAME.ToLower() -replace '[^a-z0-9_-]', '')
    while ($UserName -notmatch '^[a-z_][a-z0-9_-]{0,31}$') {
      $UserName = Read-Host "Choose a Linux username (lowercase letters/numbers) [$suggest]"
      if (-not $UserName) { $UserName = $suggest }
    }
  }

  $password = $env:WSL_SETUP_PASSWORD
  if ($newUser -and -not $password) {
    while ($true) {
      $p1 = [Net.NetworkCredential]::new('', (Read-Host 'Choose a Linux password (used for sudo)' -AsSecureString)).Password
      $p2 = [Net.NetworkCredential]::new('', (Read-Host 'Confirm password' -AsSecureString)).Password
      if ($p1 -and $p1 -ceq $p2) { $password = $p1; break }
      Write-Host 'Passwords were empty or did not match, try again.' -ForegroundColor Yellow
    }
  }

  Write-Step 'Preparing base system'
  Invoke-InDistro root (@'
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq sudo git ca-certificates curl >/dev/null
id -u __USER__ >/dev/null 2>&1 || useradd -m -s /bin/bash -G sudo __USER__
touch /etc/wsl.conf
grep -q '^\[user\]' /etc/wsl.conf || printf '\n[user]\ndefault=__USER__\n' >> /etc/wsl.conf
echo '__USER__ ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/zz-wsl-setup
chmod 440 /etc/sudoers.d/zz-wsl-setup
'@ -replace '__USER__', $UserName)

  try {
    if ($newUser) {
      "$($UserName):$password" | & wsl.exe -d $Name -u root -e sh -c "tr -d '\r' | chpasswd"
      if ($LASTEXITCODE -ne 0) { throw 'Setting the password failed.' }
    }

    Write-Step 'Running setup.sh (this takes a few minutes)'
    Invoke-InDistro $UserName (@'
mkdir -p ~/dev
if [ -d ~/dev/wsl-setup/.git ]; then
  git -C ~/dev/wsl-setup pull --ff-only
else
  git clone --branch '__BRANCH__' '__REPO__' ~/dev/wsl-setup
fi
~/dev/wsl-setup/setup.sh
'@ -replace '__BRANCH__', $Branch -replace '__REPO__', $Repo)
  } finally {
    & wsl.exe -d $Name -u root -e rm -f /etc/sudoers.d/zz-wsl-setup
  }

  & wsl.exe --terminate $Name *> $null
  if ($created) { & wsl.exe --set-default $Name }

  Write-Host "`nAll done! Open '$Name' from the Start menu or Windows Terminal, or run: wsl -d $Name" -ForegroundColor Green
}

Install-WslSetup @args
