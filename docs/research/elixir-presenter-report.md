# Elixir in place of TypeScript for the presenter

This document gives the result of an investigation on 2026-09-29. The question is this:
how can the presenter use less TypeScript, and how can more of its logic go into Elixir?

The investigation read each module of `assets/src/`, the renderer and the style sheet. It
did not build a prototype. A second investigation on the same day examined the command
variant in more depth, and the section "The interpreter" gives its result. The line counts
below come from the repository at commit `0b22e7f`. The estimates of the result are
estimates, and the text marks each one.

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
"The command variant" gives it. The section "The interpreter" takes the variant further:
Elixir writes a small program for each deck, and a general interpreter in TypeScript runs
it. The tests of the behavior then go to Elixir. Gleam, Elixir in WebAssembly and a server
do not agree with the constraints, and the section "The options that do not agree" tells
why.

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
  a unit test of a state in the DOM is more difficult than a unit test of an object. The
  section "The interpreter" replaces this design with an object for the state.

## The interpreter

A second investigation on the same day examined the command variant in more depth. It
compared each rule of `state.ts` and `main.ts` with the command model. It did not build a
prototype, so the result is a design on paper. Four findings change the design above.

### 1. Elixir writes a program for each deck

In the design above, Elixir writes one table of keys. A better design treats Elixir as a
compiler. At render time, Elixir writes a small program for this deck into the document.
The TypeScript is then a general interpreter, and it runs the program that the document
holds.

The program is specific to one deck, so Elixir does most of the arithmetic, and the
program holds the results as numbers:

| Today, in TypeScript | In the program of a deck |
| --- | --- |
| `ArrowDown` in the overview adds `columns(slides)` | `["select", 4]`, because the deck has 4 columns |
| `End` goes to step 1 of the last slide | `["goto", 37]` |
| `Home` goes to the first slide | `["goto", 0]` |
| A typed number and `Enter` find the slide | A table from each slide to its index, in the JSON. The built-in function `go_typed` reads it. |

This makes the rule "no condition and no variable" possible. The browser seldom calculates
a value, because Elixir calculated it for the deck.

### 2. An object holds the state

This finding replaces the design above, where the attributes of the `body` hold the state.
LiveView can keep a state in the DOM, because the server holds the true state. A deck
opens from the disk and has no server. Three parts of the presenter also need named
fields:

- The messages between the two windows send the position and the black screen.
- The fragment `#4.2` of the address holds the position.
- A test must compare the state before an event with the state after it.

Therefore Elixir declares the fields of the state, the fields that go to the other window,
and the attribute that shows each field:

```elixir
state index: 0, view: :present, blank: false, help: false, digits: "",
      overview: false, selected: 1, progress: true, every: false

sync [:index, :blank]

project body: [view: "data-view", blank: "data-blank", every: "data-every"],
        vars: ["--fraction": {:entry, :fraction}]
```

`{:entry, :fraction}` is a value of the current entry of the list of steps. The style
sheet then gives the progress bar a width of `calc(var(--fraction) * 100%)`.

For each event, the interpreter does these steps:

1. It finds the first mode whose condition the state matches.
2. It finds the commands of the event in that mode.
3. It applies the commands to the state, one after the other.
4. It compares the new state with the old state. With no change, it stops.
5. It writes each changed field to the document, in a transition when the rule of the
   transitions gives one.
6. It calls `preventDefault`.

Step 4 keeps a rule of the handout view. A key that changes nothing goes to the browser, so
the arrow keys still scroll the pages.

### 3. Each rule of today fits the model

The rules need three mechanisms:

- **The condition of a mode.** A condition compares fields of the state with values. The
  first mode that matches is the mode of the event.
- **Commands that stop at the ends of the deck.** A move past the first step or the last
  step gives no change.
- **Approximately six built-in functions in TypeScript.** They do the work that needs the
  clock, a second window or the address.

This definition gives the present view:

```elixir
mode :present, when: [view: :present], each: clear(:digits) do
  key ~w(j ArrowRight ArrowDown PageDown Space), step(+1), "Next step"
  key ~w(k ArrowLeft ArrowUp PageUp), step(-1), "Previous step"
  key ~w(0 1 2 3 4 5 6 7 8 9), digit(), "Type a slide number", each: false
  key "Enter", go_typed(), "Step 1 of the slide that you typed"
  key "End", goto(last_slide()), "Step 1 of the last slide"
  click :left_third, step(-1), "Previous step"
  swipe :right, step(-1), "Previous step"
end
```

