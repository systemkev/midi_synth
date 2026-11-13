
import math

with open("g_tan_lut.mem", "w") as file:
    for i in range(4096):
        fc = 20 * (1000 ** (i / 4095))
        g = math.tan(math.pi * fc / 96000)
        g_fixed = round(g * (2 ** 24))
        file.write(f"{g_fixed:06X}\n")