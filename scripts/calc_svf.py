import math

def calculate_coeffs(fc, fs, Q):
    g = math.tan(math.pi * fc / fs)
    k = 1.0 / Q
    a1 = 1.0 / (1.0 + g * (g + k))
    a2 = g * a1
    a3 = g * a2
    
    print(f"g  = {g:.50f}")
    print(f"k  = {k:.50f}")
    print(f"a1 = {a1:.50f}")
    print(f"a2 = {a2:.50f}")
    print(f"a3 = {a3:.50f}")

if __name__ == "__main__":
    try:
        fc = float(input("cutoff frequency (fc): "))
        fs = float(input("sample rate (fs): "))
        Q = float(input("quality factor (Q): "))
        
        calculate_coeffs(fc, fs, Q)
    except ValueError:
        print("error :(")