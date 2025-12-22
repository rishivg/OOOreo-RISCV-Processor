# Checkpoint 1 Progress Report

## Overview
For Checkpoint 1, we implemented the complete front-end of our Tomasulo-based OoO processor. This included designing the high-level architecture diagram, implementing the fetch stage with a linebuffer, integrating the instruction cache with the DRAM model, and building all required frontend components.

## Completed Work

### Architecture Diagram
- Created a detailed block diagram of the full OoO datapath using draw.io.
- Diagram includes: Fetch → Decode → Dispatch/Rename → Reservation Stations → Functional Units → CDB → ROB → Commit.
- Clearly represents state flow, dependencies, and frontend/backend boundaries.

### Parameterizable FIFO Queue
- Implemented a width- and depth-parameterized FIFO used as the instruction queue.
- Covered all necessary edge cases:
  - Full and empty detection using MSB wrap tracking.
  - Circular buffer pointer wraparound logic.
- Wrote comprehensive DUT-level tests verifying enqueue/dequeue, simultaneous operations, wraparound, and stall behavior.

### Cacheline Adapter
- Implemented a cacheline adapter to interface between DRAM’s 4×64-bit burst responses and the 256-bit cachelines.
- Correctly handles:
  - Burst accumulation
  - Response signaling
  - DRAM ready/valid handshake semantics
- Integrated with the instruction cache for full linebuffer support.

### Fetch Stage + Linebuffer
- Implemented instruction fetch with 1-IPC throughput for instructions within the same cacheline.
- Added a 256-bit linebuffer to avoid mp_cache’s alternating-cycle response behavior.
- Correctly detects:
  - Same-cacheline hits (serve from buffer)
  - Cross-cacheline boundaries (issue new cache request)
- PC initialized to `0xAAAAA000` as required.

### Architecture Selection
- Selected **Tomasulo-style** out-of-order architecture.
- Submitted the required architecture selection form.

## Notes
- All CP1 components are functional and tested.
- Fetch stage output cleanly interfaces with the instruction queue and downstream decode logic.

