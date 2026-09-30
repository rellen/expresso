# Development

This document tells you how to get a toolchain, how to run the checks and how to look at a
deck in a browser.

## The toolchain

The versions are in `.tool-versions`: Elixir 1.20.4, Erlang/OTP 29.1, Node 24.20.0 and
Zig 0.16.0. Burrito needs Zig for the binary, and no other command needs it.

Four places give a toolchain, and each place gives these versions:

- `flake.nix` and `shell.nix`, which the Nix shell reads on your machine.
- `.tool-versions`, which asdf and mise read.
- `.claude/hooks/session-start.sh`, which a remote Claude Code session runs.
- `.github/workflows/check.yml`, which GitHub runs for a pull request.

Therefore each command gives the same result in each place. After a change to one place,
change the other three.

### On your machine

Use the Nix shell. It gives each tool, and it gives Zig for a Burrito release.

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
2. Make sure that Burrito has an ERTS for its OTP version. "The release tests" below gives
   the reason.
3. Put the commit in `flake.nix`, and run `nix flake lock`.

### In a Claude Code session on the web

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
   A failure gives a warning, and the hook continues, because only the binary needs Zig.
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
use Burrito". The Zig build takes approximately 400 MB of disk. "The release tests" below
gives the commands that make the binary and test it.

To run the hook again by hand:

```sh
CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR="$PWD" ./.claude/hooks/session-start.sh
```

## The checks

```sh
mix check                      # each tool below, Dialyzer, Doctor, ex_doc and unused_deps
mix compile --warnings-as-errors
mix format --check-formatted
mix credo
mix sobelow --exit --skip
mix hex.audit                  # the advisories and the retirements of the dependencies
mix test
mix test --only e2e            # the browser tests, see "The browser tests"
mix test --only release        # the tests of the binary, see "The release tests"
```

Each command above passes, and `mix check` passes as a whole. `mix doctor` passes with a
doc coverage, a spec coverage and a moduledoc coverage of 100 percent. Doctor reads the
source and not the compiled modules, so the functions that `use Spark.Dsl` and
`use Temple.Component` write do not count. Each public function that you write needs a
`@doc` and a `@spec`, and each struct needs a `@type t`.

Each result above comes from Erlang/OTP 29.1, Elixir 1.20.4 and Zig 0.16.0, which
`.tool-versions` gives. The Nix shell, a remote session and the workflow each give these
versions. Therefore a check that passes in a session also passes on your machine and in the
workflow.

`mix check` also runs the browser tests and the release tests. Before the release tests,
it makes the binary for the target of the computer: `macos_arm`, `macos_x86`, `linux_x86`
or `linux_arm`. `.check.exs` finds the target. Therefore `mix check` needs Node, the
Chromium of Playwright, Zig, `xz` and `timeout`. It does not run the two `npm` commands.

The browser tests start after the unit tests, and the release tests start after the
browser tests and a release that succeeded. `.check.exs` gives `retry: false`, so each run
of `mix check` runs each tool. In the retry mode, a run after a failure runs only the
failed tools. A failed tool with a dependency that does not run is then skipped, and a
skipped tool does not fail the run.

### Property tests

`stream_data` gives the property tests. Put `use ExUnitProperties` in the test module, and
then write `property` in place of `test`. `test/expresso/image_element_test.exs` gives an
example. It makes a random width, and it compares the result against the rule.

`test/support` holds the generators, and `mix.exs` compiles this directory in the test
environment only. `Expresso.Test.CSS` makes a value of the CSS `width` property: a length
in each unit of CSS Values and Units 4, a percentage, a keyword, a custom property and a
math function such as `calc`, `min`, `max` and `clamp`. The module makes the text of the
value, because the DSL holds a width as a string. `Expresso.Test.Overlay` makes an overlay
specification of each form of `docs/overlays.md`, and a term that `Expresso.Overlay.new/1`
refuses.

