# Development

This document tells you how to get a toolchain, how to run the checks and how to look at a
deck in a browser.

## The toolchain

The versions are in `.tool-versions`: Elixir 1.20, Erlang 28 and Node 24.

### On your machine

Use the Nix shell. It gives each tool, and it gives Zig for a Burrito release.

```sh
nix develop      # or: direnv allow, after you copy .envrc.example to .envrc
mix deps.get
```

### In a Claude Code session on the web

A remote container has no Elixir, and it has no Nix. The hook
`.claude/hooks/session-start.sh` installs a toolchain at the start of each remote session.
The hook does nothing on your machine, where the Nix shell gives the tools.

The hook does these operations:

1. `apt-get install erlang-nox erlang-dev unzip curl`. The apt package gives Erlang/OTP 25.
2. Download the Elixir build for OTP 25 from the Elixir release on GitHub, and put it in
   `/opt/elixir`. The apt package gives Elixir 1.14, and `mix.exs` needs 1.17 or later.
3. Write `PATH` and `ELIXIR_ERL_OPTIONS` into `$CLAUDE_ENV_FILE`.
4. `mix local.hex`, `mix local.rebar`, `mix deps.get` and `mix compile`.

The versions of the container are not the versions of `.tool-versions`. Erlang/OTP 25 and
Elixir 1.18 compile this project and run each check. Two rules apply:

- The Elixir build must agree with the OTP release. The name of the file on GitHub is
  `elixir-otp-25.zip`.
- The container gives a latin1 name encoding. Therefore `ELIXIR_ERL_OPTIONS` must contain
  `+fnu`, or each command writes a warning.

To run the hook again by hand:

```sh
CLAUDE_CODE_REMOTE=true CLAUDE_PROJECT_DIR="$PWD" ./.claude/hooks/session-start.sh
```

## The checks

```sh
mix check                      # each tool below, and Dialyzer
mix compile --warnings-as-errors
mix format --check-formatted
mix credo
mix sobelow --exit --skip
mix deps.audit
mix test
```

`mix credo`, `mix sobelow`, `mix format` and `mix test` pass. `mix doctor` does not pass.
The moduledoc coverage is 100 percent, but the doc coverage and the spec coverage are near
50 percent.

Sobelow gives a warning for `Phoenix.HTML.raw/1`. Put a `# sobelow_skip` comment above the
function when the input is safe. `Expresso.main/2` and `Expresso.Renderer.render/1` show
this pattern.

Prettier formats the files in `assets/`. The Nix shell gives Prettier.

## Look at a deck

Make an HTML document, and then open it:

```sh
mix expresso examples/demo.exs /tmp/demo.html
```

A remote container has no display, but it has Chromium and Playwright. Use them to make
sure that a change to the CSS or to `assets/main.js` is correct. The browser is at
`/opt/pw-browsers/chromium-1194/chrome-linux/chrome`. This path is not the default path of
Playwright, so give it to `chromium.launch`.

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

Read the computed style, and do not read the attribute. A defect in a style attribute gives
no error. The browser drops the declaration, and the page looks almost correct.

## Documents

- `docs/architecture.md` — how the code makes an HTML document from a deck.
- `docs/overlays.md` — the design for overlays, and its open decisions.
