{
  # Reproducible dev shell for OOOreo. `nix develop` gives the exact host tools
  # (verilator, sv2v, riscv gcc, python) + formal stack (symbiyosys + solvers),
  # all pinned by flake.lock. The synth/PPA flow additionally uses the pinned
  # OpenROAD docker image (see tools/versions.lock ORFS_IMAGE) for yosys 0.64 +
  # OpenROAD -- host yosys here is for lint only (0.x cannot synth this design).
  description = "OOOreo RV32IM OoO core toolchain";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "x86_64-linux" "aarch64-linux" ];
      forAll = f: nixpkgs.lib.genAttrs systems (s: f nixpkgs.legacyPackages.${s});
    in {
      devShells = forAll (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            verilator
            yosys                       # lint only
            (haskellPackages.sv2v or sv2v)
            pkgsCross.riscv32-embedded.buildPackages.gcc   # rv32 bare-metal gcc
            python3
            gnumake
            # formal
            symbiyosys
            boolector
            yices
            # PPA flow driver needs docker on the host (orfs image), not packaged here
          ];
          shellHook = ''
            echo "OOOreo dev shell — see tools/versions.lock for pins."
            echo "  sim/lint:  make -C sim ... / make -C lint lint"
            echo "  synth/PPA: make -C synth ppa   (uses the pinned OpenROAD docker)"
            echo "  formal:    make -C formal"
          '';
        };
      });
    };
}
