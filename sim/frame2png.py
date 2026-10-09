#!/usr/bin/env python3
"""Turn the frame.txt written by tb_tc2068_boot into a PNG.

usage: frame2png.py frame.txt out.png

The input is one character per 14 MHz clock: a hex digit (I G R B) or 's'
while composite sync is low. Line length is recovered from the spacing of
the horizontal sync pulses, the top of the frame from the vertical sync.
"""
import struct
import sys
import zlib
from collections import Counter

LINES = 312


def main(src, dst):
    s = open(src).read().replace("\n", "")
    # Falling edges of sync.
    edges = [i for i in range(1, len(s)) if s[i] == "s" and s[i - 1] != "s"]
    if len(edges) < 100:
        sys.exit("no sync found in %s" % src)
    width = Counter(b - a for a, b in zip(edges, edges[1:])).most_common(1)[0][0]
    # Vertical sync: the first cluster of sync runs much longer than a
    # horizontal sync pulse. The frame starts at the first line after it.
    runs, run, start = [], 0, 0
    for i, c in enumerate(s):
        if c == "s":
            if run == 0:
                start = i
            run += 1
        elif run:
            runs.append((start, run))
            run = 0
    long_runs = [r for r in runs if r[1] > width // 4]
    if not long_runs:
        sys.exit("no vertical sync found in %s" % src)
    end = long_runs[0]
    for r in long_runs[1:]:
        if r[0] - (end[0] + end[1]) > 2 * width:
            break
        end = r
    top = next(e for e in edges if e > end[0] + end[1])
    rows = []
    for n in range(LINES):
        row = s[top + n * width: top + (n + 1) * width]
        if len(row) < width:
            break
        rows.append(row)
    raw = bytearray()
    for row in rows:
        raw.append(0)
        for c in row:
            if c == "s":
                raw += b"\x00\x00\x00"
            elif c == "x":
                raw += b"\xff\x00\xff"          # undefined: magenta
            else:
                v = int(c, 16)
                lvl = 255 if v & 8 else 192
                raw += bytes((lvl if v & 2 else 0, lvl if v & 4 else 0, lvl if v & 1 else 0))

    def chunk(tag, data):
        c = struct.pack(">I", len(data)) + tag + data
        return c + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n"
    png += chunk(b"IHDR", struct.pack(">IIBBBBB", width, len(rows), 8, 2, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(bytes(raw), 9))
    png += chunk(b"IEND", b"")
    open(dst, "wb").write(png)
    print("%s: %d x %d" % (dst, width, len(rows)))


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    main(sys.argv[1], sys.argv[2])
