# Contributing

Use the setup instructions in [README.md](README.md), then run:

```sh
python3 -m unittest discover -s tests
(cd hdl && sbt -batch test)
make -C lint lint
```

Add a regression that checks the behavior being changed. For RTL changes, inspect
the generated Verilog and run the relevant RVFI programs. Queue ordering, flushes,
stalls, collisions and non-power-of-two resource sizes deserve particular care.
Explain any configuration restrictions in the validation code.

Keep generated files and local measurements out of commits. Record the resolved
configuration, tools, workloads and constraints when reporting performance.
Source simulation, block synthesis and physical implementation are separate
measurements and must be labeled accordingly.

Keep comments focused on protocol requirements, priority, timing assumptions and
other constraints that are not clear from the code. Use the terminology and
formatting of the surrounding module.

Contributions are submitted under Apache-2.0 unless explicitly stated otherwise.
Preserve third-party copyright and license notices.
