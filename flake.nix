{
  description = "Chinese Checker - Gleam/Lustre dev environment";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

  outputs = { self, nixpkgs }:
    let
      systems = [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
      forAllSystems = f:
        nixpkgs.lib.genAttrs systems (system: f nixpkgs.legacyPackages.${system});
    in {
      devShells = forAllSystems (pkgs: {
        default = pkgs.mkShell {
          packages = with pkgs; [
            gleam    # 1.14+ required by gleam_stdlib >= 0.44
            nodejs   # JS runtime for gleam run + lustre dev tools
            python3  # tools/generate_hsk_gleam.py, tools/preprocess_dictionary.py
          ];

          shellHook = ''
            echo "gleam $(gleam --version)"
            echo "node $(node --version)"
          '';
        };
      });
    };
}
