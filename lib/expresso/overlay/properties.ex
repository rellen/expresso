defmodule Expresso.Overlay.Properties do
  @moduledoc """
  The check of the custom properties of one slide

  `slide/1` does the work of `Expresso.Overlay.PropertyVerifier`, and it is a
  pure function on an `Expresso.Slide` struct. It reads the `state` option and
  the `set` option of each `on` entity of the slide, and it gives one warning
  for each property that `Expresso.Theme` reports as a defect.

  `registered_state/2` does a part of the work of `Expresso.Overlay.Verifier`.
  It refuses a state that takes the name of a property that the theme
  registers.

  `docs/overlays.md` gives the rules.
  """

  alias Expresso.Element.{On, Tree}
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
  - A key of the `set` option names a registered property, and the value does
    not agree with the syntax of that registration. The browser then ignores
    the value, and the property keeps its initial value. A `<length>` needs a
    unit of length, an `<angle>` needs a unit of angle, and a `<number>` needs
    a plain number. A value with a CSS function, such as `var()` or `calc()`,
    and a CSS-wide keyword, such as `inherit`, get no warning, because the
    browser calculates them.

  Each message holds the path of the slide. The function adds the location of
  the `on` entity when Spark has it. A module of a test has no debug
  information, and Spark then gives `nil`.
  """
  @spec slide(Slide.t(), Expresso.Css.names()) :: [warning()]
  def slide(%Slide{} = slide, names \\ Theme.names()) do
    path = slide |> Expresso.Dsl.slide_path() |> Enum.join(" -> ")

    for element <- Tree.descendants(slide.elements),
        on <- Map.get(element, :on) || [],
        warning <- entity(on, {path, names}),
        do: warning
  end

  defp entity(%On{state: state, set: set} = on, context) do
    states = if state, do: state(state, on, context), else: []

    states ++ Enum.flat_map(set || [], fn {key, value} -> set(key, value, on, context) end)
  end

  @doc """
  Give an error for a state that takes the name of a property that the theme registers

  The compiler registers each state as a number with the initial value 0, and
  that registration replaces the registration of the theme. Each element of
  the deck that reads the property then gets 0 in place of the initial value
  of the theme, on each slide. The state `scale` is an example: each element
  gets the size 0 × 0. The default registrations are those of the theme.
  """
  @spec registered_state(Slide.t(), %{String.t() => String.t()}) :: :ok | {:error, String.t()}
  def registered_state(%Slide{} = slide, registered \\ Theme.names().registered) do
    states =
      for element <- Tree.descendants(slide.elements),
          %On{state: state} <- Map.get(element, :on) || [],
          state != nil,
          do: state

    case Enum.find(states, &Map.has_key?(registered, Atom.to_string(&1))) do
      nil -> :ok
      state -> {:error, registered_message(state, Map.fetch!(registered, Atom.to_string(state)))}
    end
  end

  defp registered_message(state, syntax) do
    "the state `#{state}` writes the custom property `--#{state}`, and the theme registers " <>
      "that property with the syntax #{inspect(syntax)}. The compiler registers each state " <>
      "as a number with the initial value 0, and that registration replaces the registration " <>
      "of the theme on each slide. Give the state a different name, or use the set option"
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

  defp set(key, value, on, {path, names}) do
    name = Atom.to_string(key)
    syntax = Map.get(names.registered, name)

    cond do
      name not in names.used -> [unused(path, "the set key", key, on)]
      agrees?(value, syntax) -> []
      true -> [mismatch(path, key, value, syntax, on)]
    end
  end

  @length_units ~w(px em rem ex rex ch rch cap rcap ic ric lh rlh vw vh vi vb vmin vmax
                   svw svh svi svb svmin svmax lvw lvh lvi lvb lvmin lvmax dvw dvh dvi dvb
                   dvmin dvmax cqw cqh cqi cqb cqmin cqmax cm mm q in pt pc)
  @angle_units ~w(deg grad rad turn)
  @wide_keywords ~w(inherit initial unset revert revert-layer)
  @dimension ~r/\A[+-]?(?:\d+\.?\d*|\.\d+)(?:e[+-]?\d+)?([a-z]*)\z/i

  # The function knows three syntaxes. It accepts each value for a different
  # syntax, and for a property that no rule registers.
  defp agrees?(value, syntax) when syntax in ["<length>", "<angle>", "<number>"] do
    text = value |> to_string() |> String.trim()

    String.contains?(text, "(") or String.downcase(text) in @wide_keywords or
      unit_agrees?(Regex.run(@dimension, text), syntax)
  end

  defp agrees?(_value, _syntax), do: true

  # A `<length>` accepts a zero without a unit, and an `<angle>` does not.
  defp unit_agrees?([zero, ""], "<length>"), do: String.match?(zero, ~r/\A[+-]?0*\.?0*(e.*)?\z/i)
  defp unit_agrees?([_text, unit], "<length>"), do: String.downcase(unit) in @length_units
  defp unit_agrees?([_text, unit], "<angle>"), do: String.downcase(unit) in @angle_units
  defp unit_agrees?([_text, unit], "<number>"), do: unit == ""
  defp unit_agrees?(nil, _syntax), do: false

  @advice %{
    "<length>" => "Give a length with a unit of length, such as \"400px\"",
    "<angle>" => "Give an angle with a unit of angle, such as \"45deg\"",
    "<number>" => "Give a plain number without a unit, such as 1.5"
  }

  defp mismatch(path, key, value, syntax, on) do
    message(
      "#{path}: the set key `#{key}` gives the value #{inspect(value)} to the custom property " <>
        "`--#{key}`, and the theme registers that property with the syntax #{inspect(syntax)}. " <>
        "The browser ignores the value, and the property keeps its initial value. " <>
        Map.fetch!(@advice, syntax),
      on
    )
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
