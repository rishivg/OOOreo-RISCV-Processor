# Development and simulation notes

Run Verilator simulation (example):

```bash
cd sim
make run_verilator_top_tb PROG=../testcode/coremark_im.elf
```

Plusargs supported by testbench:
- `+DEBUG` — enables realtime debug file output (`rt_debug.log`)
- `+DEBUG_CONSOLE` — enable per-cycle console debug prints (suppresses default concise `simulation.log` preservation)
- `+KANATA` — enable Konata JSONL logger (`konata.jsonl`)
