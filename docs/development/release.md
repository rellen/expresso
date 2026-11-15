# The binary and its tests

This page tells you how to make the binary, and how the dependency test and the release tests use Expresso outside this repository.

## Make a binary

Burrito makes a binary for macOS and for Linux, on x86_64 and on aarch64:

```sh
mix release expresso_cli_app
```

The command needs Zig 0.16.0 and `xz` on the path. The Nix shell gives both, and so does
the hook of a remote Claude Code session.

`burrito_out/` holds one binary for each computer, such as
`burrito_out/expresso_cli_app_linux_x86`. `BURRITO_TARGET=linux_x86` in front of the
command makes only that binary.

The first run of a binary installs its release on the computer, in a directory that has
the version of the release. A later binary of the same version runs that installed release,
and not its own. Therefore change the version in `mix.exs` for each binary that you give
to other users. `<binary> maintenance uninstall` removes the installed release.

## The library of MDEx in the binary

MDEx makes the HTML of the notes of the speaker, and it is a NIF in Rust. RustlerPrecompiled
gets its library for the computer that compiles. That library is not correct for a binary:

- Burrito puts an ERTS for musl in a binary for Linux, and most computers have glibc.
- A binary for macOS from a computer with Linux gets the library of Linux.

`Expresso.Release.MDExLibrary` is a step of Burrito, and the release in `mix.exs` names it
in `extra_steps`. For each target, the step does these operations:

1. It gets the library for the target from the release of `mdex_native` on GitHub. The
   file cache of Burrito keeps the file for the next build.
2. It makes sure that the SHA-256 of the file is the one in
   `checksum-Elixir.MDExNative.Native.exs` of the Hex package.
3. It writes the library with the name of the library that the release holds, because
   `MDExNative.Native` loads the library by that name.
4. For Linux, it changes two entries of the library, and it builds an unwinder with
   `zig cc`.

### The unwinder for Linux

The library for musl needs `libgcc_s.so.1`, which unwinds the stack when Rust code panics.
The launcher of Burrito puts the library directories of the host first in
`LD_LIBRARY_PATH`, and musl looks there before it looks at the run path of a library. On
a computer with glibc, musl then gets the `libgcc_s.so.1` of glibc, and it stops:

```
Error relocating /lib/x86_64-linux-gnu/libgcc_s.so.1: _dl_find_object: symbol not found
```

The step therefore changes two entries of the dynamic section of the library:

| Before | After |
| --- | --- |
| `NEEDED` `libgcc_s.so.1` | `NEEDED` `expresso.so.1` |
| `NEEDED` `libc.so` | `RUNPATH` `$ORIGIN` |

Each new text has the length of the text that it replaces. The step thus moves no byte,
and it needs no tool such as `patchelf`. No host has a library with the name
`expresso.so.1`, so musl finds it only in the directory of the library of MDEx. musl is
always present in the process, so the library does not need the entry for `libc.so`.

`expresso.so.1` is the libunwind of LLVM. Zig holds its source in `lib/libunwind`, and the
step compiles that source for the target. The license of libunwind is Apache 2.0 with the
LLVM exception. A test outside the repository made a Rust library with the same two
entries. Its panic went through 21 functions, each destructor ran, and Rust caught it.

A new version of `mdex_native` can have a library with different entries. The step then
stops the build with a message, and it does not make a binary that fails later.

### The tests of the library

| Target | Test |
| --- | --- |
| `linux_x86` | The release tests, in a session and in the workflow. |
| `linux_arm` | The release tests in the workflow, on a runner with aarch64. |
| `macos_x86`, `macos_arm` | No test, because no job makes these binaries. The library of macOS needs only libraries that macOS holds. Run `mix check` on a Mac to test the binary of that Mac. |

The test "shows the Markdown of the notes of the speaker" makes sure that the binary
writes no warning about the library, and that the notes have their Markdown. The test
"writes the same HTML as Expresso.main/2" compares a deck with notes.

A binary runs an installed release of the same version, as "Make a binary" tells. Run
`<binary> maintenance uninstall` before you look at the notes of a new binary by hand.

## The dependency test

The test of `test/dependency/` makes a Mix project in `_build/dependency_project`.
The project takes Expresso as a dev dependency from the path of the repository, as
`docs/how-to/render-a-deck-in-your-project.md` tells a user to do from GitHub. The test
runs `mix deps.get`, then `mix expresso` on a deck of the project with the `root` option.

