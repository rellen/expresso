defmodule Expresso.Presenter.Program do
  @moduledoc """
  Makes the program of the presenter for one deck

  `compile/2` takes a definition from `Expresso.Presenter.Definition` and a
  deck. The result holds numbers where the definition holds symbols, so the
  interpreter calculates almost nothing. For example, `ArrowDown` in the
  overview becomes `{:select_by, 3}` for a deck of 7 slides, because such a deck
  has 3 columns.

  `compile/2` also puts the `each` commands of a mode in front of each binding,
  and it makes a map from each event to its commands. A key with two bindings
  in one mode raises an error, because the list of keys would show two
  functions for it. `Expresso.Presenter.Verifier` refuses such a definition
  when it compiles.

  A mode with the option `element` gets its `each` commands in `element`, and
  each other mode gets `nil`. The interpreter puts these commands in front of
  the commands of an element under a click.
  """

  alias Expresso.Presenter.{Definition, Projection}
  alias Expresso.Steps

  @typedoc "The commands for each event in one mode"
  @type mode :: %{
          name: atom(),
          when: keyword(),
          any: [Definition.command()] | nil,
          keys: %{String.t() => [Definition.command()]},
          click: %{atom() => [Definition.command()]},
          swipe: %{atom() => [Definition.command()]},
          element: [Definition.command()] | nil,
          other: [Definition.command()] | nil
        }

  @typedoc """
  The program of one deck

  `steps` holds `{slide, step}` for each step. `slides` holds a map for each
  slide: the index of its step 1, its number of steps and its transition. Both
  are tuples, so the interpreter reads an entry by its index.
  """
  @type t :: %__MODULE__{
          state: map(),
          sync: [Definition.field()],
          reset: [Definition.field()],
          modes: [mode()],
          project: Projection.t(),
          steps: tuple(),
          slides: tuple()
        }

  @enforce_keys [:state, :sync, :reset, :modes, :project, :steps, :slides]
  defstruct @enforce_keys

  @doc """
  Make the program of a deck from a definition

  The first value of the field `progress` comes from the deck: the deck option
  `progress false` hides the progress bar at the start. A deck from the
  imperative API with no such key in its metadata shows the bar.
  """
  @spec compile(Definition.t(), Expresso.Deck.t()) :: t()
  def compile(definition, deck) do
    slides = Steps.slides(deck)

    %__MODULE__{
      state: Map.put(definition.state, :progress, progress(deck)),
      sync: definition.sync,
      reset: definition.reset,
      modes: Enum.map(definition.modes, &mode(&1, slides)),
      project: definition.project,
      steps: deck |> Steps.entries() |> Enum.map(&{&1.slide, &1.step}) |> List.to_tuple(),
      slides: List.to_tuple(slides)
    }
  end

  @doc """
  Return the program as JSON for the `script` element

  The JSON object has five keys:

    * `"state"` - the first value of each field of the state.
    * `"sync"` - the fields that a message to the other window holds, after
      the slide and the step.
    * `"reset"` - the fields that take their first value again at each change
      of the step.
    * `"modes"` - the modes, in the order that the interpreter examines them.
      A mode holds its `"name"`, its condition `"when"`, its `"any"` commands
      or `null`, its `"other"` commands or `null`, and its `"element"` commands
      or `null`.
      `"keys"`, `"click"` and `"swipe"` hold pairs of events and commands. Each
      pair holds each event that has the same commands.
    * `"project"` - the projections, as `Expresso.Presenter.Projection.json/1`
      returns them.

  A command is a JSON array, such as `["step", 1]`, as `json_commands/1`
  shows. The steps and the slides are not in the program, because
  `Expresso.Steps.json/1` writes them. Each `<` becomes `\\u003c`, as in the
  list of the steps.
  """
  @spec json(t()) :: String.t()
  def json(program) do
    # The keys are strings, so each render gives the same text. See
    # `Expresso.Steps.json/1`.
    %{
      "state" =>
        Map.new(program.state, fn {field, value} -> {Atom.to_string(field), value(value)} end),
      "sync" => Enum.map(program.sync, &Atom.to_string/1),
      "reset" => Enum.map(program.reset, &Atom.to_string/1),
      "modes" => Enum.map(program.modes, &mode_json/1),
      "project" => Projection.json(program.project)
    }
    |> JSON.encode!()
    |> String.replace("<", "\\u003c")
  end

  @doc """
  Return a list of commands as JSON, such as `[["step",1]]`

  The first element of each array is the name of the command. A field, a view
  and a built-in function become strings.

      iex> Expresso.Presenter.Program.json_commands([{:goto_slide, 2}, {:set, :overview, false}])
      ~s([["goto_slide",2],["set","overview",false]])
  """
  @spec json_commands([Definition.command()]) :: String.t()
  def json_commands(commands), do: commands |> Enum.map(&command_json/1) |> JSON.encode!()

  defp mode_json(mode) do
    %{
      "name" => Atom.to_string(mode.name),
      "when" =>
        Map.new(mode.when, fn {field, value} -> {Atom.to_string(field), value(value)} end),
      "any" => commands_json(mode.any),
      "other" => commands_json(mode.other),
      "element" => commands_json(mode.element),
      "keys" => pairs(mode.keys),
      "click" => pairs(mode.click),
      "swipe" => pairs(mode.swipe)
    }
  end

  # Each group of events with the same commands becomes one pair. The groups and
  # the events in each group are in sorted order.
  defp pairs(map) do
    map
    |> Enum.group_by(fn {_event, commands} -> commands end, fn {event, _commands} ->
      value(event)
    end)
    |> Enum.sort()
    |> Enum.map(fn {commands, events} -> [Enum.sort(events), commands_json(commands)] end)
  end

  defp commands_json(nil), do: nil
  defp commands_json(commands), do: Enum.map(commands, &command_json/1)

  defp command_json({:assign, field, {:entry, :slide}}),
    do: ["assign", value(field), ["entry", "slide"]]

  defp command_json(command) when is_atom(command), do: [value(command)]
  defp command_json(command), do: command |> Tuple.to_list() |> Enum.map(&value/1)

  # The deck option `progress false` hides the progress bar at the start.
  defp progress(%{metadata: %{progress: false}}), do: false
  defp progress(_deck), do: true

  defp value(value) when is_boolean(value) or is_nil(value), do: value
  defp value(value) when is_atom(value), do: Atom.to_string(value)
  defp value(value), do: value

  @doc """
  Return the commands that a page in the overview holds for a slide

  A click on the page goes to step 1 of the slide, and it closes the overview.
  """
  @spec element(pos_integer()) :: [Definition.command()]
  def element(slide), do: [{:goto_slide, slide}, {:set, :overview, false}]

  @doc """
  Return the commands of a link to the step at an index, for `Expresso.Goto`

      iex> Expresso.Presenter.Program.link(7)
      [{:goto, 7}]
  """
  @spec link(non_neg_integer()) :: [Definition.command()]
  def link(index), do: [{:goto, index}]

  @doc """
  Return the number of columns in the overview for a number of slides

  The result is the square root of the slide count, rounded up to an integer.
  The number of rows is then not more than the number of columns.

      iex> Expresso.Presenter.Program.columns(7)
      3

      iex> Expresso.Presenter.Program.columns(0)
      1
  """
  @spec columns(non_neg_integer()) :: pos_integer()
  def columns(slides), do: max(1, ceil(:math.sqrt(slides)))

  defp mode(mode, slides) do
    bindings =
      Enum.map(mode.bindings, fn binding ->
        each = if binding.each, do: mode.each, else: []
        %{binding | commands: Enum.map(each ++ binding.commands, &resolve(&1, slides))}
      end)

    %{
      name: mode.name,
      when: mode.when,
      any: mode.any,
      keys: events(mode.name, bindings, :key),
      click: events(mode.name, bindings, :click),
      swipe: events(mode.name, bindings, :swipe),
      element: if(mode.element, do: mode.each),
      other: if(mode.other, do: mode.each)
    }
  end

  # The map from each event of one kind to its commands.
  defp events(mode, bindings, kind) do
    for binding <- bindings, {^kind, value} <- binding.on, reduce: %{} do
      map -> put_event(map, mode, kind, value, binding.commands)
    end
  end

  defp put_event(map, mode, kind, value, _commands) when is_map_key(map, value),
    do: raise(ArgumentError, "the mode #{mode} has two bindings for #{kind} #{inspect(value)}")

  defp put_event(map, _mode, _kind, value, commands), do: Map.put(map, value, commands)

  # A symbol becomes a number for the deck. A deck with no slide has no last
  # slide, and a command with `nil` makes no change.
  defp resolve({:goto, :last_slide}, slides), do: {:goto, slides |> List.last() |> first()}
  defp resolve({:select, :last_slide}, slides), do: {:select, length(slides)}

  defp resolve({:select_by, {:columns, sign}}, slides),
    do: {:select_by, sign * columns(length(slides))}

  defp resolve(command, _slides), do: command

  defp first(nil), do: nil
  defp first(slide), do: slide.first
end
