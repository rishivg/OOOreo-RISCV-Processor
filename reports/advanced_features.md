# Advanced Features Progress Report

## Overview
For the Advanced Features stage, we added several performance-oriented enhancements across branch prediction, memory execution, and issue scheduling. All features were integrated into our CP3 baseline and verified across all benchmarks with RVFI and Spike.

## Completed Advanced Features

### TAGE Branch Predictor
- Replaced static prediction to significantly reduce mispredict penalties.

### Return Address Stack (RAS)
- Added RAS for CALL/RET instructions.
- Improves prediction accuracy for function-heavy workloads.

### Stride Prefetcher
- Dynamically detects stride patterns and prefetches future lines.

### Split Load/Store Queue
- Separated LSQ into independent Load Queue and Store Queue.
- Allows loads to issue out-of-order relative to unrelated stores.

### Age-Ordered Issue Scheduling
- Added oldest-first prioritization for issuing ready instructions.
- Helps reduce ROB head stalls and smooth backend execution.

## Summary
We implemented five advanced features across branch prediction, memory, and scheduling categories: TAGE, RAS, Stride Prefetcher, Split LSQ, and Age-Ordered Issue Scheduling. These features improved overall performance while maintaining correctness and synthesizability.
