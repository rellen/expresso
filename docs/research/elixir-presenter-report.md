# Elixir in place of TypeScript for the presenter

This document gives the result of an investigation on 2026-09-29. The question is this:
how can the presenter use less TypeScript, and how can more of its logic go into Elixir?

The investigation read each module of `assets/src/`, the renderer and the style sheet. It
did not build a prototype. The line counts below come from the repository at commit
`0b22e7f`. The estimates of the result are estimates, and the text marks each one.

## The answer

Much of the logic in the presenter does not need the browser. It needs only the deck, and
Elixir has the deck at render time. Today the renderer writes these values as `data-*`
attributes, and the script reads them back and calculates the same facts again.

The proposal has three parts, and a fourth part that is optional:

1. Elixir writes a list of each step of the deck into the document.
2. Elixir owns the table of keys, and the renderer writes the list of keys as HTML.
3. The renderer writes the parts of the overview and the speaker view that do not change.
4. Optional: the GIF recorder moves from Node to Elixir.

After these parts, TypeScript keeps only the work that needs a browser: the events, the
clock, the second window and the transitions. The decisions of `docs/typescript.md` do not
change.

A variant of part 2 takes the idea of the JS commands of Phoenix LiveView. The section
"The command variant" gives it. Gleam, Elixir in WebAssembly and a server do not agree
with the constraints, and the section "The options that do not agree" tells why.

## The presenter today

| Part | Files | Lines |
| --- | --- | --- |
| The script | `assets/src/*.ts`, 5 modules | 1398 |
| The unit tests | `assets/test/`, 217 tests | 3089 |
| The GIF recorder | `assets/gifs/*.ts` | 303 |
| The browser tests | `test/e2e/`, 15 modules in Elixir | — |

The bundle `priv/static/presenter.js` has 13268 bytes. The comments in `assets/src/` are
long, so the lines of code are fewer than the table shows.

## Three groups of logic

Each part of the script goes into one of three groups.

| Group | The parts | Where the part can go |
| --- | --- | --- |
| A. The part needs only the deck | `maxStep`, `limits()`, `count`, `fraction`, `done`, `upcoming`, `describe`, `kinds()`, the table `BINDINGS`, `help.ts`, `columns` and the zoom of the overview, `data-thumbnail`, `speakerPanel`, the minutes of `data-duration` | Elixir, at render time |
| B. The part is pure, but it needs the input of the user | `next` and the reducer of the overview, the fragment of the address, `side` and `swipe`, the messages (`stamp`, `accepts`, `isMessage`, `follow`), `clock`, `pace` and `left` | TypeScript, and smaller after group A moves |
| C. The part needs the browser | the listeners of `main.ts`, `apply`, `animate`, the full screen, `window.open`, `postMessage`, the timers | TypeScript |

Group A is the problem. For example, the renderer calculates the maximum step of each
slide and writes it as `data-max-step`. `dom.ts` reads each value into `Limits`, and
`state.ts` then calculates the sequence of steps, the progress and the next step from
it. The same fact is in two languages, and the document is the only connection between
them.

## The proposal

### 1. A list of the steps from Elixir

This part gives the most value. The renderer writes one JSON block into the document:

```html
<script type="application/json" id="expresso-deck">
{"steps": [[1, 1, 0.0, 0.0, "Slide 1 of 12"], [1, 2, 0.04, 0.03, "Slide 1 of 12, step 2 of 3"]],
 "slides": [{"first": 0, "transition": "fade"}],
 "duration_ms": 1200000}
</script>
```

Each entry of `steps` holds the slide, the step, the value of `fraction`, the value of
`done` and the position text of the speaker view. Each entry of `slides` holds the index
of its first step and its kind of transition.

The state of the script then holds an index into `steps`, and not a slide and a step:

- `forward` adds 1 to the index, and `back` subtracts 1.
- `Home`, `End` and a typed slide number go to `slides[n].first`.
- The next step of the speaker view is the entry after the index.
- The width of the progress bar, the pace and the position text are values of the entry.