A property that fails gives the smallest value that it found, and the seed of the run. Run
`mix test --seed <seed> <file>:<line>` to get the same values again.

`config/config.exs` gives each property 500 runs. The generators make many forms, and the
default of 100 runs does not reach enough of them.

The dependency is present in `dev` and in `test`. `mix format` runs in `dev`, and it reads
`deps/stream_data/.formatter.exs` through `import_deps`. Therefore the formatter writes no
parentheses after `check all`.

### The browser tests

The tests of `test/e2e/` render a deck to an HTML file, open the file in Chromium, and
operate the presenter as a user does. They press keys, click, tap, swipe, read computed
styles, reload the page, open the speaker view in a second window, and count the pages of a
PDF. Playwright has no swipe, so a script in the page sends the touch events. They find the
defects that the unit tests of `assets/test/` cannot find, because those tests use no CSS
and no browser.

```sh
mix test --only e2e
```

`mix test` excludes these tests, because they need Node, the Playwright driver and a
browser. `playwright_ex` is the Elixir client, and it starts the driver of
`node_modules/playwright`, which `package.json` pins. `Expresso.E2E` in `test/support/`
is the case template. It starts one browser for each module and a new context for each
test, and it gives the helpers, such as `press/2`, `position/1` and `pdf_pages/1`.

The variable `EXPRESSO_CHROMIUM` gives the path of a Chromium executable. A remote session
has no browser at the path of Playwright, so the hook sets the variable to the Chromium
of the container. Without the variable, Playwright uses its own browser:

```sh
npx playwright install --only-shell chromium
```

The workflow runs the same command in `.github/actions/setup-playwright`, and a cache
keeps the browser from one run to the next. The runner image already has each system
library of the headless browser, so the workflow does not use `--with-deps`.

### The release tests

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

### The checks of a pull request

`.github/workflows/check.yml` runs the checks for a pull request and for a push to `main`.
The Linux jobs run in parallel, so the slowest of them gives their time:

- `format`: the formatter.
- `lint`: the compiler with warnings as errors, Credo, Sobelow, `mix hex.audit`, the check
  of unused dependencies, `mix docs`, Doctor and Dialyzer.
- `test`: the unit tests and the browser tests.
- `presenter`: `npm run check` and `npm test`.
- `binary`: the binary for Linux and the release tests, in two jobs. The job
  `binary (linux_x86)` runs on x86_64, and the job `binary (linux_arm)` runs on an arm64
  runner. Each job makes the binary for its own architecture, so it can run the binary.
  Neither job publishes the binary. `.github/actions/setup-zig` installs Zig, as "Zig in
  the workflow" below tells.
- `macos`: five tools of `mix check` on an arm64 runner with macOS. It makes the binary for
  `macos_arm`. Homebrew gives `xz`, and the Homebrew package of GNU coreutils gives
  `gtimeout`. The job starts only when each Linux job succeeded.

Together they run each tool of `mix check`, the two npm commands, the browser tests and
the release tests. They make and test the binary for `linux_x86`, `linux_arm` and
`macos_arm`. No job makes the binary for `macos_x86`.

The Linux jobs do not run `mix check`, because that command runs the tools one after the
other in one job. The job `macos` runs only the tools that can give a different result on a
Mac:

```sh
mix check --only compiler --only ex_unit --only e2e --only release --only release_tests
```

The Linux jobs already ran the other tools, such as Credo and Dialyzer, and their result
does not depend on the platform. Therefore the workflow does not show that each tool of
`mix check` runs on a Mac. Run `mix check` on a Mac to find that out.

The job `macos` needs each Linux job. A macOS runner costs more than a Linux runner, and
most defects also show on Linux. Therefore `macos` starts only when each Linux job
succeeded. When a Linux job fails, GitHub skips `macos`, and the last job fails. The time
of the workflow is the time of the slowest Linux job, plus the time of `macos`.

