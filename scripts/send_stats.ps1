<#
.SYNOPSIS
  Invia CPU/GPU/RAM/HDD ad Arduino via seriale
.DESCRIPTION
  Legge le statistiche di sistema Windows 11 e le invia
  al microcontrollore ATmega328PB + OLED SSD1306.
  Formato: CPU:val|GPU:val|RAM:val|DISK:val\n
.PARAMETER Port
  Porta COM (default: auto-detect Arduino)
.PARAMETER Interval
  Intervallo di aggiornamento in ms (default: 500)
#>

param(
  [string]$Port = "",
  [int]$Interval = 500
)

# ── Rilevamento automatico porta ──
function Find-ArduinoPort {
  $ports = [System.IO.Ports.SerialPort]::GetPortNames()
  foreach ($p in $ports) {
    try {
      $sp = New-Object System.IO.Ports.SerialPort $p, 115200, None, 8, One
      $sp.ReadTimeout = 600
      $sp.WriteTimeout = 600
      $sp.Open()
      Start-Sleep -Milliseconds 100
      $sp.Close()
      return $p
    } catch { continue }
  }
  return $ports[0]
}

if (-not $Port) {
  $Port = Find-ArduinoPort
  if (-not $Port) {
    Write-Host "Nessuna porta COM trovata. Specifica: .\send_stats.ps1 -Port COM3" -ForegroundColor Red
    exit 1
  }
}

# ── Connessione ──
try {
  $serial = New-Object System.IO.Ports.SerialPort($Port, 115200, [System.IO.Ports.Parity]::None, 8, [System.IO.Ports.StopBits]::One)
  $serial.Open()
  Write-Host "[OK] Connesso a $Port" -ForegroundColor Green
} catch {
  Write-Host "[ERR] Impossibile aprire $Port : $_" -ForegroundColor Red
  exit 1
}

# ── Variabili per media CPU ──
$lastCpu = Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average
$cpuSmoothing = 0.3

Write-Host "Monitoraggio attivo (CTRL+C per uscire)" -ForegroundColor Cyan
Write-Host "───" * 20

while ($true) {
  try {
    # ── CPU (% media pesata) ──
    $cpuRaw = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
    if ($cpuRaw -and $lastCpu) {
      $cpu = [math]::Round($lastCpu.Average * (1 - $cpuSmoothing) + $cpuRaw * $cpuSmoothing, 1)
    } else { $cpu = [math]::Round($cpuRaw, 1) }
    $lastCpu = $cpuRaw

    # ── RAM ──
    $os = Get-CimInstance Win32_OperatingSystem
    $ram = [math]::Round(
      ($os.TotalVisibleMemorySize - $os.FreePhysicalMemory) / $os.TotalVisibleMemorySize * 100, 1
    )

    # ── HDD (C:) ──
    $disk = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"
    $hdd = [math]::Round(
      ($disk.Size - $disk.FreeSpace) / $disk.Size * 100, 1
    )

    # ── GPU (NVIDIA / AMD / generica) ──
    $gpu = 0.0
    # Prova NVIDIA
    try {
      $nvidia = & nvidia-smi --query-gpu=utilization.gpu --format=csv,noheader,nounits 2>$null
      if ($nvidia -match '^\d+') { $gpu = [math]::Round([float]$nvidia, 1) }
    } catch {}
    # Fallback AMD
    if ($gpu -eq 0) {
      try {
        $amd = Get-CimInstance -ClassName "Win32_PerfFormattedData_Counters_GPUAdapter" -ErrorAction SilentlyContinue
        if ($amd) { $gpu = [math]::Round(($amd | Measure-Object -Property PercentGPUTime -Average).Average, 1) }
      } catch {}
    }
    # Fallback generico
    if ($gpu -eq 0) {
      $gpu = $cpu * 0.7  # stima approssimativa
    }

    # ── Invio ──
    $line = "CPU:$cpu|GPU:$gpu|RAM:$ram|DISK:$hdd"
    $serial.WriteLine($line)

    # ── Output console ──
    $time = Get-Date -Format "HH:mm:ss"
    Write-Host ("[{0}] CPU:{1,5}% | GPU:{2,5}% | RAM:{3,5}% | DISK:{4,5}%" -f
      $time, $cpu, $gpu, $ram, $hdd)

  } catch {
    Write-Host "[ERR] $_" -ForegroundColor Yellow
  }

  Start-Sleep -Milliseconds $Interval
}
