defmodule Expresso.Overlay.Properties do
  @moduledoc """
  The check of the custom properties of one slide

  `slide/1` does the work of `Expresso.Overlay.PropertyVerifier`, and it is a
  pure function on an `Expresso.Slide` struct. It reads the `state` option and
  the `set` option of each `on` entity of the slide, and it gives one warning
  for each property that `Expresso.Theme` reports as a defect.

  `docs/overlays.md` gives the rules.
  """

  alias Expresso.Element.{On, Pause}
  alias Expresso.Slide
  alias Expresso.Theme
  alias Spark.Dsl.Entity

  @typedoc "A warning of the verifier, with the location of the `on` entity"
  @type warning :: {String.t(), :erl_anno.anno()} | String.t()

  @doc """
  Give a warning for each custom property of a slide that is a defect

  The names come from the theme and from the CSS of the deck, which
  `Expresso.Css.merge/2` joins. The default is the theme alone. The function
  reports these conditions:

  - The `state` option, or a key of the `set` option, names a property that
    the theme does not use. The renderer writes the property, and no rule of
    the theme reads it. Therefore the value has no effect.
  - The `state` option names a property that the theme declares, or that the
    theme registers with a different syntax than a number. The compiler
    registers each state as a number with the initial value 0. That
    registration makes the value of the theme invalid, and the theme then
    loses the property.

  Each message holds the path of the slide. The function adds the location of
  the `on` entity when Spark has it. A module of a test has no debug
  information, and Spark then gives `nil`.
  """
  @spec slide(Slide.t(), Expresso.Css.names()) :: [warning()]
  def slide(%Slide{} = slide, names \\ Theme.names()) do
    path = Enum.join([:deck, :slide | List.wrap(slide.name)], " -> ")

    elements(slide.elements || [], {path, names})
  end

  defp elements(elements, context), do: Enum.flat_map(elements, &element(&1, context))

  defp element(%Pause{}, _context), do: []

  defp element(element, context) do
    on = Map.get(element, :on) || []
    children = Map.get(element, :elements) || []

    Enum.flat_map(on, &entity(&1, context)) ++ elements(children, context)
  end

  defp entity(%On{state: state, set: set} = on, context) do
    states = if state, do: state(state, on, context), else: []

    states ++ Enum.flat_map(set || [], fn {key, _value} -> set(key, on, context) end)
  end

  defp state(state, on, {path, names}) do
    name = Atom.to_string(state)
    syntax = Map.get(names.registered, name)

    cond do
      name not in names.used -> [unused(path, "the state", state, on)]
      name in names.declared -> [declared(path, state, on)]
      syntax in [nil, "<number>"] -> []
      true -> [collision(path, state, syntax, on)]
    end
  end

  defp set(key, on, {path, names}) do
    if Atom.to_string(key) in names.used, do: [], else: [unused(path, "the set key", key, on)]
  end

  defp unused(path, kind, name, on) do
    message(
      "#{path}: #{kind} `#{name}` writes the custom property `--#{name}`, " <>
        "and neither the theme nor the CSS of the deck uses that property",
      on
    )
  end

  defp declared(path, name, on) do
    message(
      "#{path}: the state `#{name}` writes the custom property `--#{name}` as a number, " <>
        "and the theme gives that property a value of a different type",
      on
    )
  end

  defp collision(path, name, syntax, on) do
    message(
      "#{path}: the state `#{name}` writes the custom property `--#{name}` as a number, " <>
        "and the theme registers that property with the syntax #{inspect(syntax)}",
      on
    )
  end

  defp message(text, on) do
    case Entity.anno(on) do
      nil -> text
      anno -> {text, anno}
    end
  end
end
