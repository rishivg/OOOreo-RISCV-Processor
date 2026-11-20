#!/usr/bin/env python3
"""Write OpenRAM compiler configurations without overwriting tracked models."""

import argparse
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent


def generate(destination):
    for source in sorted((ROOT / "config").glob("*.json")):
        cfg = json.loads(source.read_text())
        name = source.stem
        directory = destination / name
        directory.mkdir(parents=True, exist_ok=True)
        values = {
            "tech_name": "freepdk45",
            "num_rw_ports": cfg["num_rw_ports"],
            "num_r_ports": 0,
            "num_w_ports": 0,
            "word_size": cfg["word_size"],
            "write_size": (
                None if cfg["word_size"] == cfg["write_size"] else cfg["write_size"]
            ),
            "num_words": cfg["num_words"],
            "nominal_corner_only": True,
            "process_corners": ["TT"],
            "supply_voltages": [1.0],
            "temperatures": [25],
            "netlist_only": False,
            "route_supplies": False,
            "check_lvsdrc": False,
            "perimeter_pins": False,
            "load_scales": [0.5, 1, 4],
            "slew_scales": [0.5, 1],
            "output_name": name,
            "output_path": str(directory),
            "print_banner": False,
            "num_threads": 4,
            "output_extended_config": True,
        }
        path = directory / f"{name}.py"
        path.write_text(
            "\n".join(f"{key} = {value!r}" for key, value in values.items()) + "\n"
        )
        print(path)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", type=Path, default=ROOT / "generated")
    generate(parser.parse_args().out.resolve())
