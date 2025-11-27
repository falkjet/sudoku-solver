{
  description = "An empty project that uses Zig.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flake-utils.url = "github:numtide/flake-utils";
    zig.url = "github:mitchellh/zig-overlay";

    # Used for shell.nix
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, ... }@inputs:
    let
      overlays = [
        # Other overlays
        (final: prev: { zigpkgs = inputs.zig.packages.${prev.system}; })
      ];

      # Our supported systems are the same supported systems as the Zig binaries
      systems = builtins.attrNames inputs.zig.packages;
    in flake-utils.lib.eachSystem systems (system:
      let pkgs = import nixpkgs { inherit overlays system; };
      in rec {
        devShells.default =
          pkgs.mkShell { nativeBuildInputs = with pkgs; [ zigpkgs."0.14.0" ]; };
        packages = rec {
          sudoku-solver = pkgs.stdenv.mkDerivation {
            name = "sudoku-solver";
            nativeBuildInputs = with pkgs; [ zigpkgs.master ];
            buildPhase = ''
              ZIG_GLOBAL_CACHE_DIR="$PWD" zig build --release=fast
            '';
            installPhase = ''
              ZIG_GLOBAL_CACHE_DIR="$PWD" zig build --prefix "$out" --release=fast
            '';
            src = ./.;
          };
          default = sudoku-solver;
        };

        # For compatibility with older versions of the `nix` binary
        devShell = self.devShells.${system}.default;
      });
}
