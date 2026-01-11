# Software tools

This directory contains Python analysis and indexing tools for simulation artifacts.

Usage example (index konata JSONL into SQLite):

```bash
python3 sw/tools/konata_index.py sim/verilator/konata.jsonl --db sim/konata.db
```

Install optional dependencies:

```bash
python3 -m pip install -r sw/tools/requirements.txt
```
