defmodule Expresso.Presenter.Definition do
  @moduledoc """
  Holds the types of the presenter definition, and reads the definition

  A definition holds each rule of the presenter as data: modes, bindings and
  commands. `Expresso.Presenter.Default` writes the definition in the DSL of
  `Expresso.Presenter.Extension`, and `presenter/0` reads it into maps.
  `Expresso.Presenter.Program` makes the program of one deck from the
  definition, and the interpreter in the browser runs that program.
  `Expresso.Presenter.Interpreter` is the reference interpreter in Elixir.

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
      element, after the `each` commands. A page of the overview has the
      commands that go to its slide, and a link of `Expresso.Goto` has the
      commands that go to its step.

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
      `:open_speaker`, `:fullscreen`, `:reset_timer` or `:switch_scheme`.

  A definition can hold two symbols in place of a number: `:last_slide` and
  `{:columns, sign}`. `Expresso.Presenter.Program` changes each symbol into a
  number for the deck.
  """

  @typedoc "A field of the state"
  @type field ::
          :index
          | :view
          | :blank
          | :help
          | :digits
          | :overview
          | :selected
          | :progress
          | :every
          | :undim

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
          | {:builtin, :open_speaker | :fullscreen | :reset_timer | :switch_scheme}

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

  alias Expresso.Presenter.{Binding, Mode, Projection}

  @typedoc "The definition of the presenter"
  @type t :: %{state: map(), sync: [field()], modes: [mode()], project: Projection.t()}

  @doc """
  Return the definition of the presenter

  The definition comes from `Expresso.Presenter.Default`. The modes come in the
  order that the interpreter examines them. The black screen comes first, then
  the list of keys, then the overview, then the views.
  """
  @spec presenter() :: t()
  def presenter, do: from(Expresso.Presenter.Default)

  @doc """
  Make a definition from a module that uses `Expresso.Presenter.Dsl`
  """
  @spec from(module()) :: t()
  def from(module) do
    entities = Spark.Dsl.Extension.get_entities(module, [:presenter])

    %{
      state: module |> Spark.Dsl.Extension.get_opt([:presenter], :state) |> Map.new(),
      sync: Spark.Dsl.Extension.get_opt(module, [:presenter], :sync),
      modes: for(%Mode{} = mode <- entities, do: mode(mode)),
      project: Projection.from(entities)
    }
  end

  defp mode(%Mode{} = mode) do
    %{
      name: mode.name,
      when: mode.match,
      bindings: Enum.map(mode.bindings, &binding_map/1),
      each: mode.each,
      any: mode.any,
      other: mode.other,
      element: mode.element
    }
  end

  defp binding_map(%Binding{} = binding),
    do: Map.take(binding, [:on, :commands, :text, :label, :each])
end