`last_slide()` returns the index of step 1 of the last slide. Elixir calculates it at
render time for each deck. The renderer writes this JSON from the definitions:

```json
{"modes": [
  {"when": {"blank": true}, "any": [["set", "blank", false]]},
  {"when": {"help": true}, "any": [["set", "help", false]]},
  {"when": {"overview": true},
   "keys": {"ArrowDown": [["select", 4]],
            "Enter": [["goto_slide", "selected"], ["set", "overview", false]]}},
  {"when": {"view": "present"},
   "keys": {"j": [["clear", "digits"], ["step", 1]],
            "End": [["clear", "digits"], ["goto", 37]]},
   "click": {"left_third": [["clear", "digits"], ["step", -1]]},
   "other": [["clear", "digits"]]}
]}
```

The table below gives each rule of today and its place in the model.

| The rule of today | The model |
| --- | --- |
| Each key or click closes a black screen or the list of keys, and it does no more. | The modes `when: [blank: true]` and `when: [help: true]` come first, and each has an `any` list. |
| The overview has its own keys, and `?` operates in it. | A mode `when: [overview: true]` comes after the mode of the list of keys. |
| `j` and `k` move one step, and do nothing at the ends of the deck. | `step(+1)` and `step(-1)` stop at the ends. The state does not change, so the key goes to the browser. |
| Each key except a digit removes the typed digits. | Elixir adds `clear(:digits)` to each binding of the mode, and it adds an `other` list for a key with no binding. |
| `Enter` with no digits goes to the browser. | The built-in function `go_typed` returns the same state. |
| The overview opens with the current slide selected. | `assign(:selected, {:entry, :slide})` |
| `Enter` and a click on a page of the overview go to step 1 of the slide. | `[goto_slide(:selected), set(:overview, false)]`. The click version is an attribute on each page of the overview, as `phx-click` is. |
| A click on the left third goes back, and a swipe moves one step. | The events `click :left_third` and `swipe :left`. The distances are parameters of the event, and not conditions. |
| A click with a modifier, on a link or at the end of a selection goes to the browser. | A fixed filter in the source of the click events. |
| `s`, `f` and `r` | The built-in functions `open_speaker`, `fullscreen` and `reset_timer`. |
| The fragment of the address, and the messages between the windows | Built-in functions on the declared fields. The protocol of `stamp` and `accepts` does not change. |
| The transitions | A part of step 5, with the kind of each slide from the list of steps. |
| The speaker view adds ", black screen" to the position. | The style sheet: `body[data-blank] #speaker-position::after { content: ", black screen" }`. |
| The speaker view marks the current page and the next page. | The renderer writes `data-index` on each page. A general `mark` projection writes `data-speaker="current"` on the page whose `data-index` is `index`, and `next` on the page after it. |

The comparison also found an inconsistency in the code today. The keys `s` and `f` remove
the typed digits, but the key `r` does not. In the program, the JSON shows the commands of
each key, so the maintainer can see this and decide the correct behavior.

The subtle parts are the digits and the rule for `preventDefault`. Step 2 of the prototype
below tests them first.

### 4. Two interpreters and one set of tests

Elixir also gets a reference interpreter. It applies the same commands to a map, and it
needs approximately 150 lines of pure functions. This is an estimate. The tests then
change as follows:

1. The tests of the behavior go to ExUnit and StreamData. Most of the 217 TypeScript tests
   examine `next`, and each becomes a test of the program in Elixir.
2. Elixir writes fixtures: random sequences of events, and the state that each sequence
   gives.
3. `npm test` runs the TypeScript interpreter on the same fixtures. A difference between
   the two interpreters makes the test fail.
4. The browser tests of `test/e2e/` do not change.

The program and the interpreter are always in the same HTML file. Therefore the format
between them needs no version: each document holds the interpreter that agrees with its
program.

### What moves

These numbers are estimates. The prototype measures them.

| Part | Today | After |
| --- | --- | --- |
| TypeScript | 1398 lines, all specific to the presenter | 400 to 550 lines of general code. It holds the state, approximately 12 commands, the modes, the sources of events and the projections. It also holds the built-in functions for the clock, the windows and the transitions. |
| Elixir | No part of this logic | The definition of the presenter (approximately 200 lines), the compiler of the program (approximately 200) and the reference interpreter (approximately 150) |
| The tests of the behavior | 217 tests for `node --test` | Most in ExUnit, and a TypeScript suite that compares the two interpreters with the fixtures |

