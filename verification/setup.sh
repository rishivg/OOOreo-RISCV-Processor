#!/bin/bash
# Linux x86_64; host prerequisites: C/C++ toolchain, make, curl, uv, Java/sbt,
# Verilator, patch, and RV32-capable riscv64-unknown-elf-gcc (the benchmark compiler).
set -euo pipefail
REPO=$(cd "$(dirname "$0")/.." && pwd)
WORK=$(mkdir -p "${1:-$REPO/verification/work}" && cd "${1:-$REPO/verification/work}" && pwd)
mkdir -p "$WORK"/{bin,root,debs,apt/lists/partial}
export UV_CACHE_DIR="$WORK/uv-cache" UV_PYTHON_INSTALL_DIR="$WORK/python"
uv python install 3.11.17
[[ -x "$WORK/venv/bin/python" ]] || uv venv --python 3.11.17 --seed "$WORK/venv"
uv pip install --python "$WORK/venv/bin/python" -r "$REPO/verification/requirements.txt"
"$WORK/venv/bin/python" "$REPO/verification/run.py" fetch --work "$WORK"
uv pip install --python "$WORK/venv/bin/python" --no-deps \
    -e "$WORK/upstream/act4/framework" -e "$WORK/upstream/act4/generators/testgen" \
    -e "$WORK/upstream/act4/generators/coverage"

# Signed Debian packages are extracted locally; no privileged installation.
if [[ ! -x "$WORK/root/usr/bin/ruby3.3" ]]; then
    cat > "$WORK/apt/sources.list" <<'APT'
