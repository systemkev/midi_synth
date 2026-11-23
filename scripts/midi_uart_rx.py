import argparse
import sys
import serial
from serial.tools import list_ports

NOTE_NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

STATUS_TYPES = {
    0x80: "Note Off",
    0x90: "Note On",
    0xA0: "Poly Pressure",
    0xB0: "Control Change",
    0xC0: "Program Change",
    0xD0: "Channel Pressure",
    0xE0: "Pitch Bend",
}


def note_name(note: int) -> str:
    return f"{NOTE_NAMES[note % 12]}{(note // 12) - 1}"


def format_midi(status: int, d1: int, d2: int) -> str:
    msg_type = status & 0xF0
    ch = (status & 0x0F) + 1
    label = STATUS_TYPES.get(msg_type, f"Status 0x{status:02X}")

    if msg_type == 0x90 and d2 == 0:
        detail = f"Note Off (vel 0) {note_name(d1)} ({d1})"
    elif msg_type in (0x80, 0x90):
        detail = f"{label} {note_name(d1)} ({d1}) vel={d2}"
    elif msg_type == 0xB0:
        detail = f"{label} CC#{d1} val={d2}"
    elif msg_type == 0xE0:
        bend = ((d2 << 7) | d1) - 8192
        detail = f"{label} {bend:+d}"
    else:
        detail = f"{label} d1={d1} d2={d2}"

    return f"[0x{status:02X} 0x{d1:02X} 0x{d2:02X}] ch={ch:2d} | {detail}"


def list_available_ports() -> None:
    ports = list_ports.comports()
    if not ports:
        print("No serial ports found.")
        return
    print("Available serial ports:")
    for p in ports:
        print(f"  {p.device:20s} {p.description}")


def main() -> None:
    parser = argparse.ArgumentParser(description="Receive 3-byte MIDI packets over UART.")
    parser.add_argument("port", nargs="?", help="Serial port (e.g. COM3, /dev/ttyUSB1, /dev/cu.usbserial-XXXX)")
    parser.add_argument("-b", "--baud", type=int, default=115200, help="Baud rate (default: 115200)")
    parser.add_argument("--raw", action="store_true", help="Print every incoming byte as raw hex without MIDI framing")
    args = parser.parse_args()

    if not args.port:
        list_available_ports()
        print("\nUsage: python midi_uart_rx.py <PORT> [--baud 115200] [--raw]")
        sys.exit(1)

    try:
        ser = serial.Serial(
            port=args.port,
            baudrate=args.baud,
            bytesize=serial.EIGHTBITS,
            parity=serial.PARITY_NONE,
            stopbits=serial.STOPBITS_ONE,
            timeout=0.5,
        )
    except serial.SerialException as exc:
        print(f"Could not open {args.port}: {exc}")
        list_available_ports()
        sys.exit(1)

    print(f"Listening on {args.port} at {args.baud} 8N1 (Ctrl+C to stop)...")
    buf = bytearray()

    try:
        while True:
            chunk = ser.read(ser.in_waiting or 1)
            if not chunk:
                continue

            if args.raw:
                print(" ".join(f"{b:02X}" for b in chunk), flush=True)
                continue

            for b in chunk:
                if b & 0x80:
                    # Status byte: start a fresh 3-byte packet
                    if buf:
                        print(f"[incomplete: {' '.join(f'0x{x:02X}' for x in buf)}]", flush=True)
                    buf = bytearray([b])
                elif buf:
                    buf.append(b)
                    if len(buf) == 3:
                        print(format_midi(buf[0], buf[1], buf[2]), flush=True)
                        buf.clear()
                else:
                    print(f"[orphan data byte: 0x{b:02X}]", flush=True)
    except KeyboardInterrupt:
        print("\nStopped.")
    finally:
        ser.close()


if __name__ == "__main__":
    main()