These functions then leave TypeScript: `maxStep`, `count`, `fraction`, `done`,
`upcoming`, `describe`, `limits()` and `kinds()`. Most of `forward`, `back` and `move`
also go. `talkLength` keeps only the `?duration=` parameter of the address.

The tests of these functions go to ExUnit. `stream_data` is a dependency already, so the
property tests of `state_property.test.ts` can go to ExUnit too.

Two details apply:

- Elixir 1.20 gives `JSON.encode!/1`, and `Mix.Tasks.Expresso.Gifs` uses it already. The
  block needs no new dependency.
- A `<` in the JSON must become `<`. Otherwise a text in the deck can close the
  `script` element. `Expresso.Css.escape/1` solves the same problem for the style sheet.

The renderer can keep `data-max-step` for the browser tests and for a theme. The script
does not read it.

### 2. The table of keys in Elixir

A new module, such as `Expresso.Presenter.Keys`, holds the table that `BINDINGS` holds
today. The table has 175 lines in `state.ts`. The renderer then writes two things from
the module:

- The list of keys of each mode, as HTML. The style sheet shows the list of the current
  mode.
- A small JSON map from each key to its action, for each mode.

`help.ts`, the table `NAMES`, the table `BINDINGS` and the function `help` of `dom.ts` then
leave TypeScript. A later version can let a deck change its keys in the DSL. The tables of
keys in `docs/architecture.md` and in `README.md` can also come from the module.

TypeScript still needs the type `Action`, because the `never` check in `next` finds an
action with no branch. Two methods keep the Elixir actions and the TypeScript actions
equal:

- **(a) A check at load.** The script refuses an unknown action in the JSON. A browser test
  presses each key of the table.
- **(b) A generated file.** The compiler `Mix.Tasks.Compile.Presenter` in `mix.exs` writes
  `assets/src/actions.ts` from the module. Git holds the file, and `mix check` fails when
  the file is not current.

Method (a) is simpler. Method (b) finds a difference before a deck runs.

### 3. The parts of the overview and the speaker view that do not change

- The renderer writes `--overview-columns` and `--overview-zoom` on the `body`, and
  `data-thumbnail` on the page of the last step of each slide. The script then writes
  only `data-selected`.
- The renderer writes the four `speaker-*` elements. The style sheet hides them outside
  the speaker view already, for example with
  `body:not([data-view="speaker"]) #speaker-notes`.

This part is small, and it does not need part 1 or part 2.

### 4. The GIF recorder in Elixir (optional)

`assets/gifs/record.ts` has 206 lines. `playwright_ex` gives the functions that the
recorder needs: `clock_install`, `screenshot` and `evaluate`. Elixir has no GIF encoder,
so the port needs one of these:

- An encoder in Elixir. `:zlib` of Erlang reads a PNG. A palette and the LZW compression
  then make the GIF. The size is approximately 200 to 300 lines, and this is an estimate.
- A dependency on Vix, which uses libvips.

The port removes `gifenc` and `pngjs`. Node stays, because `playwright_ex` runs the Node
driver of Playwright. Therefore the only gain is one language for the tools, and this part
has the least value.

### The result

The estimate for parts 1 to 3 is that `assets/src/` goes from 1398 lines to between 800
and 900 lines. A similar part of the unit tests moves to ExUnit. The investigation did not
measure these numbers.

The size of a document stays approximately the same. The list of steps adds approximately
60 bytes for each step, so a deck with 150 steps gets approximately 9 kB more. The text of
the list of keys moves from the script into the HTML, and the script becomes smaller.

## The command variant

### How LiveView does it

