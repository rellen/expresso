{ pkgs ? import <nixpkgs> { }, nixpkgs ? <nixpkgs> }:
let
  inherit (pkgs.lib) optional;
  beam = pkgs.beam.packages.erlang_28;
  erlang = pkgs.beam.interpreters.erlang_28;
  elixir = beam.elixir_1_20;
  elixir-ls = beam.elixir-ls.override { inherit elixir; };
  # Burrito pins the Zig it builds wrappers with; keep this in step with
  # @zig_version_expected in burrito.ex (1.6.0 wants exactly 0.16.0).
  zig = pkgs.zig_0_16;

in pkgs.mkShell rec {
  name = "Elixir";
  buildInputs = with pkgs;
    [ rebar rebar3 erlang elixir elixir-ls nodejs_24 prettier zig xz ]
    ++ optional stdenv.hostPlatform.isLinux inotify-tools;

  shellHook = ''
    # this allows mix to work on the local directory
    mkdir -p .nix-mix
    mkdir -p .nix-hex
    export MIX_HOME=$PWD/.nix-mix
    export HEX_HOME=$PWD/.nix-hex
    export PATH=$MIX_HOME/bin:$PATH
    export PATH=$HEX_HOME/bin:$PATH
    export LANG=en_US.UTF-8
    export ERL_AFLAGS="-kernel shell_history enabled"
    export ERL_LIBS=""
  '';
}
