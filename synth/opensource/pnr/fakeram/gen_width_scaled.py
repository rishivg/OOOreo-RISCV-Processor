#!/usr/bin/env python3
"""Generate width-scaled placeholder Liberty/LEF variants.

Keep all bus pins. Scale area, internal energy, LEF height, and pin y-coordinates
by the width ratio. Scale timing by --timing-ratio (default: width ratio);
other Liberty values stay unchanged. These are screening estimates.

--check compares regenerated 16x240 values against the committed fixtures.
Usage: gen_width_scaled.py fakeram45_64x256 fakeram45_64x128 0.5 --timing-ratio 0.9
"""

import argparse, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))

TIMING_BLOCKS = ("cell_rise", "cell_fall", "rise_constraint", "fall_constraint")
ENERGY_BLOCKS = ("rise_power", "fall_power")


def scale_num(m, ratio):
    return f"{float(m.group(0)) * ratio:.3f}"


def scale_lib(text, parent, new, er, tr):
    out = []
    ctx = None  # which block kind the next values(...) line belongs to
    for line in text.splitlines(keepends=True):
        stripped = line.strip()
        for b in TIMING_BLOCKS:
            if stripped.startswith(b + "("):
                ctx = "t"
        for b in ENERGY_BLOCKS:
            if stripped.startswith(b + "("):
                ctx = "e"
        if stripped.startswith("area :"):
            line = re.sub(r"[0-9]+\.[0-9]+", lambda m: scale_num(m, er), line)
        elif stripped.startswith("values") and ctx is not None:
            r = er if ctx == "e" else tr
            line = re.sub(r"[0-9]+\.[0-9]+", lambda m: scale_num(m, r), line)
            ctx = None
        out.append(line.replace(parent, new))
    return "".join(out)


def scale_lef(text, parent, new, er):
    out = []
    for line in text.splitlines(keepends=True):
        s = line.strip()
        if s.startswith("SIZE"):
            m = re.match(r"(\s*SIZE\s+)([0-9.]+)(\s+BY\s+)([0-9.]+)(\s*;.*\n?)", line)
            line = f"{m.group(1)}{m.group(2)}{m.group(3)}{float(m.group(4)) * er:.3f}{m.group(5)}"
        elif s.startswith("RECT"):
            m = re.match(
                r"(\s*RECT\s+)([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)\s+([0-9.]+)(\s*;.*\n?)",
                line,
            )
            line = (
                f"{m.group(1)}{m.group(2)} {float(m.group(3)) * er:.3f} "
                f"{m.group(4)} {float(m.group(5)) * er:.3f}{m.group(6)}"
            )
        out.append(line.replace(parent, new))
    return "".join(out)


def nums(t):
    return [float(x) for x in re.findall(r"[0-9]+\.[0-9]+", t)]


def check():
    er = 240.0 / 256.0
    ok = True
    for kind, fn in (("lib", scale_lib), ("lef", scale_lef)):
        src = open(os.path.join(HERE, f"fakeram45_16x256.{kind}")).read()
        ref = open(os.path.join(HERE, f"fakeram45_16x240.{kind}")).read()
        gen = (
            fn(src, "fakeram45_16x256", "fakeram45_16x240", er, er)
            if kind == "lib"
            else fn(src, "fakeram45_16x256", "fakeram45_16x240", er)
        )
        a, b = nums(gen), nums(ref)
        bad = [(i, x, y) for i, (x, y) in enumerate(zip(a, b)) if abs(x - y) > 0.0015]
        if len(a) != len(b) or bad:
            print(
                f"[check] {kind}: MISMATCH count {len(a)} vs {len(b)}, first bad: {bad[:3]}"
            )
            ok = False
        else:
            print(
                f"[check] {kind}: all {len(a)} numeric values match the committed 16x240"
            )
    return 0 if ok else 1


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("parent", nargs="?")
    ap.add_argument("new", nargs="?")
    ap.add_argument("ratio", nargs="?", type=float)
    ap.add_argument("--timing-ratio", type=float, default=None)
    ap.add_argument("--check", action="store_true")
    a = ap.parse_args()
    if a.check:
        sys.exit(check())
    tr = a.timing_ratio if a.timing_ratio is not None else a.ratio
    for kind in ("lib", "lef"):
        src = open(os.path.join(HERE, f"{a.parent}.{kind}")).read()
        gen = (
            scale_lib(src, a.parent, a.new, a.ratio, tr)
            if kind == "lib"
            else scale_lef(src, a.parent, a.new, a.ratio)
        )
        with open(os.path.join(HERE, f"{a.new}.{kind}"), "w") as f:
            f.write(gen)
        print(f"[gen] wrote {a.new}.{kind} (energy x{a.ratio}, timing x{tr})")


if __name__ == "__main__":
    main()
