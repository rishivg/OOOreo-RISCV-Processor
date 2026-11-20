# Physical implementation

This package contains one 601.5 MHz Nangate45 implementation. The layout, connectivity,
constraints, models and per-instance power export are bound by [SHA-256 hashes](files.json).
[result.json](result.json) records the measurement conditions and tool hash.

From the repository root, check the files, decode the layout, and independently
sum all 361,846 physical instances' power components:

```sh
python3 synth/implementation/verify.py --output /tmp/oooreo-implementation
```

Requires Python 3.10+ and zstd. To repeat setup, hold, electrical, clock and area
checks, add `--openroad /path/to/openroad` using the recorded binary and its runtime
libraries. The [pinned ORFS image](../../tools/versions.lock) supplies the toolchain.
Reports and decoded files go to `--output`.

The result uses TT, 1.1 V, 25 °C, propagated clocks and placement RC. SRAM and divider
models are placeholders. Power assumes uniform activity 0.1 and duty 0.5. Hold meets
a 50 ps floor; the additional 100 ps setup guard is unmet. This is a placement
estimate, with no routed signoff or silicon measurement. The power check reproduces
an exported estimate; it does not run a device model.
It sums binary32 instance components in binary64, so its total can differ slightly
from OpenROAD's single-precision report total.

The physical netlist and portable RTL are distinct implementations. Source generation
does not recreate this layout. The included checks establish file integrity and
physical measurements, not full-core equivalence to regenerated RTL.
