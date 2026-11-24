
import serial

PORT = "COM3"  # Change to your COM port
BAUD = 115200

with serial.Serial(PORT, BAUD, timeout=1) as ser:
    print(f"Listening on {PORT} at {BAUD} baud. Press Ctrl+C to stop.\n")

    try:
        while True:
            data = ser.read(32)
            if data:
                print("HEX:", data.hex(" ").upper())
                print("DEC:", list(data))
    except KeyboardInterrupt:
        print("\nStopped.")
