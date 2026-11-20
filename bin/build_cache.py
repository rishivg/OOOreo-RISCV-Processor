"""Content-checked build reuse. Test execution is never cached."""

from contextlib import contextmanager
import fcntl
import hashlib
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import sys


def digest(path):
    checksum = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            checksum.update(chunk)
    return checksum.hexdigest()


def file_hashes(paths):
    return {str(path): digest(path) for path in sorted({Path(p).resolve() for p in paths})}


def tool_identity(name, version_args=(), env=None):
    environment = os.environ if env is None else env
    arguments = [name] if shutil.which(name, path=environment.get("PATH")) else shlex.split(name)
    executable = shutil.which(arguments[0], path=environment.get("PATH"))
    if executable is None:
        raise FileNotFoundError(f"Required build tool is missing: {name}")
    result = {"path": str(Path(executable).resolve()), "sha256": digest(executable),
              "arguments": arguments[1:]}
    if version_args:
        result["version"] = subprocess.check_output(
            [executable, *arguments[1:], *version_args], stderr=subprocess.STDOUT,
            text=True, env=environment
        ).strip()
    return result


def verilator_signature(command):
    # Worker count changes scheduling, not the simulator being compiled.
    arguments = iter(map(str, command))
    compile_command = []
    for argument in arguments:
        if argument == "-j":
            next(arguments)
        else:
            compile_command.append(argument)
    return {"command": compile_command,
            "verilator": tool_identity("verilator", ("--version",)),
            "compiler": tool_identity(os.environ.get("CXX", "g++"), ("--version",)),
            "environment": {key: os.environ.get(key) for key in (
                "CC", "CXX", "CFLAGS", "CPPFLAGS", "CXXFLAGS", "LDFLAGS", "CPATH",
                "CPLUS_INCLUDE_PATH", "LIBRARY_PATH", "LD_LIBRARY_PATH", "VERILATOR_ROOT",
                "OPT_FAST", "OPT_SLOW", "OPT_GLOBAL", "VM_USER_CFLAGS")}}


def discard_native_objects(directory):
    """Force native recompilation on a content miss, regardless of make timestamps."""
    for path in Path(directory).iterdir():
        if path.is_file() and path.suffix in (".o", ".a", ".gch"):
            path.unlink()


def cached_verilator(manifest, inputs, binary, command, log, *, cwd, force=False):
    """Compile a logged simulator build, discarding stale native products on a miss."""
    binary, log = Path(binary), Path(log)

    def compile_model():
        discard_native_objects(binary.parent)
        binary.unlink(missing_ok=True)
        log.parent.mkdir(parents=True, exist_ok=True)
        with log.open("w") as stream:
            try:
                subprocess.run(command, cwd=cwd, stdout=stream,
                               stderr=subprocess.STDOUT, check=True)
            except subprocess.CalledProcessError:
                print(log.read_text(), file=sys.stderr)
                raise

    return cached_build(manifest, inputs, [binary], verilator_signature(command),
                        compile_model, force=force or not os.access(binary, os.X_OK))


@contextmanager
def build_lock(manifest):
    manifest.parent.mkdir(parents=True, exist_ok=True)
    with manifest.with_suffix(manifest.suffix + ".lock").open("a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        yield


def cached_build(manifest, inputs, outputs, signature, build, *, force=False):
    """Run build on a miss; verify both source inputs and products on every hit.

    A failed/interrupted build has no reusable receipt. Serializing each receipt
    also prevents two invocations from generating into the same output directory.
    """
    manifest = Path(manifest)
    inputs = [*inputs, Path(__file__)]
    outputs = list(outputs)
    with build_lock(manifest):
        expected = {"schema_version": 1, "inputs": file_hashes(inputs), "signature": signature}
        try:
            previous = json.loads(manifest.read_text())
            hit = all(previous[key] == value for key, value in expected.items())
            hit = hit and previous["outputs"] == file_hashes(outputs)
        except (OSError, ValueError, KeyError, TypeError):
            hit = False
        if hit and not force:
            return False
        manifest.unlink(missing_ok=True)
        build()
        if file_hashes(inputs) != expected["inputs"]:
            raise RuntimeError("Build inputs changed during execution; rerun the build")
        receipt = dict(expected, outputs=file_hashes(outputs))
        temporary = manifest.with_name(f"{manifest.name}.{os.getpid()}.tmp")
        try:
            temporary.write_text(json.dumps(receipt, indent=2) + "\n")
            temporary.replace(manifest)
        finally:
            temporary.unlink(missing_ok=True)
        return True
