defmodule Expresso.Presenter.Definition do
  @moduledoc """
  Holds each rule of the presenter as data: modes, bindings and commands

  This module is step 2 of the prototype that
  `docs/research/elixir-presenter-report.md` describes in its section "The
  interpreter". It holds the rules of `assets/src/state.ts` and
  `assets/src/main.ts`. `Expresso.Presenter.Program`
  makes the program of one deck from it, and `Expresso.Presenter.Interpreter`
  runs that program. The renderer does not use these modules yet, so the script
  in the browser does not change.

  ## The modes

  A mode has a condition on the state, such as `[view: :present]`. The
  interpreter uses the first mode whose condition the state matches. A mode
  holds:

    * `bindings` - each binding holds one or more events, a list of commands and
      its row in the list of keys.
    * `each` - the commands that go in front of each binding. The present, the
      speaker and the handout views remove the typed digits with each key. A
      binding with `each: false` does not get them.
    * `any` - the commands for each event of the mode. The black screen and the
      list of keys close at the next event, and the event does no more.
    * `other` - true when a key with no binding gets the `each` commands.
    * `element` - true when a click on an element runs the commands of that
      element. A page of the overview has the commands that go to its slide.

  ## The events

    * `{:key, key}` - the value of `KeyboardEvent.key`, such as `"j"` or `" "`.
    * `{:click, :left_third}` and `{:click, :right}` - a click or a tap.
    * `{:swipe, :left}` and `{:swipe, :right}` - a movement of one finger.
    * `:element` - a click on an element that holds commands.

  ## The commands

    * `{:set, field, value}` - sets a field to a value.
    * `{:toggle, field}` - changes a field from true to false, or from false to
      true.
    * `{:clear, field}` - sets a field to its first value, which `presenter/0`
      declares.
    * `{:assign, :selected, {:entry, :slide}}` - selects the slide of the current
      step.
    * `{:append, :digits}` - adds the key to the typed digits.
    * `{:step, count}` - moves forward or back by a number of steps. A move past
      the first step or the last step makes no change.
    * `{:goto, index}` - goes to the step at an index in the deck.
    * `{:goto_slide, slide}` - goes to step 1 of a slide. With `:selected`, it
      goes to step 1 of the selected slide.
    * `{:select, slide}` and `{:select_by, count}` - select a slide in the
      overview, or move the selection by a number of slides. A slide outside the
      deck makes no change.
    * `:go_typed` - goes to step 1 of the slide that the typed digits give, and
      removes the digits.
    * `{:builtin, name}` - calls a built-in function of the browser:
      `:open_speaker`, `:fullscreen` or `:reset_timer`.

  A definition can hold two symbols in place of a number: `:last_slide` and
  `{:columns, sign}`. `Expresso.Presenter.Program` changes each symbol into a
  number for the deck.
  """

  @typedoc "A field of the state"
  @type field ::
          :index | :view | :blank | :help | :digits | :overview | :selected | :progress | :every

  @typedoc "A command of a definition. The section \"The commands\" of the module documentation tells what each command does."
  @type command ::
          {:set, field(), term()}
          | {:toggle, field()}
          | {:clear, field()}
          | {:assign, :selected, {:entry, :slide}}
          | {:append, :digits}
          | {:step, integer()}
          | {:goto, non_neg_integer() | :last_slide}
          | {:goto_slide, :selected | pos_integer()}
          | {:select, pos_integer() | :last_slide}
          | {:select_by, integer() | {:columns, 1 | -1}}
          | :go_typed
          | {:builtin, :open_speaker | :fullscreen | :reset_timer}

  @typedoc "An event of a binding"
  @type event ::
          {:key, String.t()}
          | {:click, :left_third | :right}
          | {:swipe, :left | :right}
          | :element

  @typedoc "A binding: its events, its commands and its row in the list of keys"
  @type binding :: %{
          on: [event()],
          commands: [command()],
          text: String.t(),
          label: String.t() | nil,
          each: boolean()
        }

  @typedoc "A mode of the presenter"
  @type mode :: %{
          name: atom(),
          when: keyword(),
          bindings: [binding()],
          each: [command()],
          any: [command()] | nil,
          other: boolean(),
          element: boolean()
        }

  @typedoc "The definition of the presenter"
  @type t :: %{state: map(), sync: [field()], modes: [mode()]}

  @digits ~w(0 1 2 3 4 5 6 7 8 9)

  @doc """
  Return the definition of the presenter today

  The modes come in the order that the interpreter examines them. The black
  screen comes first, then the list of keys, then the overview, then the views.
  """
  @spec presenter() :: t()
  def presenter do
    %{
      state: %{
        index: 0,
        view: :present,
        blank: false,
        help: false,
        digits: "",
        overview: false,
        selected: 1,
        progress: true,
        every: false
      },
      sync: [:index, :blank],
      modes: [
        mode(:blank, [blank: true], any: [{:set, :blank, false}]),
        mode(:help, [help: true], any: [{:set, :help, false}]),
        mode(:overview, [overview: true], bindings: overview(), element: true),
        mode(:present, [view: :present], bindings: showing(:present), each: clear(), other: true),
        mode(:speaker, [view: :speaker], bindings: showing(:speaker), each: clear(), other: true),
        mode(:handout, [view: :handout], bindings: handout(), each: clear(), other: true)
      ]
    }
  end

  defp clear, do: [{:clear, :digits}]

  defp mode(name, condition, options) do
    %{
      name: name,
      when: condition,
      bindings: Keyword.get(options, :bindings, []),
      each: Keyword.get(options, :each, []),
      any: Keyword.get(options, :any),
      other: Keyword.get(options, :other, false),
      element: Keyword.get(options, :element, false)
    }
  end

  defp binding(on, commands, text, options \\ []) do
    %{
      on: on,
      commands: commands,
      text: text,
      label: Keyword.get(options, :label),
      each: Keyword.get(options, :each, true)
    }
  end

  defp keys(names), do: Enum.map(names, &{:key, &1})

  # The present view and the speaker view share most keys. The order is the
  # order of the rows in the list of keys today.
  defp showing(view) do
    [
      binding(
        keys(["j", "ArrowRight", "ArrowDown", "PageDown", " "]),
        [{:step, 1}],
        "Next step, or the first step of the next slide"
      ),
      binding(
        keys(["k", "ArrowLeft", "ArrowUp", "PageUp"]),
        [{:step, -1}],
        "Previous step, or the last step of the previous slide"
      ),
      binding(keys(["Home"]), [{:goto, 0}], "First slide"),
      binding(keys(["End"]), [{:goto, :last_slide}], "Step 1 of the last slide"),
      binding(keys(@digits), [{:append, :digits}], "Type a slide number",
        label: "0 to 9",
        each: false
      ),
      binding(keys(["Enter"]), [:go_typed], "Step 1 of the slide that you typed", each: false),
      binding(
        keys(["b"]),
        [{:set, :blank, true}],
        "Black screen. The next key shows the slide again."
      )
    ] ++
      only(view == :present, [
        binding(keys(["p"]), [{:set, :view, :handout}], "Handout view"),
        binding(
          keys(["s"]),
          [{:builtin, :open_speaker}],
          "Speaker view, in a second window"
        )
      ]) ++
      only(view == :speaker, [
        # The key `r` does not remove the typed digits today, and the keys `s`
        # and `f` do. The report asks the maintainer about this difference.
        binding(keys(["r"]), [{:builtin, :reset_timer}], "Set the timer to 0:00", each: false)
      ]) ++
      [binding(keys(["f"]), [{:builtin, :fullscreen}], "Full screen on or off")] ++
      only(view == :present, [
        binding(keys(["g"]), [{:toggle, :progress}], "Progress bar on or off")
      ]) ++
      [
        binding([{:click, :right}, {:swipe, :left}], [{:step, 1}], "Next step",
          label: "Click or tap the right two thirds, or swipe left"
        ),
        binding([{:click, :left_third}, {:swipe, :right}], [{:step, -1}], "Previous step",
          label: "Click or tap the left third, or swipe right"
        ),
        binding(
          keys(["o"]),
          [{:set, :overview, true}, {:assign, :selected, {:entry, :slide}}],
          "Overview of the slides. Only this window shows it."
        ),
        binding(keys(["?"]), [{:set, :help, true}], "This list of keys. The next key closes it.")
      ]
  end

  defp only(true, bindings), do: bindings
  defp only(false, _bindings), do: []

  # The handout view knows only these keys. The browser gets each other key,
  # so the arrow keys and the space bar scroll the pages.
  defp handout do
    [
      binding(keys(["j"]), [{:step, 1}], "Next step. The present view then shows it."),
      binding(keys(["k"]), [{:step, -1}], "Previous step. The present view then shows it."),
      binding(keys(["p"]), [{:set, :view, :present}], "Present view"),
      binding(
        keys(["a"]),
        [{:toggle, :every}],
        "Every step, or the steps of the handout option. A print shows the same."
      ),
      binding(keys(["?"]), [{:set, :help, true}], "This list of keys. The next key closes it.")
    ]
  end

  # The list of keys of the overview shows `?` in the first row.
  defp overview do
    [
      binding(keys(["?"]), [{:set, :help, true}], "This list of keys. The next key closes it."),
      binding(
        keys(["j", "ArrowRight", "PageDown", " "]),
        [{:select_by, 1}],
        "Select the next slide"
      ),
      binding(
        keys(["k", "ArrowLeft", "PageUp"]),
        [{:select_by, -1}],
        "Select the previous slide"
      ),
      binding(keys(["ArrowDown"]), [{:select_by, {:columns, 1}}], "Select the slide below"),
      binding(keys(["ArrowUp"]), [{:select_by, {:columns, -1}}], "Select the slide above"),
      binding(keys(["Home"]), [{:select, 1}], "Select the first slide"),
      binding(keys(["End"]), [{:select, :last_slide}], "Select the last slide"),
      binding(
        keys(["Enter"]),
        [{:goto_slide, :selected}, {:set, :overview, false}],
        "Step 1 of the selected slide"
      ),
      binding([:element], [], "Step 1 of that slide", label: "Click or tap a slide"),
      binding(
        keys(["o", "Escape"]),
        [{:set, :overview, false}],
        "Close the overview. The step does not change."
      )
    ]
  end
end
