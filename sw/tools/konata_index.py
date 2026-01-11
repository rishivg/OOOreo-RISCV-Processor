#!/usr/bin/env python3
"""Parse konata.jsonl and build an SQLite index for fast queries."""
import argparse
import json
import sqlite3
from pathlib import Path


def build_index(jsonl_path: Path, db_path: Path, batch=1000):
    conn = sqlite3.connect(str(db_path))
    cur = conn.cursor()
    cur.execute("PRAGMA synchronous = OFF")
    cur.execute("PRAGMA journal_mode = WAL")

    cur.execute("CREATE TABLE IF NOT EXISTS events(id INTEGER PRIMARY KEY, cycle INTEGER, event TEXT, instr_id INTEGER, rob_row INTEGER, rob_col INTEGER, raw JSON)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_cycle ON events(cycle)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_instr ON events(instr_id)")
    cur.execute("CREATE INDEX IF NOT EXISTS idx_event ON events(event)")

    inserted = 0
    batch_rows = []
    with jsonl_path.open() as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                obj = json.loads(line)
            except Exception:
                # skip malformed lines
                continue

            # metadata lines stored with event NULL
            if 'meta' in obj:
                continue

            cycle = obj.get('cycle')
            event = obj.get('event')
            instr_id = obj.get('instr_id')
            rob_row = obj.get('rob_row')
            rob_col = obj.get('rob_col')

            batch_rows.append((cycle, event, instr_id, rob_row, rob_col, line))
            if len(batch_rows) >= batch:
                cur.executemany("INSERT INTO events(cycle,event,instr_id,rob_row,rob_col,raw) VALUES(?,?,?,?,?,?)", batch_rows)
                conn.commit()
                inserted += len(batch_rows)
                batch_rows = []

    if batch_rows:
        cur.executemany("INSERT INTO events(cycle,event,instr_id,rob_row,rob_col,raw) VALUES(?,?,?,?,?,?)", batch_rows)
        conn.commit()
        inserted += len(batch_rows)

    conn.close()
    return inserted


def main():
    p = argparse.ArgumentParser()
    p.add_argument('jsonl', type=Path, help='konata.jsonl file')
    p.add_argument('--db', type=Path, default=Path('konata.db'), help='output sqlite DB')
    args = p.parse_args()

    inserted = build_index(args.jsonl, args.db)
    print(f'Inserted {inserted} events into {args.db}')


if __name__ == '__main__':
    main()