`Phoenix.LiveView.JS` makes a list of commands in Elixir. Version 1.2.12 gives
`show`, `hide`, `toggle`, `add_class`, `remove_class`, `toggle_class`, `set_attribute`,
`remove_attribute`, `toggle_attribute`, `transition`, `dispatch`, `push`, `navigate`,
`patch`, `focus`, `exec` and some more. A HEEx template writes the list as JSON into an
attribute such as `phx-click`. The client script runs the list when the event occurs, and
the changes stay after the next patch from the server.

A command cannot read a state, compare two values or calculate a number. The server does
that work. A deck opens from the disk and has no server, so the script must still hold the
position and do the arithmetic.

This project cannot use the library itself. The client script of LiveView is a part of
the LiveView socket, and it expects a connection to a server. It is also much larger than
the presenter. The idea can come into this project, but the code cannot.

### The design

The attributes of the `body` hold the state. Each mode is a CSS selector on the `body`, and
the interpreter uses the first mode that the `body` matches:

```elixir
keys do
  # A black screen or the list of keys closes at the next key, and the key does no more.
  mode "body[data-blank]", any: JS.remove_attribute("data-blank", to: "body")
  mode "body[data-help]", any: JS.remove_attribute("data-help", to: "body")

  mode "body[data-view=present]" do
    key ~w(j ArrowRight ArrowDown PageDown Space), JS.step(+1), "Next step"
    key ~w(k ArrowLeft ArrowUp PageUp), JS.step(-1), "Previous step"
    key "b", JS.set_attribute({"data-blank", "true"}, to: "body"), "Black screen"
    key "g", JS.toggle_attribute({"data-progress", "true", "false"}, to: "body"), "Progress bar"
    key "p", JS.set_attribute({"data-view", "handout"}, to: "body"), "Handout view"
    key "s", JS.builtin(:open_speaker), "Speaker view"
    key "f", JS.builtin(:fullscreen), "Full screen"
  end
end
```

The renderer writes three things from this definition:

- The map of keys, as JSON.
- The list of keys of each mode, as HTML.
- An attribute with a command on each page of the overview. A click on a page of the
  overview then goes to its slide, as a `phx-click` does.

The interpreter in TypeScript knows approximately ten commands:

- `set_attribute`, `remove_attribute` and `toggle_attribute`.
- `step(n)` and `goto(first | last | typed | selected)`, on the list of steps of part 1.
- `select(n)`, for the overview.
- `digit`, for a typed slide number.
- `builtin(name)`, for the full screen, the speaker view and the timer.

### What the variant gives

- **One definition of the behavior, in Elixir.** The keys, the texts, the modes and the
  lists of keys come from one place. Elixir can refuse a bad definition when the deck
  compiles. For example, a Spark verifier can refuse a key that occurs two times in one
  mode.
- **A feature for decks and elements.** When an element can hold a command, a link to
  slide 5 is `JS.goto(slide: 5)` on a text element. An extension can add an element that
  shows its content on a click, and it needs no new TypeScript. This is the largest
  difference from part 2.
- **Less TypeScript.** `next`, the reducer of the overview, `BINDINGS` and `help.ts` have
  approximately 320 lines. An interpreter needs approximately 150 lines. With part 1, the
  estimate for `assets/src/` is between 600 and 700 lines.

### What the variant costs

- **The commands can become a second language.** Each behavior that does not fit adds
  pressure for a condition, a variable or a new command. Make one rule at the start: the
  commands get no condition and no variable. A behavior that needs one of them is a
  built-in function in TypeScript.
- **Some rules do not fit already.** Each of these goes into `step`, `goto` or the main
  loop of the interpreter, and not into the commands:
  - Each key except a digit removes the typed digits.
  - A transition needs the position before the change and after the change.
  - A message to the other window holds the position and the black screen.
- **The type check moves.** Today the `never` check of TypeScript finds an action with no
  branch. With commands, Elixir examines the definition, and the interpreter examines the
  JSON at load. The safety is similar, but it is in two languages.
