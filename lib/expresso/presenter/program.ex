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
  functions for it.
  """

  alias Expresso.Presenter.Definition
  alias Expresso.Steps

  @typedoc "The commands for each event in one mode"
  @type mode :: %{
          name: atom(),
          when: keyword(),
          any: [Definition.command()] | nil,
          keys: %{String.t() => [Definition.command()]},
          click: %{atom() => [Definition.command()]},
          swipe: %{atom() => [Definition.command()]},
          element: boolean(),
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
          modes: [mode()],
          steps: tuple(),
          slides: tuple()
        }

  @enforce_keys [:state, :sync, :modes, :steps, :slides]
  defstruct @enforce_keys

  @doc """
  Make the program of a deck from a definition
  """
  @spec compile(Definition.t(), Expresso.Deck.t()) :: t()
  def compile(definition, deck) do
    slides = Steps.slides(deck)

    %__MODULE__{
      state: definition.state,
      sync: definition.sync,
      modes: Enum.map(definition.modes, &mode(&1, slides)),
      steps: deck |> Steps.entries() |> Enum.map(&{&1.slide, &1.step}) |> List.to_tuple(),
      slides: List.to_tuple(slides)
    }
  end

  @doc """
  Return the commands that a page in the overview holds for a slide

  A click on the page goes to step 1 of the slide, and it closes the overview.
  """
  @spec element(pos_integer()) :: [Definition.command()]
  def element(slide), do: [{:goto_slide, slide}, {:set, :overview, false}]

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
      element: mode.element,
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
