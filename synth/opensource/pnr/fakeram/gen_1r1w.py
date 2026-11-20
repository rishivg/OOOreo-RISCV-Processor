#!/usr/bin/env python3
"""Generate placeholder 1R1W Liberty/LEF variants for predictor banks.

Clone the address bus and pins into an independent write port. Scale area,
energy, and timing by 1.6, 1.5, and 1.1. Extend LEF height for the new pins
and adjust width to preserve the area factor. These are screening estimates.

Usage: gen_1r1w.py fakeram45_32x96
"""

import os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
AREA_F, ENERGY_F, TIMING_F = 1.6, 1.5, 1.1

TIMING_BLOCKS = ("cell_rise", "cell_fall", "rise_constraint", "fall_constraint")
ENERGY_BLOCKS = ("rise_power", "fall_power")


def scale_lib(text):
    out, ctx = [], None
    for line in text.splitlines(keepends=True):
        s = line.strip()
        for b in TIMING_BLOCKS:
            if s.startswith(b + "("):
                ctx = "t"
        for b in ENERGY_BLOCKS:
            if s.startswith(b + "("):
                ctx = "e"
        if s.startswith("area :"):
            line = re.sub(
                r"[0-9]+\.[0-9]+", lambda m: f"{float(m.group(0)) * AREA_F:.3f}", line
            )
        elif s.startswith("values") and ctx is not None:
            r = ENERGY_F if ctx == "e" else TIMING_F
            line = re.sub(
                r"[0-9]+\.[0-9]+", lambda m: f"{float(m.group(0)) * r:.3f}", line
            )
            ctx = None
        out.append(line)
    return "".join(out)


def dup_addr_bus(text):
    i = text.index("bus(addr_in)")
    # brace-match the block
    j = text.index("{", i)
    depth, k = 1, j + 1
    while depth:
        if text[k] == "{":
            depth += 1
        elif text[k] == "}":
            depth -= 1
        k += 1
    block = text[i:k]
    clone = block.replace("bus(addr_in)", "bus(waddr_in)", 1)
    # keep indentation: insert after the original block
    return text[:k] + "\n    " + clone + text[k:]


def lef_1r1w(text):
    size_m = re.search(r"(\s*SIZE\s+)([0-9.]+)(\s+BY\s+)([0-9.]+)(\s*;)", text)
    old_x, old_y = float(size_m.group(2)), float(size_m.group(4))
    # collect addr_in pin blocks
    pins = re.findall(
        r"(  PIN addr_in\[(\d+)\]\n(?:.*\n)*?  END addr_in\[\d+\]\n)", text
    )
    assert pins, "no addr_in pins found"
    ys = []
    for blk, _ in pins:
        m = re.search(r"RECT\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)", blk)
        ys.append(float(m.group(2)))
    pitch = abs(ys[1] - ys[0]) if len(ys) > 1 else 0.4
    band0 = old_y + pitch  # margin then the band
    new_y = old_y + pitch * (len(pins) + 2)  # band + margins
    x_ratio = AREA_F * old_y / new_y
    # clone pins into the band (y-shift each RECT into the new band, keep x for now)
    clones = []
    for (blk, idx), y0 in zip(pins, ys):
        shift = band0 + pitch * int(idx) - y0
        nblk = blk.replace(f"addr_in[{idx}]", f"waddr_in[{idx}]")
        nblk = re.sub(
            r"(RECT\s+[0-9.]+\s+)([0-9.]+)(\s+[0-9.]+\s+)([0-9.]+)",
            lambda m: f"{m.group(1)}{float(m.group(2)) + shift:.3f}{m.group(3)}{float(m.group(4)) + shift:.3f}",
            nblk,
        )
        clones.append(nblk)
    last_addr_end = text.rindex("END addr_in[")
    insert_at = text.index("\n", last_addr_end) + 1
    text = text[:insert_at] + "".join(clones) + text[insert_at:]

    # new SIZE + x-scale everything (house recipe: SIZE X + every RECT x-coord)
    def rect_x(m):
        return (
            f"{m.group(1)}{float(m.group(2)) * x_ratio:.3f} {m.group(3)} "
            f"{float(m.group(4)) * x_ratio:.3f} {m.group(5)}"
        )

    text = re.sub(
        r"(\s*RECT\s+)([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)", rect_x, text
    )
    text = re.sub(
        r"(\s*SIZE\s+)([0-9.]+)(\s+BY\s+)([0-9.]+)",
        lambda m: f"{m.group(1)}{float(m.group(2)) * x_ratio:.3f}{m.group(3)}{new_y:.3f}",
        text,
    )
    return text


def main():
    parent = sys.argv[1]
    new = parent.replace("fakeram45_", "fakeram45_1r1w_")
    lib = open(os.path.join(HERE, parent + ".lib")).read()
    lef = open(os.path.join(HERE, parent + ".lef")).read()
    out_lib = dup_addr_bus(scale_lib(lib)).replace(parent, new)
    out_lef = lef_1r1w(lef).replace(parent, new)
    assert out_lib.count("{") == out_lib.count("}"), "lib brace mismatch"
    assert out_lib.count("bus(waddr_in)") == 1 and out_lef.count("PIN waddr_in[0]") == 1
    open(os.path.join(HERE, new + ".lib"), "w").write(out_lib)
    open(os.path.join(HERE, new + ".lef"), "w").write(out_lef)
    n_addr = out_lef.count("PIN waddr_in[")
    print(
        f"{new}: +{n_addr} waddr pins, area x{AREA_F}, energy x{ENERGY_F}, timing x{TIMING_F}"
    )


if __name__ == "__main__":
    main()