A job compiles the project for one environment. Therefore the tools that need the same
build share one job, and the project compiles two times for the development environment,
in `lint` and in `gifs`. It compiles three times for the test environment, in `test` and in
the two `binary` jobs, and two times for the production environment, in the two `binary`
jobs. A step of `lint` or of `test` runs also when a step before it fails, so one run
reports each defect.

`lint` also runs Dialyzer, because Dialyzer needs the same build. The cache of `lint` holds
the PLT. With the PLT, Dialyzer takes approximately 30 seconds, and `lint` still finishes
before the slowest Linux job. Until 2026-09-28, Dialyzer had its own job, which compiled
the project again for the development environment.

Each Elixir job uses `.github/actions/setup-elixir`, which installs the versions of
`.tool-versions`, reads the cache and gets the dependencies. One set of versions is
sufficient, because each place gives these versions.

The last job, `Erlang/OTP 29, Elixir 1.20, Node 24`, needs each other job. It fails when
one of them fails, is cancelled or is skipped. It has the name of the one job of the earlier
workflow.

After a push to `main`, two more jobs run. `media` puts the GIFs of the guides on the branch
`media`, and "Record the GIFs and the stills of the examples" gives the details. `pages`
puts the site of `mix docs` on GitHub Pages, at https://rellen.github.io/expresso/. The job
`lint` makes the site, and it uploads the directory `doc/` when each of its steps succeeded.
Therefore the site and the checks come from one build. The site is public, as the repository
is. GitHub gives a private site to an organization on GitHub Enterprise Cloud only.

`media` and `pages` need the last job, so they start only when each check succeeded. A push
to `main` with a failed check keeps the old GIFs and the old site. The site shows the GIFs
of the branch `media`, so the two stay in agreement. A new push to `main` cancels the run
of the push before it, and then only the new run changes the GIFs and the site.

The repository must have Pages on, with GitHub Actions as the source. Turn it on in the
settings of the repository, under "Pages". The token of a workflow cannot turn it on: the
first run of `pages` tried, and GitHub refused with "Resource not accessible by
integration". A run of `pages` without the site fails at `configure-pages`.

From 2026-09-17 to 2026-09-18 the workflow ran two jobs, one for the versions of the
container and one for the versions of `.tool-versions`. The container then took the
versions of `.tool-versions`, and the second job became the same as the first.

GitHub does not make a job necessary by itself. Add a branch protection rule for `main`
with the last job, or a pull request with a failure can still merge. A rule with that name
from the earlier workflow still covers each check.

The workflow holds each version in one `env` block, because no action reads
`.tool-versions`. Keep the workflow and `.tool-versions` in agreement.

`.github/actions/setup-elixir` gives `setup-beam` the option `version-type: strict`, so
the action installs each version as it is. Without the option, the action read 29.1 as the
latest 29.1.x. After the release of OTP 29.1.1 on 2026-09-22, the jobs then ran on 29.1.1,
and each other place gave 29.1. Burrito found no ERTS for 29.1.1, and the job `release`,
now `binary`, failed.

The workflow keeps `deps` and `_build` in a cache for each job. The key holds the name of
the job, `mix.lock`, the two versions and the commit. Therefore each run saves the build
of its commit, and the next run compiles only the files that changed after it. A run with
no cache of its commit reads the latest cache of the same `mix.lock`, and then the latest
cache of the job. Each job has its own cache, because a job that compiles nothing, such as
`format`, must not give the other jobs a cache with no build. For a result from a full
compile, run `mix compile --warnings-as-errors --force` on your machine.

Dialyzer comes with the Erlang archive of `builds.hex.pm`, and an apt package is not
necessary. The first `mix dialyzer` builds a PLT of approximately 570 modules, and this
operation takes approximately two minutes. The PLT stays in `_build`, so each
`mix dialyzer` after the first takes a few seconds. Dialyzer reports no error at this time.

### The audit of the dependencies

