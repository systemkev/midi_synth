
import serial
import threading
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.animation import FuncAnimation

PORT = "COM7" 
BAUD = 115200
N = 512
FS = 98_297_872 / 1024
HEADER = bytes([0xA5, 0x5A, 0xC3, 0x3C])
FRAME_SIZE = N * 9

latest = np.zeros((N, 3), dtype=np.float32)
lock = threading.Lock()
stop = threading.Event()
ser = serial.Serial(PORT, BAUD, timeout=0.05)

def read_serial():
    buf = bytearray()

    while not stop.is_set():
        try:
            buf.extend(ser.read(2048))
        except serial.SerialException:
            break

        while True:
            pos = buf.find(HEADER)
            if pos < 0:
                del buf[:-3]
                break

            if pos > 0: del buf[:pos]
            if len(buf) < 4 + FRAME_SIZE: break

            raw = np.frombuffer(bytes(buf[4:4+FRAME_SIZE]), dtype=np.uint8).reshape(N, 9)
            values = (raw[:, 0::3].astype(np.int32) << 16) | (raw[:, 1::3].astype(np.int32) << 8) | raw[:, 2::3].astype(np.int32)
            values = ((values ^ 0x800000) - 0x800000) / 8388608.0

            with lock:
                latest[:] = values

            del buf[:4+FRAME_SIZE]

threading.Thread(target=read_serial, daemon=True).start()

t = np.arange(N) / FS * 1000
fig, ax = plt.subplots(figsize=(12, 6))
names = ["VCF Input", "VCF Output", "VCA Output"]
lines = [ax.plot(t, np.zeros(N), label=name)[0] for name in names]

ax.set(xlim=(0, t[-1]), ylim=(-1.1, 1.1),
       xlabel="Time (ms)", ylabel="Normalized amplitude",
       title="FPGA Synthesizer - Real-Time Waveforms")
ax.legend()
ax.grid(True)

def update(_):
    with lock:
        data = latest.copy()

    for i, line in enumerate(lines):
        line.set_ydata(data[:, i])
    return lines

ani = FuncAnimation(fig, update, interval=100, blit=True, cache_frame_data=False)

try:
    plt.show()
finally:
    stop.set()
    ser.close()
