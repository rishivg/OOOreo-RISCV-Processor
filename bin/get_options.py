#!/usr/bin/env python3
"""Read simulator and bare-metal compiler options."""

import argparse
import json
from pathlib import Path


def value(key):
    options = json.loads(
        (Path(__file__).resolve().parents[1] / "options.json").read_text()
    )
    if key == "arch":
        return "rv32im" + "".join(
            ext for ext in "ac" if options.get(f"{ext}_ext", False)
        )
    if key == "abi":
        return "ilp32"
    if key == "clock":
        period = options["clock"]
        if not isinstance(period, int) or period <= 0 or period % 2:
            raise ValueError("clock must be a positive even integer in picoseconds")
        return period
    if key == "bmem_x":
        return int(options["bmem_0_on_x"])
    raise ValueError(f"unknown option: {key}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("key", choices=("arch", "abi", "clock", "bmem_x"))
    args = parser.parse_args()
    try:
        print(value(args.key))
    except ValueError as error:
        parser.error(str(error))