`mix hex.audit` fails for a dependency with a security advisory or a retirement on Hex.
Hex 2.5 added the advisories to this task, and they come from the same source as the
warnings of `mix deps.get`. The job `lint` runs it for each pull request.

Hex can publish an advisory after a merge. Therefore `.github/workflows/audit.yml` also
runs `mix hex.audit` on `main` each day, at 08:07 UTC. GitHub sends an email for a failed
scheduled run to the person who last changed the schedule. The workflow reads the versions
of Erlang and Elixir from `.tool-versions`, so it adds no place for a version.

Until September 2026, the project used `mix deps.audit` from the package `mix_audit`. Its
advisory source did not contain each advisory. Two times in that month, `mix deps.get`
reported advisories for mint, and `mix deps.audit` gave "No vulnerabilities found" for the
same lockfile. `mix hex.audit` reported the second group, so the project removed
`mix_audit`.

For an advisory, do these steps:

1. Read the advisory, and find the fixed version on its page.
2. Update the dependency with `mix deps.update <name>`, and run the checks.
3. If no fixed version exists, or the advisory does not apply, add its ID to
   `hex: [ignore_advisories: [...]]` in `project/0` of `mix.exs`. Give the reason in a
   comment. `mix help hex.audit` gives the form.

The job `lint` and the daily workflow use `mix deps.get --check-locked`. It fails when
`mix.lock` does not agree with `mix.exs`. Run `mix deps.get` on your machine, and commit
the new lockfile.

### Zig in the workflow

The jobs `binary` and `macos` get Zig from `.github/actions/setup-zig`. This action uses
the shell and `actions/cache`, and it has no code of its own for Node.js. The jobs used
`mlugg/setup-zig` before. Its last release, v2.2.1 of 2026-01-19, targets Node.js 20, and
GitHub gave a warning for each job that used it.

`.github/actions/setup-zig/install.sh` does these steps:

1. Get the list of the community mirrors from ziglang.org. When ziglang.org does not
   answer, use the copy of the list in the script.
2. Try the mirrors in a random order. The Zig project asks automated systems to use the
   mirrors, and the random order divides the requests between them. When a mirror gives
   less than 500 KB/s for 20 seconds, try the next mirror.
3. Make sure that the SHA-256 of the archive agrees with the sum in the script. When a
   mirror gives a different archive, try the next mirror.
4. Try ziglang.org only when each mirror fails. This download has no speed limit.

In the first run of the workflow, one mirror took 5 minutes for the 55 MB of Zig, before
the speed limit. Another mirror took 21 seconds.

The script holds the SHA-256 of Zig 0.16.0 for Linux and macOS, on x86_64 and on aarch64.
After a change to the version of Zig, add the new sums from
https://ziglang.org/download/index.json. Without them, the job stops with a message. The
script also runs on a Linux or macOS computer:
`.github/actions/setup-zig/install.sh 0.16.0 /tmp/zig`.

The cache of GitHub keeps the installed Zig, so a run with a hit downloads nothing. It also
keeps the build cache of Zig. In this container, the build of the binary took 142 seconds
with an empty build cache, and 47 seconds with the cache of an earlier build. A build cache
of more than 1 GB goes, and the job starts a new one.

The key of the build cache holds `mix.lock`, and a job saves the build cache only when no
cache has its key. Therefore the jobs save it one time for each version of the lockfile.
Until 2026-09-28, the key held the number of the run, so each run saved the build cache.
Each build adds its payload to the cache, and one run saved 405 MB for `linux_x86` and
234 MB for `macos_arm`. The build of the wrapper changes only with Burrito, so one save
keeps most of the gain.