The TypeScript estimate is smaller than the estimate of the command variant above. The
projections and the program for each deck also remove most of `dom.ts`.

### The new risks

- **Two interpreters must agree.** The fixtures keep them equal. That work stays small only
  while the set of commands stays small. This is one more reason for the rule "no
  condition and no variable".
- **The behavior is data, and data is more difficult to debug.** Add a parameter `?trace`
  to the address. With it, the interpreter writes each list of commands to the console,
  with the state before and after it.
- **A command on an element can break the print.** An element command can show content
  outside the model of the steps. The handout view and the print then do not show that
  content, and `docs/overlays.md` says that the handout shows each step. Two rules can
  prevent this:
  - An element command can only go to a different slide or step.
  - An element declares each state that a command can give it, and the print shows each
    declared state.

### The prototype

Do the steps in this sequence. Each step gives a measurement, and the work can stop after
each step:

1. **The list of the steps.** This is part 1 of the proposal. The other steps need it, and
   it has value alone.
2. **The model in Elixir only.** Write the definition of the presenter as plain data, and
   the reference interpreter. Move the approximately 95 tests of `state.test.ts` and
   `state_property.test.ts` to ExUnit. The browser does not change. This step costs the
   least, and it answers the main question: a rule that does not fit the model shows here.
3. **The interpreter in TypeScript.** The fixtures from Elixir drive its tests. It replaces
   `next`, `BINDINGS` and `help.ts`, and the browser tests do not change. Measure the
   bytes and the lines.
4. **The Spark DSL and its verifiers.** Then add the first public feature: `goto(slide: n)`
   on an element.

### The result of step 2

Step 2 is done. Each rule of `state.ts` and `main.ts` fits the model, and no command needs
a condition or a variable. Three modules in `lib/expresso/presenter/` hold the model:

| Module | What it does | Estimate | Lines of code |
| --- | --- | --- | --- |
| `Expresso.Presenter.Definition` | Holds each rule as modes, bindings and commands | 200 | 192 |
| `Expresso.Presenter.Program` | Makes the program of one deck | 200 | 74 |
| `Expresso.Presenter.Interpreter` | Runs a program on a state | 150 | 137 |

The lines of code do not include the documentation and the comments. `Program` is
smaller than the estimate, because it does not write the JSON yet. Step 3 adds that. The
renderer does not use the three modules yet, so the script in the browser does not change.

The result comes from a comparison with the script of today, in these steps:

1. Elixir made 2000 random decks of 0 to 8 slides, and 60 random events for each deck.
2. The Elixir interpreter recorded the state, the call of `preventDefault`, the built-in
   functions, the transition, the fragment and the next step after each event.
3. A Node script sent the same events through `state.ts`, as the listeners of `main.ts`
   do, and it compared each result.

Two runs with different random seeds sent 240000 events, and the comparison found no
difference. The events reached each difficult part of the state:

- Approximately 12 % of the states had the overview.
- Approximately 16 % of the states had typed digits.
- Approximately 2 % of the states had a black screen, and 2 % had the list of keys.
- 228 of the 2000 decks of one run had no slide.

To make sure that the comparison finds a difference, two deliberate changes went into the
model, one at a time. Each change caused approximately 259 differences. The comparison
scripts are not in the repository. Step 3 makes them permanent, as test fixtures for the
TypeScript interpreter.

The tests of the model are in `test/expresso/presenter/`: 58 tests, 17 properties with
500 runs each, and 2 doctests. They come from `state.test.ts` and
`state_property.test.ts`. These TypeScript tests have no copy in ExUnit, because the model
does not hold the code that they test:

- `message`, `isMessage`, `stamp` and `accepts`: the protocol of the messages between the
  windows.
- `side` and `swipe`: the sources of the click events and the swipe events.
- `binding`, `mode` and the rows with no key: the structure of the table `BINDINGS`.

The TypeScript tests stay until step 3 replaces `state.ts`.

The work found four facts that the design above does not contain:

- **A click on a page needs a flag on the mode.** A page of the overview holds the
  commands that go to its slide. The speaker view also shows pages, and there a click on a
  page is a plain click that moves one step. Therefore a mode has the flag `element`, and
  only the overview sets it.
- **The overview needs two forms of `select`.** `ArrowDown` moves the selection by the
  number of columns, and `End` selects the last slide. `select_by` moves the selection by
  a number, and `select` selects a slide by its number. The model has 12 commands, as the
  estimate said.
