# Memory models

`output/` contains tracked behavioral models for verification; `config/` contains
OpenRAM geometries. The D-cache tag word is 25 bits, including validity.
Run from the repository root:

```sh
make -C sram configs
OPENRAM=/path/to/openram make -C sram all
make -C sram clean
```

Configurations and compiled macros go under `generated/`; cleaning preserves
tracked models. OpenRAM needs its configured Python environment. Replacements
must preserve read latency, held chip-select behavior, write masks and tag width.
[ASIC screening](../synth/README.md) describes the placeholder physical libraries.