deb [signed-by=/usr/share/keyrings/debian-archive-keyring.gpg] https://deb.debian.org/debian trixie main
APT
    APT=(-o Dir::Etc::parts=- -o Dir::Etc::main=- -o Dir::Etc::sourcelist="$WORK/apt/sources.list"
         -o Dir::Etc::sourceparts=- -o Dir::State::lists="$WORK/apt/lists"
         -o APT::Sandbox::User="$(id -un)")
    apt-get "${APT[@]}" update
    (cd "$WORK/debs" && apt-get "${APT[@]}" download \
        ruby3.3 ruby3.3-dev libruby3.3 ruby-rubygems ruby-bundler rubygems-integration libyaml-0-2)
    for package in "$WORK"/debs/*.deb; do dpkg-deb -x "$package" "$WORK/root"; done
fi
ln -sf "$WORK/root/usr/bin/ruby3.3" "$WORK/bin/ruby"
cat > "$WORK/activate.sh" <<ACTIVATE
export PATH="$WORK/bin:$WORK/root/usr/bin:$WORK/sail/sail-riscv-Linux-x86_64/bin:$WORK/venv/bin:\$PATH"
export LD_LIBRARY_PATH="$WORK/root/usr/lib/x86_64-linux-gnu\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
export RUBYLIB="$WORK/root/usr/lib/ruby/3.3.0:$WORK/root/usr/lib/x86_64-linux-gnu/ruby/3.3.0:$WORK/root/usr/lib/ruby/vendor_ruby:$WORK/root/usr/lib/x86_64-linux-gnu/ruby/vendor_ruby/3.3.0"
export GEM_HOME="$WORK/bundle/ruby/3.3.0"
export GEM_PATH="\$GEM_HOME:$WORK/root/usr/lib/ruby/gems/3.3.0:$WORK/root/usr/share/rubygems-integration/all"
export BUNDLE_PATH="$WORK/bundle" BUNDLE_APP_CONFIG="$WORK/bundle-config" BUNDLE_USER_HOME="$WORK/bundle-user"
export UV_CACHE_DIR="$WORK/uv-cache" UV_PYTHON_INSTALL_DIR="$WORK/python"
export XDG_CACHE_HOME="$WORK/cache" XDG_DATA_HOME="$WORK/data"
export PATH="\$GEM_HOME/bin:\$PATH"
ACTIVATE
source "$WORK/activate.sh"

# Verify official release archives before extracting executable tools.
python - "$REPO" "$WORK" <<'PY'
import hashlib,json,subprocess,sys
from pathlib import Path
repo,work=map(Path,sys.argv[1:])
for name,spec in json.loads((repo/'verification/tools.json').read_text()).items():
    filename,destination,binary = {
        'sail': ('sail.tar.gz','sail','sail/sail-riscv-Linux-x86_64/bin/sail_riscv_sim'),
        'act_gcc': ('gcc15.tar.xz','gcc15','gcc15/riscv/bin/riscv64-unknown-elf-gcc')
    }[name]
    archive=work/filename
    if not archive.exists():
        subprocess.run(['curl','--fail','--location','--retry','3',spec['url'],'-o',archive],check=True)
    with archive.open('rb') as stream:
        digest=hashlib.file_digest(stream,'sha256').hexdigest()
    if digest != spec['sha256']: raise ValueError(f'{name}: archive checksum mismatch')
    if not (work/binary).exists():
        (work/destination).mkdir(exist_ok=True)
        subprocess.run(['tar','-xf',archive,'-C',work/destination],check=True)
PY

# Use ACT's locked gem checksums and the native Linux FFI package.
export BUNDLE_GEMFILE="$WORK/upstream/act4/framework/src/act/data/Gemfile"
if ! ruby "$WORK/root/usr/bin/bundle" check; then
    python - "$WORK" <<'PY'
import hashlib,json,re,subprocess,sys
from pathlib import Path
work=Path(sys.argv[1]); gems=work/'gems'; gems.mkdir(exist_ok=True)
lock=(work/'upstream/act4/framework/src/act/data/Gemfile.lock').read_text()
items=re.findall(r'^  ([\w-]+) \(([^)]+)\) sha256=([0-9a-f]+)$',lock,re.M)
items=[x for x in items if x[0]!='ffi' or x[1].endswith('-x86_64-linux-gnu')]
meta=subprocess.check_output(['curl','--fail','--silent','--show-error',
    'https://rubygems.org/api/v2/rubygems/bundler/versions/4.0.22.json?platform=ruby'])
items.append(('bundler','4.0.22',json.loads(meta)['sha']))
files=[]
for name,version,digest in items:
    path=gems/f'{name}-{version}.gem'
    if not path.exists():
        subprocess.run(['curl','--fail','--location','--silent','--show-error','--retry','3',
            f'https://rubygems.org/downloads/{path.name}','-o',path],check=True)
    if hashlib.sha256(path.read_bytes()).hexdigest()!=digest: raise ValueError(f'{path}: checksum mismatch')
    files.append(path)
subprocess.run(['ruby',work/'root/usr/bin/gem','install','--local','--ignore-dependencies',
    '--no-document',*files],check=True)
PY
fi
cat > "$WORK/bin/bundle" <<BUNDLE
#!/bin/bash
exec ruby "$WORK/root/usr/bin/bundle" "\$@"
BUNDLE
chmod +x "$WORK/bin/bundle"
bundle check
unset BUNDLE_GEMFILE

if [[ ! -f "$WORK/newlib/riscv64-unknown-elf/lib/libc.a" ]]; then
    mkdir -p "$WORK/newlib-build"
    (cd "$WORK/newlib-build"
     "$WORK/upstream/newlib/configure" --target=riscv64-unknown-elf --prefix="$WORK/newlib" \
        --disable-multilib --disable-newlib-supplied-syscalls --enable-newlib-nano-malloc \
        --disable-newlib-io-float CFLAGS_FOR_TARGET='-O2 -march=rv32imac -mabi=ilp32'
     make -j2 all-target-newlib
     make install-target-newlib)
fi
riscv64-unknown-elf-gcc --version | head -1
"$WORK/gcc15/riscv/bin/riscv64-unknown-elf-gcc" --version | head -1
sail_riscv_sim --version
printf 'Activate with: source %q/activate.sh\n' "$WORK"