- **`clear` sets a field to its first value.** The definition declares the first value of
  each field, so `clear(:digits)` needs no value.
- **The fragment and the messages do not go through the modes.** They go to a slide and a
  step directly, as the design said. A fragment also removes a black screen, and a message
  sets the black screen that the other window sends.

The key `r` keeps the typed digits, as the code of today does. The binding of `r` has
`each: false`, so the definition shows the difference from `s` and `f`. Decision 10 is
still open.

### The result of step 3

Step 3 is done. The script of the browser runs the program of each deck with a TypeScript
interpreter. The table `BINDINGS`, the function `next` and the module `help.ts` are not in
the script now. The 66 browser tests of `test/e2e/` pass with no change.

The renderer writes three new parts into each document:

- The program of the deck as JSON, in `script#expresso-program`. `Program.json/1` writes
  it.
- The list of keys of each mode as HTML, in the element `help`. `Expresso.Presenter.Help`
  makes the rows, and `dom.ts` shows the list of one mode.
- The commands of a click in the overview, in `data-commands` on the page of the last step
  of each slide.

The script has two new modules. `program.ts` reads the program, and it makes sure of the
type of each value. `interpreter.ts` runs the program, as `Expresso.Presenter.Interpreter`
does. `state.ts` keeps the type of the state, the messages between the windows, `side`,
`swipe` and `columns`.

These are the measurements. A line of code is a line that is not empty and not a comment:

| Measurement | Before step 3 | After step 3 |
| --- | --- | --- |
| Lines of `assets/src/` | 1451 | 1443 |
| Lines of code of `assets/src/` | 1054 | 1017 |
| Lines of `state.ts` | 676 | 145 |
| Lines of `program.ts` and `interpreter.ts` | 0 | 537 |
| Bytes of the bundle | 13766 | 12468 |
| Bytes of the bundle with `gzip -9` | 4749 | 4574 |
| Lines of `assets/test/` | 3193 | 2396 |
| Tests for `node --test` | 215 | 140 |
| Lines of code of `Expresso.Presenter.Program` | 74 | 118 |
| Lines of code of `Expresso.Presenter.Help` | 0 | 29 |

The bundle is 1298 bytes smaller. The document is larger, because it holds the program and
the lists of keys. For the deck of `examples/demo.exs`, the program has 3079 bytes and the
lists of keys have 3442 bytes. Each slide adds 43 bytes of `data-commands`. A document
with one slide is therefore approximately 5.2 kB larger. The document of that deck has
199387 bytes, so the increase is approximately 2.6 %.

The script did not become as small as the estimate of "What moves". These are the reasons:

- `program.ts` has 206 lines of code, and most of them examine the JSON at load. The
  estimate did not count this examination.
- Step 3 did not make the projections. `dom.ts`, `speaker.ts` and `main.ts` did not
  become smaller.

The larger gain is in the rules. A new key with the current commands is now a change to
`Expresso.Presenter.Definition` only. The TypeScript interpreter knows no key.

The comparison of step 2 is now a permanent test:

1. `Expresso.Test.PresenterFixtures` runs the Elixir interpreter on 32 cases: 16 random
   decks, 2 sequences for each deck, and 30 random events in each sequence.
2. It writes the events and the results into `assets/test/fixtures/presenter.json`. The
   file also holds the programs of 23 decks and the lists of keys. It has 175779 bytes.
3. `assets/test/interpreter.test.ts` runs the 960 events through the TypeScript
   interpreter, and it compares each state, the call of `preventDefault`, the built-in
   functions and the transition.
4. `test/expresso/presenter/fixtures_test.exs` fails when the file does not agree with the
   definition. `docs/development.md` tells how to write the file again.

To make sure that the test finds a difference, a deliberate change went into the
TypeScript interpreter. The test failed at event 14 of case 29.

The first fixture file had 281 kB, and fewer random decks made it smaller. The property
tests of `test/expresso/presenter/` examine the Elixir model with more events. The fixture
file keeps the TypeScript interpreter equal to the Elixir interpreter.

### The result of step 4

Step 4 is done. The maintainer settled two decisions for this step:

- Decision 8: the definition of the presenter is a Spark DSL, and only Expresso uses it. A
  deck cannot change the keys.
- Decision 9: a command on an element can only go to a slide and a step.

The step has two parts. The first part is the DSL of the presenter:

