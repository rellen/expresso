# The workflow

This page describes the workflow that checks a pull request on GitHub, and how its jobs get Zig.

## The checks of a pull request

`.github/workflows/check.yml` runs the checks for a pull request and for a push to `main`.
The jobs run in parallel on Linux, so the slowest of them gives their time:

- `format`: the formatter.
- `lint`: the compiler with warnings as errors, Credo, Sobelow, `mix hex.audit`, the check
  of unused dependencies, `mix docs`, Doctor and Dialyzer.
- `test`: the unit tests, in two jobs, `test (1/2)` and `test (2/2)`.
- `e2e`: the browser tests, in three jobs, `e2e (1/3)` to `e2e (3/3)`.
- `graph`: the tests that run a tool that draws a graph. This job, the jobs of `e2e` and
  the job `gifs` install Graphviz and D2 with `.github/actions/setup-graph-tools`. See
  `graph-tools.md`.
- `dependency`: the dependency test.
- `presenter`: `npm run check`, `npm run lint`, `npm run format:check` and `npm test`.
- `gifs`: `mix expresso.gifs`, the GIFs and the stills of the example decks. The artifact
  `gifs` holds them.
- `binary`: the binary for Linux and the release tests, in two jobs. The job
  `binary (linux_x86)` runs on x86_64, and the job `binary (linux_arm)` runs on an arm64
  runner. Each job makes the binary for its own architecture, so it can run the binary.
  Neither job publishes the binary. `.github/actions/setup-zig` installs Zig, as "Zig in
  the workflow" below tells.

Together they run each tool of `mix check`, with the four npm commands, the browser tests,
the tests of the graph tools and the release tests. They make and test the binary for `linux_x86` and `linux_arm`. No job
makes a binary for macOS.

The jobs do not run `mix check`, because that command runs the tools one after the other
in one job.

No job runs on macOS. A macOS runner costs more than a Linux runner, and most defects also
show on Linux. To find a defect of the Mac, run `mix check` on a Mac. Until 2026-10-05, the
job `macos` ran the compiler, the unit tests, the browser tests, the binary for
`macos_arm` and the release tests on macOS.

A job compiles the project for one environment. Therefore the tools that need the same
build share one job, and the project compiles two times for the development environment,
in `lint` and in `gifs`. It compiles for the test environment in each job of `test`, `e2e`,
`graph` and `dependency`, and in the two `binary` jobs. It compiles two times for the production
environment, in the two `binary` jobs. A step of `lint` or of `presenter` runs also when a
step before it fails, so one run reports each defect.

The jobs of `test`, `e2e` and `graph` share the cache `test`. Each job reads the build
of the commit before, and compiles only the files that changed. The first job to finish
saves the build of its commit. A build job that the other jobs wait for adds its setup and
the save of the cache to the time of each run, so the workflow has no such job.

`mix test --partitions` gives each test file to one partition, and `MIX_TEST_PARTITION`
selects the partition of a job. To run the tests of one job on your machine, give the same
values:

```sh
MIX_TEST_PARTITION=2 mix test --only e2e --partitions 3
```

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
`media`, and [Record the GIFs and the stills of the examples](gifs.md) gives the details. `pages`
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

The workflow keeps `deps` and `_build` in a cache. The key holds the name of the cache of
the job, `mix.lock`, the two versions and the commit. Therefore each run saves the build
of its commit, and the next run compiles only the files that changed after it. A run with
no cache of its commit reads the latest cache of the same `mix.lock`, and then the latest
cache of the same name. Each job has a cache of its own name, except the jobs of `test`
and `e2e`, which share the cache `test`. A job that compiles nothing, such as `format`,
must not give the other jobs a cache with no build. For a result from a full
compile, run `mix compile --warnings-as-errors --force` on your machine.

Dialyzer comes with the Erlang archive of `builds.hex.pm`, and an apt package is not
necessary. The first `mix dialyzer` builds a PLT of approximately 570 modules, and this
operation takes approximately two minutes. The PLT stays in `_build`, so each
`mix dialyzer` after the first takes a few seconds. Dialyzer reports no error at this time.

## Zig in the workflow

The jobs `lint`, `test`, `e2e`, `dependency`, `gifs` and `binary` get Zig from
`.github/actions/setup-zig`. The jobs before `binary` compile the GIF encoder of `tools/`,
and the `binary` jobs also make the binary. This action uses
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

The key of the build cache holds the name of the cache of the job and `mix.lock`, and a job saves the
build cache only when no cache has its key. Therefore each job saves it one time for each
version of the lockfile. A job that does not make the binary has its own key, so its cache
does not take the place of a cache with the wrapper of Burrito. Only the `binary` jobs keep
the download cache of Burrito.
Until 2026-09-28, the key held the number of the run, so each run saved the build cache.
Each build adds its payload to the cache, and one run saved 405 MB for `linux_x86` and
234 MB for `macos_arm`. The build of the wrapper changes only with Burrito, so one save
keeps most of the gain.

On a Linux runner, the action sets `TARGET_ARCH`, `TARGET_OS` and `TARGET_ABI`. Zigler
then compiles the NIF of `tools/` for the baseline CPU of the architecture, and not for the
CPU of the runner. The cache of `_build` gives the NIF to the next runner, and that runner
can have a different CPU. On 2026-10-01, a NIF with AVX-512 instructions stopped a runner
without AVX-512 with `Illegal instruction`. The key of the cache of `deps` and `_build`
starts with `mix-baseline`, so no job reads a cache from before this change. Burrito does
not read these variables, and a macOS runner and your computer keep their own CPU.

Burrito downloads the ERTS of the target from the CDN `beam-machine-universal.b-cdn.net`,
and on Linux also a musl runtime. It keeps them in its own download cache:
`~/.cache/burrito_file_cache` on Linux and `~/Library/Caches/burrito_file_cache` on macOS.
The action also keeps this directory in the cache of GitHub, with a key that holds the
version of Erlang and `mix.lock`. Therefore a run with a hit downloads nothing, and a
problem with the CDN cannot stop that run. The action asks Erlang for the path, so a job
runs `.github/actions/setup-elixir` first.
