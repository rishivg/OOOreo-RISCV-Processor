# Checkpoint 3 Progress Report

## Overview
For Checkpoint 3, we completed full RV32IM support and integrated both the instruction and data caches with arbitration logic for the shared DRAM interface. Our Tomasulo-based OoO core now correctly handles all memory and control instructions and passes all required benchmark tests on the autograder.

## Completed Work

### Data Cache Integration
- Integrated the data cache alongside the existing instruction cache.
- Added arbitration logic in the cacheline adapter to handle requests from both caches.
- Ensured correct sequencing of DRAM read/write requests and proper routing of responses.

### Memory Instruction Support
- Implemented full support for all RV32I load and store instructions.
- Memory operations are performed in order at ROB commit, ensuring correctness.
- Loads are fully functional before commit as recommended in the lab.
- Verified correct RAW, WAW, and WAR handling through the LSQ/ROB interactions.

### Control Instruction Support
- Implemented BR, JAL, JALR, and AUIPC.
- Added misprediction recovery logic: flushing RS, ROB, and restoring PC when needed.
- Static branch handling (not-taken/taken) is implemented as allowed for CP3.

### Correctness and Verification
- Passed synthesis and Spyglass lint with zero warnings.
- Processor connected to RVFI/Spike monitor with no mismatches or memory errors.
- Successfully ran all required CP3 benchmarks:
  - Coremark IM
  - FFT
  - Mergesort
  - AES-SHA
  - Compression

### Benchmark Success
All benchmarks completed without Spike mismatches or RVFI errors:
- Coremark IM: passed
- FFT: passed
- Mergesort: passed
- AES-SHA: passed
- Compression: passed

## Notes
- The pipeline handles speculation, branch recovery, and memory ordering correctly.
- Cache arbitration was the main structural addition for this checkpoint and is functioning as intended.
- The design remains modular and parameterized to support upcoming advanced features.

## Next Steps
- Begin planning and implementing advanced features (prefetchers, store buffer, non-blocking cache, branch predictors, etc.).
- Add performance counters to identify bottlenecks.
- Prepare architectural diagrams and documentation for the final report.
