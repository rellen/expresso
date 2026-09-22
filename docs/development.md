# Development

This document tells you how to get a toolchain, how to run the checks and how to look at a
deck in a browser.

## The toolchain

The versions are in `.tool-versions`: Elixir 1.20.4, Erlang/OTP 29.1 and Node 24.20.0.

Four places give a toolchain, and each place gives these versions:

- `shell.nix`, which the Nix shell reads on your machine.
- `.tool-versions`, which asdf and mise read.
- `.claude/hooks/session-start.sh`, which a remote Claude Code session runs.
- `.github/workflows/check.yml`, which GitHub runs for a pull request.

Therefore each command gives the same result in each place. After a change to one place,
change the other three.

### On your machine

Use the Nix shell. It gives each tool, and it gives Zig for a Burrito release.

```sh
nix flake update # nixpkgs follows master, and the lockfile can be old
nix develop      # or: direnv allow, after you copy .envrc.example to .envrc
mix deps.get
```

`flake.nix` follows `nixpkgs` master, and `flake.lock` holds one commit of master.
Therefore `nix develop` gives the versions of that commit, and not always the versions of
`.tool-versions`. Run `nix flake update` to get the newest commit. On 2026-09-18, master
gave Erlang/OTP 29.1, Elixir 1.20.4 and Node 24.20.0, which are the versions of
`.tool-versions`.

### In a Claude Code session on the web

A remote container has no Elixir, and it has no Nix. The hook
`.claude/hooks/session-start.sh` installs a toolchain at the start of each remote session.
The hook does nothing on your machine, where the Nix shell gives the tools.

The hook does these operations:

1. Download the Erlang build for Ubuntu 24.04 from `builds.hex.pm`, and put it in
   `/opt/otp`. The archive holds dialyzer, which `mix check` needs. `setup-beam` reads the
   same builds in the workflow.
2. Download the Elixir build for OTP 29 from `builds.hex.pm`, and put it in `/opt/elixir`.
3. Download the Node build from `nodejs.org`, and put it in `/opt/node`.
4. Write `PATH`, `ELIXIR_ERL_OPTIONS` and `LANG` into `$CLAUDE_ENV_FILE`.
5. `mix local.hex`, `mix local.rebar`, `mix deps.get`, `mix compile` and `npm install`.

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

The hook does not install Zig. Therefore `mix release expresso_cli_app` gives the error
"You MUST have `zig` and `xz` installed to use Burrito" in a remote container. Make a
release on your machine, where the Nix shell gives Zig 0.16.0.

One result of this limit is that `Expresso.BurritoEntryPoint` runs in a remote session
without a test. The module calls `Expresso.main/2` only when `Burrito.Util` reads the
environment variable `__BURRITO`, and the launcher of Burrito writes this variable. See
`deps/burrito/src/erlang_launcher.zig`. Make sure that a binary reads its arguments after
you change this module.

To run the hook again by hand:

```sh
CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR="$PWD" ./.claude/hooks/session-start.sh
```

## The checks

```sh
mix check                      # each tool below, and ex_doc and unused_deps
mix compile --warnings-as-errors
mix format --check-formatted
mix credo
mix sobelow --exit --skip
mix deps.audit
mix test
```

Each command above passes, and `mix check` passes as a whole. `mix doctor` passes with a
doc coverage, a spec coverage and a moduledoc coverage of 100 percent. Doctor reads the
source and not the compiled
modules, so the functions that `use Spark.Dsl` and `use Temple.Component` write do not
count. Each public function that a person writes needs a `@doc` and a `@spec`, and each
struct needs a `@type t`.

Each result above comes from Erlang/OTP 29.1 and Elixir 1.20.4, which `.tool-versions`
gives. The Nix shell, a remote session and the workflow each give these versions.
Therefore a result in a session is a result for each person and for the workflow.

### Property tests

`stream_data` gives the property tests. Put `use ExUnitProperties` in the test module, and
then write `property` in place of `test`. `test/expresso/image_element_test.exs` gives an
example. It makes a random width, and it compares the result against the rule.

`test/support` holds the generators, and `mix.exs` compiles this directory in the test
environment only. `Expresso.Test.CSS` makes a value of the CSS `width` property: a length
in each unit of CSS Values and Units 4, a percentage, a keyword, a custom property and a
math function such as `calc`, `min`, `max` and `clamp`. The module makes the text of the
value, because the DSL holds a width as a string.

`config/config.exs` gives each property 500 runs. The generators make many forms, and the
default of 100 runs does not reach enough of them.

