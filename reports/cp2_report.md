# Checkpoint 2 Progress Report

## Overview
For Checkpoint 2, we completed the core Tomasulo pipeline: decode, rename/dispatch, reservation stations, ROB, execution units, register file interaction, and CDB. The processor now executes all RV32I immediate and register instructions and fully supports the RV32M extension using Synopsys IPs. Out-of-order execution is correct and verified.

## Completed Work

### RV32I Execution Support
- Implemented support for all immediate and register-type RV32I instructions.
- Correct ALU operations, operand selection, and bypassing through the CDB.
- AUIPC support added.

### Tomasulo Back-End
- Fully implemented Reservation Stations, ROB, and the CDB.
- ROB manages precise state and in-order commit.
- Reservation Stations track operand readiness and issue instructions when dependencies resolve.
- Correct handling of RAW, WAR, and WAW hazards.

### Multiplier & Divider Integration
- Integrated **DW_mult_pipe** for all RV32M `MUL` operations.
- Integrated **DW_div** for `DIV` and `REM`.
- Implemented RV32M-compliant divide-by-zero behavior.

### Out-of-Order Execution Demonstration
- Successfully demonstrated OoO execution on `ooo_test.s`.
- Verified wakeup/issue ordering, result broadcast, and ROB commit behavior.

### Lint and RVFI Compliance
- Passed Spyglass lint with zero warnings.
- Connected processor to RVFI/Spike reference model as required.
- No RVFI mismatches, memory errors, or Spike divergences.
- Wrote additional custom tests to validate:
  - Operand forwarding behavior
  - Dependency chains
  - Long-latency EXEC paths
  - Multi-cycle functional units

## Notes
- Backend is stable and prepared for memory and control-flow integration for CP3.
- Tomasulo structures are modular and parameterized for future advanced features.

