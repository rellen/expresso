# The toolchain

This page tells you how to get the versions of the tools that the checks need.

The versions are in `.tool-versions`: Elixir 1.20.4, Erlang/OTP 29.1, Node 24.20.0 and
Zig 0.16.0. Zigler needs Zig to compile the GIF encoder of `tools/` in dev and in test,
so `mix compile` and `mix test` need it. Burrito needs Zig for the binary.

Four places give a toolchain, and each place gives these versions:

- `flake.nix` and `shell.nix`, which the Nix shell reads on your machine.
- `.tool-versions`, which asdf and mise read.
- `.claude/hooks/session-start.sh`, which a remote Claude Code session runs.
- `.github/workflows/check.yml`, which GitHub runs for a pull request.

Therefore each command gives the same result in each place. After a change to one place,
change the other three.

## On your machine

Use the Nix shell. It gives each tool, and it gives Zig for Zigler and for Burrito.

```sh
nix develop      # or: direnv allow, after you copy .envrc.example to .envrc
mix deps.get
```

`flake.nix` pins `nixpkgs` to one commit, `b6c98e9e6633`. This commit is the release
`nixpkgs-26.11pre1078010` of the channel `nixpkgs-unstable`, from 2026-09-22. It gives
Erlang/OTP 29.1, Elixir 1.20.4, Node 24.20.0 and Zig 0.16.0 on Linux and on macOS, which
are the versions of `.tool-versions`. `nix flake update` does not move the pin.

Hydra built the channel release, so `cache.nixos.org` gives each tool of the shell. The
exception is `elixir-ls`, because `shell.nix` builds it with Elixir 1.20. On 2026-09-27,
`nix develop` on Linux built the shell. The shell made the binary with Burrito, and the
release tests passed.

To move the pin, do these steps:

1. Find a release of `nixpkgs-unstable` that gives the versions of `.tool-versions`.
   https://nix-releases.s3.amazonaws.com/?delimiter=/&prefix=nixpkgs/ lists each release,
   and the name of a release ends with the first 12 characters of its commit.
2. Make sure that Burrito has an ERTS for its OTP version. [The release tests](release.md#the-release-tests) gives
   the reason.
3. Put the commit in `flake.nix`, and run `nix flake lock`.

## In a Claude Code session on the web

A remote container has no Elixir, and it has no Nix. The hook
`.claude/hooks/session-start.sh` installs a toolchain at the start of each remote session.
The hook does nothing on your machine, where the Nix shell gives the tools.

The hook does these steps:

1. Download the Erlang build for Ubuntu 24.04 from `builds.hex.pm`, and put it in
   `/opt/otp`. The archive holds dialyzer, which `mix check` needs. `setup-beam` reads the
   same builds in the workflow.
2. Download the Elixir build for OTP 29 from `builds.hex.pm`, and put it in `/opt/elixir`.
3. Download the Node build from `nodejs.org`, and put it in `/opt/node`.
4. Put Zig in `/opt/zig` with `.github/actions/setup-zig/install.sh`, the script of the
   workflow. It downloads Zig from a community mirror, and it makes sure of the SHA-256.
   A failure gives a warning, and the hook continues. Without Zig, `mix compile` fails.
5. Write `PATH`, `ELIXIR_ERL_OPTIONS` and `LANG` into `$CLAUDE_ENV_FILE`.
6. `mix local.hex`, `mix local.rebar`, `mix deps.get`, `mix compile` and `npm install`.

The hook takes a version from an archive and not from an apt package, because the apt
packages are older. The apt package of Erlang gives OTP 25, the apt package of Elixir gives
1.14, and the container gives Node 22. Five rules apply to the container:

- The Elixir build must agree with the OTP release. The name of the file is
  `v1.20.4-otp-29.zip`.
- The archive of Erlang and the archive of Node are builds for Ubuntu 24.04 on x86_64. The
  hook stops with a message for a container of a different target.
- The container gives a latin1 name encoding. Therefore `ELIXIR_ERL_OPTIONS` must contain
  `+fnu`, or each command writes a warning.
- The container gives no utf8 language. Therefore `LANG` must be `C.UTF-8`, or a tool
  writes an escape sequence in place of a character such as a check mark.
- An archive of Hex or of rebar from a different OTP release does not load. Therefore the
  hook writes each archive again with `--force`.

Burrito needs Zig and `xz`. The container gives `xz`, and the hook gives Zig. Without Zig,
`mix release expresso_cli_app` gives the error "You MUST have `zig` and `xz` installed to
use Burrito". The Zig build takes approximately 400 MB of disk. [The release tests](release.md#the-release-tests)
gives the commands that make the binary and test it.

To run the hook again by hand:

```sh
CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR="$PWD" ./.claude/hooks/session-start.sh
```
