"""
System Monitor — Script Windows
Invia CPU/GPU/RAM/HDD ad ATmega328PB + OLED SSD1306 via seriale.

Requisiti:
  pip install psutil pyserial

Uso:
  python send_stats.py                   # auto-detect porta
  python send_stats.py --port COM5       # porta specifica
  python send_stats.py --interval 1000   # ogni 1s
"""

import argparse
import struct
import sys
import time

try:
    import psutil
except ImportError:
    print("Installa psutil: pip install psutil")
    sys.exit(1)

try:
    import serial
    import serial.tools.list_ports
except ImportError:
    print("Installa pyserial: pip install pyserial")
    sys.exit(1)


def find_arduino_port():
    ports = serial.tools.list_ports.comports()
    for p in ports:
        if any(kw in (p.description + p.manufacturer or "").lower()
               for kw in ("arduino", "ch340", "cp210", "ftdi", "serial")):
            return p.device
    if ports:
        return ports[0].device
    return None


def get_gpu_usage():
    """Tenta di leggere GPU via nvidia-smi, fallback a stima."""
    import subprocess
    try:
        out = subprocess.check_output(
            ["nvidia-smi", "--query-gpu=utilization.gpu",
             "--format=csv,noheader,nounits"],
            timeout=5, stderr=subprocess.STDOUT,
            creationflags=subprocess.CREATE_NO_WINDOW if sys.platform == "win32" else 0,
        )
        return round(float(out.decode().strip().split("\n")[0]), 1)
    except Exception:
        pass
    # Fallback: stima basata su CPU
    return round(psutil.cpu_percent(interval=0) * 0.7, 1)


def main():
    ap = argparse.ArgumentParser(description="System Monitor → Arduino")
    ap.add_argument("--port", "-p", default=None, help="Porta COM (es. COM3)")
    ap.add_argument("--baud", "-b", type=int, default=115200, help="Baud rate")
    ap.add_argument("--interval", "-i", type=int, default=500, help="ms tra invii")
    args = ap.parse_args()

    # Porta
    port = args.port or find_arduino_port()
    if not port:
        print("Nessuna porta trovata. Usa --port COMx")
        sys.exit(1)

    # Connessione
    try:
        ser = serial.Serial(port, args.baud, timeout=1, write_timeout=1)
        print(f"[OK] Connesso a {port} @ {args.baud} baud")
    except Exception as e:
        print(f"[ERR] {e}")
        sys.exit(1)

    # Smoothing CPU
    cpu_smooth = 0.0
    alpha = 0.3

    print("Monitoraggio attivo (CTRL+C per uscire)")
    print("─" * 50)

    try:
        while True:
            # CPU
            cpu_raw = psutil.cpu_percent(interval=0)
            cpu_smooth = cpu_smooth * (1 - alpha) + cpu_raw * alpha
            cpu = round(cpu_smooth, 1)

            # RAM
            ram = round(psutil.virtual_memory().percent, 1)

            # DISK (C:)
            disk = round(psutil.disk_usage("C:").percent, 1)

            # GPU
            gpu = get_gpu_usage()

            # Invio
            line = f"CPU:{cpu}|GPU:{gpu}|RAM:{ram}|DISK:{disk}\n"
            ser.write(line.encode())

            ts = time.strftime("%H:%M:%S")
            print(f"[{ts}] CPU:{cpu:5.1f}% | GPU:{gpu:5.1f}% | RAM:{ram:5.1f}% | DISK:{disk:5.1f}%")

            time.sleep(args.interval / 1000.0)

    except KeyboardInterrupt:
        print("\nChiusura...")
    finally:
        ser.close()


if __name__ == "__main__":
    main()