```sh
mix test --only dependency
```

`mix test` excludes this test, because it needs the network for the dependencies of the
project. The test uses the code of the working tree, so it finds a change that breaks
Expresso as a dependency before a merge.

The project is in `_build/dependency_project`, and the test keeps it. The project gets
`mix.lock` of Expresso, so its dependencies have the same versions. The first run compiles
each dependency and takes approximately 200 seconds. A later run compiles only the files
that changed, and takes approximately 10 seconds. A change to an element struct compiles
`lib/expresso/extension.ex` again, and that takes approximately 10 seconds. The job
`dependency` of the workflow has its own cache, which keeps the project. To start from a
new project, remove the directory:

```sh
rm -rf _build/dependency_project
```

## The release tests

The tests of `test/release/` run the binary that Burrito makes, as a user does. They read
the exit status, the standard output and the output file. They find the defects that the
unit tests cannot find, because those tests do not start a binary.

```sh
BURRITO_TARGET=linux_x86 MIX_ENV=prod mix release expresso_cli_app --overwrite
EXPRESSO_BINARY=burrito_out/expresso_cli_app_linux_x86 mix test --only release
```

`mix test` excludes these tests, because they need the binary, and the binary needs Zig.
`EXPRESSO_BINARY` gives the path of the binary. `BURRITO_TARGET` makes one binary and not
four, so the build takes less time. On a Mac, use the target `macos_arm` or `macos_x86`,
and the binary of that target. `mix check` finds the target of the computer. `--overwrite`
replaces an earlier release, because `mix release` otherwise asks a question.

In a remote session, the first build takes approximately five minutes, and a build after it
takes approximately one minute. The tests take less than 15 seconds.

The tests run the binary with `timeout` from GNU coreutils. A binary that does not halt then
gives the exit status 124, and the run of the tests does not stop. Linux gives `timeout`,
and `shell.nix` gives coreutils, also on macOS. Homebrew gives the command as `gtimeout`,
and the tests accept both names.

Two tests send SIGTERM to the launcher of Burrito, and they run the binary without
`timeout`. `timeout` sends a signal to each process in its group, so the VM also gets the
signal, and the tests then cannot find a VM that continues. The watch test uses `pgrep` to
find the VM. The `--check` test runs a deck that writes the process id of the VM to a file.
The two tests kill the launcher and the VM after the test.

Burrito puts a precompiled ERTS in the binary, and it downloads the ERTS for the exact OTP
version of the computer. Its source is `https://beam-machine-universal.b-cdn.net`. For Linux
on x86_64, the file is `OTP-<v>/linux/x86_64/any/otp_<v>_linux_any_x86_64.tar.gz`. On
2026-09-27, the source had OTP 29.0.5 and 29.1 for Linux and macOS, and it did not have
29.1.1. For an OTP version with no ERTS, `mix release` gets a 404. The pin of `flake.nix`
and `version-type: strict` of the workflow keep OTP at 29.1.

A binary installs its release in a directory that has the name and the version of the
release. When that directory is present, the binary does not install the release again.
Therefore a new binary of the same version runs the release of an earlier binary. The tests
give the binary a new home directory for each run, so they always test the new release.

To run a new binary by hand, make it without `MIX_ENV=prod`. Use the target of your
computer:

```sh
BURRITO_TARGET=linux_x86 mix release expresso_cli_app --overwrite
```

Burrito uses an installed release again only in a binary of the environment `prod`. See
`is_prod` in `deps/burrito/lib/steps/build/pack_and_build.ex`. A binary of a different
environment installs its release at each start, so it always runs the new code. On a remote
container, this start took approximately 7 seconds, and the start of an installed release
took approximately 0.3 seconds. The binary also writes many lines that start with `debug:`
to the standard error, and the standard output holds only the output of Expresso.

The launcher of Burrito starts the VM with `-s elixir start_cli`. After the boot, the CLI of
Elixir runs the first argument as a script, and then it halts the VM.
`Expresso.BurritoEntryPoint` runs the command in `start/2`, and it halts the VM before the
CLI of Elixir starts.

Before 2026-09-26, the entry point rendered the deck in a task, and it did not wait for it.
The CLI of Elixir then ran each deck a second time, and it gave the exit status. A deck that
took a long time to render gave no file and the exit status 0. The tests of `test/release/`
find this defect.
