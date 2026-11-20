"""Read monitor measurements and failures shared by simulation tools."""

import re
from typing import NamedTuple

RVFI_ERROR = re.compile(r"RVFI Monitor [Ee]rror|Monitor error \d+ in channel")
FAILURE_PATTERNS = (
    (RVFI_ERROR, "RVFI"),
    (re.compile(r"TB Error: Timed out"), "TIMEOUT"),
    (re.compile(r"Spurious|Error: |\$fatal|Assertion failed"), "ERROR"),
)


class IpcMeasurement(NamedTuple):
    kind: str
    value: str
    time_ps: int | None


def monitor_ipc(text, *, prefer_segment=False):
    """Pair the preferred IPC marker with time from the same measurement window."""
    kinds = ("Segment", "Total") if prefer_segment else ("Total", "Segment")
    for kind in kinds:
        match = re.search(rf"Monitor:\s*{kind} IPC:\s*(\d+(?:\.\d+)?)(?=\s|$)", text)
        if match:
            time = re.search(rf"Monitor:\s*{kind} Time:\s*(\d+)", text)
            return IpcMeasurement(kind.lower(), match[1], int(time[1]) if time else None)
    return None


def classify(log):
    """Passing requires an IPC/halt marker and no monitor or simulator errors."""
    for pattern, status in FAILURE_PATTERNS:
        match = pattern.search(log)
        if match:
            return status, log[match.start():match.end() + 60].splitlines()[0].strip()
    measurement = monitor_ipc(log)
    return (("PASS", measurement.value) if measurement
            else ("NOFINISH", "no IPC/halt printed (hang or crash)"))