Burrito downloads the ERTS of the target from the CDN `beam-machine-universal.b-cdn.net`,
and on Linux also a musl runtime. It keeps them in its own download cache:
`~/.cache/burrito_file_cache` on Linux and `~/Library/Caches/burrito_file_cache` on macOS.
The action also keeps this directory in the cache of GitHub, with a key that holds the
version of Erlang and `mix.lock`. Therefore a run with a hit downloads nothing, and a
problem with the CDN cannot stop that run. The action asks Erlang for the path, so a job
runs `.github/actions/setup-elixir` first.

## Dependency updates

`.github/dependabot.yml` tells Dependabot to open pull requests each week for three kinds
of dependency:

- The GitHub Actions of `.github/workflows/` and `.github/actions/`. One pull request
  holds each new version.
- The packages of `package.json`. One pull request holds the minor and the patch versions,
  and each major version gets its own pull request.
- The packages of `mix.exs` and `mix.lock`, with the same groups as npm.

Each commit message obeys Conventional Commits. The prefix is `ci:` for an action, and
`build(deps):` or `build(deps-dev):` for a package.

Dependabot does not open a major version of `@types/node`. That version follows the
Node.js of `.tool-versions`, and a change of the toolchain changes its four places
together. Dependabot does not change the toolchain.

The workflow runs each check for a pull request of Dependabot, as for each pull request.
Read the breaking changes of a major version before a merge. A new version of Playwright
also needs a new browser. The workflow installs it. A session with `EXPRESSO_CHROMIUM` uses
the Chromium of the container, and that Chromium can be older than the new version needs.

## The presenter script

`docs/typescript.md` gives the design. The parts are:

- `assets/src/program.ts` — reads the program of the presenter that the renderer writes.
- `assets/src/interpreter.ts` — runs the program for each key, click and swipe.
- `assets/src/state.ts` — the state of the presenter, the messages between the windows,
  the side of a click and the direction of a swipe.
- `assets/src/dom.ts` — the code that reads the document and writes to it.
- `assets/src/main.ts` — the entry, which esbuild bundles.
- `assets/test/interpreter.test.ts` — the test that runs the fixtures of the Elixir
  interpreter. "The fixtures of the interpreter" below tells how to write them again.
- `assets/test/state.test.ts` — the example tests of the state.
- `assets/test/state_property.test.ts` and `assets/test/speaker_property.test.ts` — the
  property tests of the state and of the speaker view texts.
- `assets/test/property.ts` — `RUNS`, the number of runs of each property.
- `assets/test/nth.ts` — the item at an index, for the tests.
- `assets/tsconfig.json` — the options of the type check.
- `package.json` — the tools, with a pinned version of each.
- `config/config.exs` — the esbuild profile.
- `Mix.Tasks.Compile.Presenter` in `mix.exs` — the compiler that makes the bundle.

`mix compile` makes `priv/static/presenter.js` with esbuild, in front of the Elixir
compiler. The first `mix compile` downloads the esbuild binary from the npm registry, and
the download passes the proxy of the remote container. Git does not hold the bundle. A
content change to a source makes a new bundle and a new compile of `Expresso.Renderer`.

The commands are:

```sh
npm install      # the hook runs this command in a remote session
npm run check    # tsc, the type check
npm test         # node --test, which runs a .ts file directly
npm run format   # prettier
```

`fast-check` gives the property tests. It is a development dependency, and the bundle does
not import it. "Property tests" above tells how `stream_data` does the same for the Elixir
code. Each property of the presenter script gets `RUNS`, which is 500, as
`config/config.exs` gives each property of `stream_data`. The generators make many forms,
such as a state after 0 to 60 keys, clicks and messages, and 100 runs do not reach enough of
them.

When a property fails, `fast-check` gives a `seed` and a `path`. Give both to `fc.assert`
as parameters to get the same value again.

Node runs the test files with no build step. Node 24 reads a `.ts` file
directly when the file uses only erasable syntax, and `erasableSyntaxOnly` in
`tsconfig.json` makes the compiler refuse other syntax.