- `Expresso.Presenter.Default` writes each rule of the presenter in the DSL of
  `Expresso.Presenter.Extension`. `Expresso.Presenter.Definition` reads it into the maps
  of step 2, so the program, the interpreters and the list of keys did not change.
- `Expresso.Presenter.Verifier` refuses a bad definition when the module compiles. It finds
  an unknown field, a value of the wrong type and an unknown command. It also finds two
  modes with the same name, and one event with two bindings in one mode.
- The fixture test compares the program of each fixture deck with the committed file.
  After the first part, the test found no change.

The second part is the first public feature, the `goto` option:

- A text area, an image or an item with `goto: [slide: 5, step: 2]` is a link. The render
  function puts its content into `<a class="goto" href="#5.2" data-commands=...>`.
- `Expresso.GotoVerifier` refuses a link to a slide or a step that the deck does not have.
- A click on the link in the present view runs its commands. The modes `present` and
  `overview` have the option `element`, and the `each` commands of the mode go in front
  of the commands of the element. Thus a click on a link removes the typed digits, as each other
  click does.
- `Tab` and `Enter` operate the link, and a screen reader reads it as a link.
  `docs/reference/goto-option.md` gives the effect of a click in each view.

These are the measurements. A line of code is a line that is not empty and not a comment:

| Measurement | Before step 4 | After step 4 |
| --- | --- | --- |
| Lines of code of `assets/src/` | 1017 | 1021 |
| Bytes of the bundle | 12468 | 12508 |
| Lines of code of the definition in Elixir | 188 | 472 |
| Lines of code of `Expresso.Goto` and `Expresso.GotoVerifier` | 0 | 101 |

The feature added 4 lines of code to the script. The script finds the nearest element with
commands, and it does not give a click on a link with commands to the browser. The overview
needed one rule in the style sheet: a click on the content of a page finds the page. Each
other part of the feature is in Elixir.

The DSL made the definition larger. The definition was 188 lines of code in one module.
Now it is 99 lines in `Expresso.Presenter.Default`, 64 lines in
`Expresso.Presenter.Definition`, and 309 lines for the extension, the verifier and the
commands. The extra lines find a bad definition when the module compiles, and not when the
presenter uses a document.

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

Part 1 is done: `Expresso.Steps` makes the list, and the state of the script holds an index
into it. The script did not become smaller:

- `assets/src/` went from 1398 lines to 1451 lines. `state.ts` lost 62 lines, but the new
  module `deck.ts` has 133 lines, and most of them examine the JSON at load.
- The bundle went from 13268 bytes to 13766 bytes.

The calculations that moved to Elixir were short. The larger gain is in the tests: the
tests of `fraction`, `done` and the position text are now ExUnit tests of
`Expresso.Steps`.

Steps 2, 3 and 4 of "The prototype" are also done. Each rule fits the model, the script
runs the program of each deck, and an element can hold a link to a step. The sections "The
result of step 2", "The result of step 3" and "The result of step 4" contain the
measurements.

Do each part in its own pull request, in this sequence:

1. Part 1, the list of the steps. Part 2 and the command variant need it.
2. Part 3, the parts that do not change. It is small and it needs no other part.
3. Part 2, or the interpreter. For the interpreter, do steps 2 to 4 of "The prototype".
   Step 2 changes no code in the browser, and it shows if each rule fits the model.
4. Part 4, if the maintainer wants it.

## The decisions

The maintainer decides each of these. Decisions 8 and 9 are settled, and the answer
follows each of them.

1. Does Elixir own the table of keys?
2. Which method keeps the actions equal: (a), the check at load, or (b), the generated
   file?
3. Part 2, the command variant or the interpreter?
4. In the command variant, what holds the state? The attributes of the `body` can hold
   it. Or TypeScript can keep the object `State` and write the attributes from it. The
   section "The interpreter" recommends the object.
5. In the command variant, is the set of commands closed, or can an extension add a
   command?
6. In the command variant, can a deck or an element hold a command? If yes, the commands
   become a public API.
7. Does the GIF recorder move to Elixir?
8. Is the definition of the presenter a Spark DSL or a plain module? Step 2 used a plain
   module, and it was sufficient. The DSL can come at step 4. Answer: a Spark DSL,
   and only `Expresso.Presenter.Default` uses it.
9. Can an element command only go to a slide or a step? Or can an element declare its
   own states, which the print then shows? Answer: an element command can only go to
   a slide and a step.
10. Does the key `r` remove the typed digits, as `s` and `f` do?

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
