
from pathlib import Path

SAMPLE_RATE = 95994.0234375
PHASE_BITS = 32
OUTPUT = Path("mem/midi_phase_inc.mem")

def midi_to_frequency(note):
    return 440.0 * 2 ** ((note - 69) / 12)

def midi_to_phase_increment(note):
    frequency = midi_to_frequency(note)
    return round((2 ** PHASE_BITS) * frequency / SAMPLE_RATE)

def main():
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)

    with OUTPUT.open("w") as file:
        for note in range(128):
            increment = midi_to_phase_increment(note)
            file.write(f"{increment:08X}\n")

    print(f"Generated {OUTPUT}")

if __name__ == "__main__":
    main()