The dependency is present in `dev` and in `test`. `mix format` runs in `dev`, and it reads
`deps/stream_data/.formatter.exs` through `import_deps`. Therefore the formatter writes no
parentheses after `check all`.

### The checks of a pull request

`.github/workflows/check.yml` runs `mix check`, `npm run check` and `npm test` for a pull
request and for a push to `main`. The job `Erlang/OTP 29, Elixir 1.20, Node 24` uses the
versions of `.tool-versions`, and one job is sufficient because each place gives these
versions.

From 2026-09-17 to 2026-09-18 the workflow ran two jobs, one for the versions of the
container and one for the versions of `.tool-versions`. The container then took the
versions of `.tool-versions`, and the second job became the same as the first.

GitHub does not make a job necessary by itself. Add a branch protection rule for `main`
with this job, or a pull request with a failure can still merge.

The workflow holds each version in one `env` block, because no action reads
`.tool-versions`. Keep the workflow and `.tool-versions` in agreement.

The workflow keeps `deps` and `_build` in a cache, and the key holds `mix.lock` and the
two versions. Therefore a change to `mix.lock` gives a new build. A run with a cache
compiles the files of the change only. For a result from a full compile, run
`mix compile --warnings-as-errors --force` on your machine.

Dialyzer comes with the Erlang archive of `builds.hex.pm`, and an apt package is not
necessary. The first `mix dialyzer` builds a PLT of approximately 570 modules, and this
operation takes approximately two minutes. The PLT stays in `_build`, so each
`mix dialyzer` after the first takes a few seconds. Dialyzer reports no error at this time.

`mix deps.audit` alone is not sufficient for a vulnerable dependency. It reads an advisory
source that does not contain each advisory.

In September 2026, Hex reported two advisories for mint 1.9.3 in the output of
`mix deps.get`. The advisories are EEF-CVE-2026-82728 and EEF-CVE-2026-82729.
`mix deps.audit` gave "No vulnerabilities found" for the same lockfile. A new copy of its
advisory source gave the same result. Therefore the source does not contain these
advisories, and the copy was not old.

Read the output of `mix deps.get` for a line that ends with `VULNERABLE!`. The session
start hook runs this command, so this line is in the output of the hook. Use both signals.

## The presenter script

`docs/typescript.md` gives the design. The parts are:

- `assets/src/state.ts` — the state of the presenter and the function that changes it.
- `assets/src/dom.ts` — the code that reads the document and writes to it.
- `assets/src/main.ts` — the entry, which esbuild bundles.
- `assets/test/state.test.ts` — the tests of the state.
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

Node runs the test files with no build step. Node 24 reads a `.ts` file
directly when the file uses only erasable syntax, and `erasableSyntaxOnly` in
`tsconfig.json` makes the compiler refuse other syntax.

A call of the DSL has no parentheses. `.formatter.exs` holds the list
`spark_locals_without_parens`, and `mix format` then adds none. After a change to an
entity or an option of the DSL, run `mix spark.formatter --extensions Expresso.Extension`
to make the list again. The task needs the `sourceror` package, which is a development
dependency. The formatter removes no parentheses, so write a new call without them.

Sobelow gives a warning for `Phoenix.HTML.raw/1`. Put a `# sobelow_skip` comment above the
function when the input is safe. `Expresso.main/2` and `Expresso.Renderer.render/1` show
this pattern.

Prettier formats the files in `assets/`. `package.json` pins the version, and
`npm install` gives the command. Run `npm run format`, which is not one of the checks.

## Look at a deck

Make an HTML document, and then open it. `examples/demo.exs` uses the functions, and
`examples/dsl_deck.exs` uses the DSL:

```sh
mix expresso examples/demo.exs /tmp/demo.html
mix expresso examples/dsl_deck.exs /tmp/dsl.html
```

A remote container has no display, but it has Chromium and Playwright. Use them to make
sure that a change to `assets/style.css`, or to the presenter in `assets/src/`, is
correct. The browser is at `/opt/pw-browsers/chromium-1194/chrome-linux/chrome`. This path
is not the default path of Playwright, so give it to `chromium.launch`.

```sh
npm install playwright     # with PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1
```

```js
import { chromium } from "playwright";

const browser = await chromium.launch({
  executablePath: "/opt/pw-browsers/chromium-1194/chrome-linux/chrome",
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

- `docs/architecture.md` — how the code makes an HTML document from a deck.
- `docs/overlays.md` — the design for overlays, and its open decisions.
