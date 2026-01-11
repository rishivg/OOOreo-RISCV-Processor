# Konata JSON event schema

Supported event objects (newline-delimited JSON):

- `meta`: top-level metadata emitted once at start.
  - `{ "meta": { "kanata_version": 4, "start_time": 12345 } }`

- `cycle`: heartbeat with cycle count.
  - `{ "event": "cycle", "cycle": 12345 }`

- `dispatch`: when uops are dispatched into ROB slots.
  - `{ "event": "dispatch", "cycle": 12345, "instr_id": 42, "rob_row": 3, "rob_col": 1, "dispatch_index": 0 }`

- `lifecycle`: optional per-instr phase markers (stage names). Fields: `phase`, `instr_id`, `cycle`.

- `execute`: CDB execution event.
  - `{ "event": "execute", "cycle": 12346, "instr_id": 42, "cdb": 0, "rob_row": 3, "rob_col": 1 }`

- `commit`: when an instruction commits.
  - `{ "event": "commit", "cycle": 12350, "instr_id": 42, "rob_row": 3, "rob_col": 1 }`

- `flush`: pipeline flush event.
  - `{ "event": "flush", "cycle": 12360 }

Notes:
- Each JSON object should be one line (JSONL) for easy streaming and indexing.
- Additional fields (pc, rd, mem_addr, value) can be added to events as needed; the indexer will store raw JSON alongside parsed columns.