`assets/tsconfig.json` has more options than the plan of `docs/typescript.md` gives.
`isolatedModules` and `verbatimModuleSyntax` refuse syntax that esbuild cannot compile one
file at a time. These options refuse code that is unused, unreachable or incomplete:

- `noImplicitReturns`
- `noFallthroughCasesInSwitch`
- `noUnusedLocals`
- `noUnusedParameters`
- `allowUnreachableCode: false`
- `allowUnusedLabels: false`

`noUncheckedIndexedAccess` gives each index access the type `T | undefined`. A test uses
`nth` of `assets/test/nth.ts`, which stops the test for a missing item.
`exactOptionalPropertyTypes` refuses `undefined` for an optional property. The options do
not change the bundle.

### The fixtures of the interpreter

The TypeScript interpreter must return the result of the Elixir interpreter for each
event. Node cannot run Elixir, so Git holds the results of the Elixir interpreter in
`assets/test/fixtures/presenter.json`. `interpreter.test.ts` runs the same events, and it
compares each result. The tests of `main.ts` also read the programs and the lists of keys
from this file.

`Expresso.Test.PresenterFixtures` makes the file. Its test in
`test/expresso/presenter/fixtures_test.exs` fails when the file does not agree with the
text that `json/0` returns. After a change to `Expresso.Presenter.Default` or to an
interpreter, do these steps:

1. Write the file again:

   ```sh
   EXPRESSO_FIXTURES=write mix test test/expresso/presenter/fixtures_test.exs
   ```

2. Run `npm test`.
3. Commit the file with the change.

Prettier does not format the file, because `.prettierignore` holds its directory. The file
has one line for each deck and for each case, so a diff shows each changed case.

A call of a DSL has no parentheses. Expresso has two DSLs: the deck DSL of
`Expresso.Extension` and the presenter DSL of `Expresso.Presenter.Extension`.
`.formatter.exs` holds the list `spark_locals_without_parens`, and `mix format` then adds
no parentheses. After a change to an entity or an option of a DSL, run this command to make
the list again:

```sh
mix spark.formatter --extensions Expresso.Extension,Expresso.Presenter.Extension
```

The task needs the `sourceror` package, which is a development dependency. The formatter removes no parentheses, so write a new call without them.

Sobelow gives a warning for `Phoenix.HTML.raw/1`. When the input is safe, put a
`# sobelow_skip` comment above the function, with the reason in a comment above it.
`Expresso.Renderer.render/1` and `Expresso.Element.Diagram.render/1` show this pattern.

Prettier formats the files in `assets/`. `package.json` pins the version, and
`npm install` gives the command. Run `npm run format`, which is not one of the checks.

## Record the GIFs and the stills of the examples

The how-to guides and the reference pages show a GIF of each example deck of
`examples/animations/`. "Present a deck" in `README.md` shows a GIF or a still of each
example deck of `examples/presenter/`. `mix expresso.gifs` records them:

```sh
mix expresso.gifs                        # each example, into _build/gifs
mix expresso.gifs /tmp/gifs overlay-at   # one example, into /tmp/gifs
```

The task renders each example deck to an HTML file. It then runs the recorder
`assets/gifs/record.ts` with Node, and it gives the recorder a manifest with the HTML file,
the address and the actions of each example. `npm run gifs -- <manifest> <output>` runs
only the recorder. The list of the examples is in `Mix.Tasks.Expresso.Gifs`. An example
has:

- a name, which gives the name of the file;
- a deck file;
- an address after the path of the HTML file, such as `?speaker#2.1`, for a view or a
  position;
- actions, which are keys, or a move of the clock of the page, such as
  `{:advance, 90_000}`, for the timer of the speaker view;
- `still: true` for a PNG of the page after the actions, in place of a GIF;
- a height of the picture, in the layout of a window of 1280 by 720 pixels, so a still of
  the handout view can show several pages.

