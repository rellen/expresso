{
  description = "Elixir";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  # A release of the channel nixpkgs-unstable, nixpkgs-26.11pre1078010, of
  # 2026-09-22. It gives the versions of .tool-versions: Erlang/OTP 29.1,
  # Elixir 1.20.4, Node 24.20.0 and Zig 0.16.0. On 2026-09-27, Burrito had no
  # ERTS for OTP 29.1.1. docs/development.md tells how to move the pin.
  inputs.nixpkgs.url = "github:NixOS/nixpkgs/b6c98e9e6633ee64753b594ff4a5febf0367fc00";

  outputs = { self, nixpkgs, flake-utils }@inputs:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = { allowUnfree = true; };
        };
      in { devShell = import ./shell.nix { inherit pkgs nixpkgs; }; });
}
