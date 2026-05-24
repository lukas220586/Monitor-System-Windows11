<#
.SYNOPSIS
  MonitorSystem Pugliese Hardware — Setup
  Installa Python + librerie psutil/pyserial
#>

$ErrorActionPreference = "Stop"
$AppDir = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "MonitorSystem Pugliese Hardware — Installazione" -ForegroundColor Cyan
Write-Host ""

# ── Python ──
$python = $null
try { $python = (Get-Command python.exe -ErrorAction Stop).Source } catch {}

if (-not $python) {
  Write-Host "Python non trovato. Scarico Python 3.12..." -ForegroundColor Yellow
  $url = "https://www.python.org/ftp/python/3.12.4/python-3.12.4-amd64.exe"
  $installer = "$env:TEMP\python-installer.exe"
  try {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Invoke-WebRequest -Uri $url -OutFile $installer -UseBasicParsing
  } catch {
    Write-Host "[ERR] Impossibile scaricare Python." -ForegroundColor Red
    Read-Host "Premi Invio per uscire"
    exit 1
  }
  Write-Host "Installazione Python in corso..." -ForegroundColor Yellow
  Start-Process -Wait -FilePath $installer -ArgumentList "/quiet", "InstallAllUsers=1", "PrependPath=1", "Include_pip=1"
  Remove-Item $installer -Force
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $python = (Get-Command python.exe).Source
  Write-Host "Python installato: $python" -ForegroundColor Green
} else {
  Write-Host "Python trovato: $python" -ForegroundColor Green
}

# ── Librerie ──
Write-Host "Installazione librerie (psutil, pyserial)..." -ForegroundColor Yellow
& $python -m pip install psutil pyserial --quiet --upgrade
Write-Host "Librerie installate." -ForegroundColor Green

Write-Host ""
Write-Host "Installazione completata!" -ForegroundColor Green
Write-Host ""
Write-Host "Il monitoraggio parte automaticamente all'accesso di Windows." -ForegroundColor White
Write-Host "Collega l'hardware via USB." -ForegroundColor White