- **The tests move.** Most of the 217 unit tests examine `next`. Elixir can write the
  default map of keys to a file for the tests. The TypeScript tests can then run the
  interpreter with that file and with no browser. Each other test becomes a browser test,
  and a browser test is slower.
- **The document holds the state.** The object `State` goes away, and the attributes of
  the `body` are the only copy of the position and the flags. LiveView does the same, but
  a unit test of a state in the DOM is more difficult than a unit test of an object.

## The options that do not agree

| Option | The reason |
| --- | --- |
| Gleam | `docs/research/gleam-report.md` measured approximately 5 kB for the part of the Gleam prelude that stays in the bundle. The bundle is now 13268 bytes, so the cost is approximately 1.4 times the size, and not 6 times. But `mix compile` then needs a compiler that no Hex package gives, and Gleam is not Elixir. The `never` check of TypeScript already finds an action with no branch in `next`. |
| Elixir in WebAssembly (Popcorn) | Popcorn 0.3 runs Elixir on AtomVM in WebAssembly, and the prerelease 0.4 runs the BEAM of Erlang/OTP in WebAssembly. The investigation did not measure the size of the runtime, and it did not open a Popcorn page from the disk. A runtime of that type is much larger than a script of 13 kB, and each deck must hold it. Measure both facts before a new decision. |
| Hologram or LiveView | Both need a server. A deck is one HTML file that opens from the disk, so a server breaks the constraint of `docs/typescript.md`. A presenter that a server controls can be an optional mode on the server of the watch mode later. It cannot replace the file. |

## The risks

- **The contract changes form.** Today the contract is a set of `data-*` attributes in
  different places. After part 1, it is one JSON block that Elixir defines. That is
  better, but each field needs a type in TypeScript and an examination at load.
- **The browser tests are the safety net.** The 15 modules of `test/e2e/` are in Elixir,
  and they test the behavior and not the script. Each part above can keep them unchanged.
- **The documents change.** The section "The presenter" of `docs/architecture.md` and the
  section "The JavaScript code" of `docs/overlays.md` describe the attributes that the
  script reads today. Each part must update them.

## The order of the work

Do each part in its own pull request, in this sequence:

1. Part 1, the list of the steps. Part 2 and the command variant need it.
2. Part 3, the parts that do not change. It is small and it needs no other part.
3. Part 2, or the command variant. Try the command variant on the present view only
   first. Measure the lines, the size of a document and the number of tests that move,
   and then decide.
4. Part 4, if the maintainer wants it.

## The decisions

The maintainer decides each of these. None of them is settled.

1. Does Elixir own the table of keys?
2. Which method keeps the actions equal: (a), the check at load, or (b), the generated
   file?
3. Part 2 or the command variant?
4. In the command variant, what holds the state? The attributes of the `body` can hold
   it. Or TypeScript can keep the object `State` and write the attributes from it.
5. In the command variant, is the set of commands closed, or can an extension add a
   command?
6. In the command variant, can a deck or an element hold a command? If yes, the commands
   become a public API.
7. Does the GIF recorder move to Elixir?

## The sources

- [`Phoenix.LiveView.JS`](https://phoenix-live-view.hexdocs.pm/Phoenix.LiveView.JS.html)
  gives the commands of version 1.2.12. It says that "JS commands are DOM-patch aware, so
  operations applied by the JS APIs will stick to elements across patches from the
  server", and that `window.liveSocket.execJS(el, js)` runs a command on the client.
- [Popcorn](https://popcorn.swmansion.com/) says that it compiles Elixir to WebAssembly
  and runs it in the browser with no server.
- [The Popcorn repository](https://github.com/software-mansion/popcorn) says that "The
  stable 0.3 release uses AtomVM", and that "The 0.4 prerelease uses the BEAM virtual
  machine from Erlang/OTP, compiled to WebAssembly".
- `docs/research/gleam-report.md` gives the measurement of the Gleam bundle.
- `docs/typescript.md` gives the constraint of one HTML file and the five decisions of the
  script.