The recorder opens each document in Chromium, does the actions, and takes a screenshot of
each frame. After a key, it pauses each animation of the page, and it moves the animations
to the time of each frame. The clock of the page is fixed, and a move of the clock sets it
to a later time. The frames therefore do not depend on the speed or the time of the
computer. The recorder encodes the frames with `gifenc`, a JavaScript package, so it needs
no program such as ffmpeg. A still is the last frame, as a PNG.

The job `gifs` of the workflow records the files for each pull request, and the artifact
`gifs` holds them. After a push to main, the job `media` replaces the branch `media` with
one commit of the new files, when each check succeeded. The guides and the README show each
file from that branch, so the history of main holds no GIF.

To add an example of a guide, write a deck in `examples/animations/`, and add it with its
keys to the list of the task. Then show its code and its GIF in a guide. To add an example
of the README, write a deck in `examples/presenter/`, or use one of the decks there, and
add the example to the list. Then show its file in the README.
`test/expresso/examples_test.exs` makes sure that a how-to guide shows the code of each
deck of the guides as it is in the file, that the guides show each of their files, and
that the README shows each of its files.

## Look at a deck

Make an HTML document, and then open it. `examples/demo.exs` uses the functions, and
`examples/dsl_deck.exs` uses the DSL:

```sh
mix expresso examples/demo.exs /tmp/demo.html
mix expresso examples/dsl_deck.exs /tmp/dsl.html
```

With `--watch`, the task renders the deck again after each change, and the page reloads.
Open `http://127.0.0.1:4100/`:

```sh
mix expresso examples/dsl_deck.exs --watch
```

The browser tests cover the behavior of the presenter. Add a test to `test/e2e/` for a
new behavior. A look at the slides is still necessary after a change to
`assets/style.css`, because no test reads the layout. A remote container has no display,
but it has Chromium, and `npm install` gives Playwright. The browser is at
`/opt/pw-browsers/chromium`. This path is not the default path of Playwright, so give it
to `chromium.launch`.

```js
import { chromium } from "playwright";

const browser = await chromium.launch({
  executablePath: "/opt/pw-browsers/chromium",
});
const page = await browser.newPage({ viewport: { width: 1000, height: 620 } });
await page.goto("file:///tmp/demo.html");

// Make sure that the result comes from the standards mode. In the quirks mode
// a percentage height gives a different layout, and the defect is not visible.
console.log(await page.evaluate(() => document.compatMode)); // "CSS1Compat"

// The presenter reads the keys j, k and p.
await page.keyboard.press("j");

// Read the computed style, because an error in a style attribute is silent.
const visible = await page.$$eval("section.slide", (elements) =>
  elements
    .filter((element) => getComputedStyle(element).display !== "none")
    .map((element) => element.id),
);
console.log(visible);

await page.screenshot({ path: "/tmp/slide.png" });
await browser.close();
```

Look at these cases after a change to the theme or to the presenter:

- A deck with no slide. Each key must give no error in the console.
- A word that is longer than the slide. The document must not become wider than the
  screen, and `document.documentElement.scrollWidth` gives that answer.
- A heading of many words, and a slide of many elements.
- A screen of 1440, 1024, 800 and 500 pixels.
- The print view, with `page.emulateMedia({ media: "print" })`, on A4 and on letter.

The theme gives `html` a font size of 48 pixels, and that size does not change with the
screen. Therefore the content of a slide can be taller than the slide on a screen of 800
pixels or less. A theme with a font size in a viewport unit does not have this limit, and
that change alters each deck.

Read the computed style, and do not read the attribute. A defect in a style attribute gives
no error. The browser drops the declaration, and the page looks almost correct.

## Documents

`mix docs` makes the site of the documents in `doc/`, and https://rellen.github.io/expresso/
shows the site of the last push to `main`. `mix.exs` gives ExDoc the list of the documents
and their groups.

- `docs/architecture.md` — how the code makes an HTML document from a deck.
- `docs/overlays.md` — the design for overlays, and its decisions.
