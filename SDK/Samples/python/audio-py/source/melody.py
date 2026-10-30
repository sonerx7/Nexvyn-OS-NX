# Melody text <-> notes. Imported by main.py ("import" loads .py files from the bundle).
#
# Format: tokens separated by spaces. "C4" is middle C for one beat, "F#4:0.5" half a beat, "Bb3:2" two beats,
# "R:1" a one-beat rest. Octaves 0..8, sharps "#", flats "b".

SEMITONES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
NAMES = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]


def parse_token(tok):
    """'C#4:0.5' -> (61, 0.5); 'R:1' -> (None, 1.0). Raises ValueError for anything else."""
    pitch, beats = tok, 1.0
    if ":" in tok:
        parts = tok.split(":")
        pitch = parts[0]
        beats = float(parts[1])
    if beats <= 0 or beats > 16:
        raise ValueError(tok)
    if pitch.upper() == "R":
        return (None, beats)
    letter = pitch[0].upper()
    if letter not in SEMITONES or len(pitch) < 2:
        raise ValueError(tok)
    i, acc = 1, 0
    if pitch[1] == "#":
        acc, i = 1, 2
    elif pitch[1] == "b":
        acc, i = -1, 2
    octave = int(pitch[i:])
    if octave < 0 or octave > 8:
        raise ValueError(tok)
    return (12 * (octave + 1) + SEMITONES[letter] + acc, beats)


def parse(text):
    """Returns (notes, bad_token). notes is a list of (midi or None, beats); bad_token is None when all is fine."""
    notes = []
    for tok in text.split():
        try:
            notes.append(parse_token(tok))
        except ValueError:
            return ([], tok)
        except IndexError:
            return ([], tok)
    return (notes, None)


def freq(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def name(midi):
    return NAMES[midi % 12] + str(midi // 12 - 1)
