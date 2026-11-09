
import math

LUT_SIZE = 4096
DATA_WIDTH = 24
OUTPUT_FILE = "mem/sine4096_24bit.mem"

MAX_AMP = (1 << (DATA_WIDTH - 1)) - 1

MASK = (1 << DATA_WIDTH) - 1

with open(OUTPUT_FILE, "w") as f:
    for i in range(LUT_SIZE):

        angle = 2 * math.pi * i / LUT_SIZE

        amplitude = round(MAX_AMP * math.sin(angle))

        value = amplitude & MASK

        f.write(f"{value:06X}\n")

print(f"Generated {OUTPUT_FILE}")
print(f"Entries: {LUT_SIZE}")
print(f"Data width: {DATA_WIDTH} bits")
