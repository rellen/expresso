defmodule Expresso.ThemeVerifier do
  @moduledoc """
  The Spark verifier of the contrast of the `theme` option

  It runs one time for each deck module at compile time. A built-in theme
  meets each minimum of `Expresso.Palette`, so only a theme of 16 colors can
  fail. The verifier gives a warning for each role that fails, and the deck
  still compiles. The option itself refuses a value that is not a theme.

  The warning of a role names the slot of its color, and a color for that
  slot that passes, from `Expresso.Palette.suggestions/1`. The colors of the
  map stay as the user gives them.

  The verifier checks each variant of the option that is a map, after the
  adjustment of `adjust: true`, and the warning of a variant names it. An
  adjustment that changes a color by more than the limit of a built-in theme
  gives a warning too.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Palette
  alias Spark.Dsl.Verifier

  @doc """
  Give a warning for each role of the theme of the deck under its minimum of contrast
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:warn, [String.t()]}
  def verify(dsl_state) do
    theme = Verifier.get_option(dsl_state, [:deck], :theme, :default)

    warnings =
      for {name, palette} <- Palette.variants(theme),
          map?(theme, name),
          warning <- warnings(palette, subject(name), adjust?(theme)),
          do: warning

    if warnings == [], do: :ok, else: {:warn, warnings}
  end

  # A built-in theme meets each minimum, so the verifier checks a map only.
  defp map?(theme, _name) when is_map(theme), do: true
  defp map?(theme, nil) when is_list(theme), do: is_map(theme[:colors])
  defp map?(theme, name) when is_list(theme), do: is_map(theme[name])
  defp map?(_theme, _name), do: false

  defp adjust?(theme), do: is_list(theme) and Keyword.get(theme, :adjust, false)

  defp subject(nil), do: "the theme"
  defp subject(name), do: "the #{name} theme"

  defp warnings(palette, subject, adjust?) do
    problems = Palette.problems(palette)
    suggestions = Palette.suggestions(palette)

    Enum.map(problems, &warning(&1, subject, suggestions)) ++ change(palette, subject, adjust?)
  end

  # The adjustment of a built-in theme stops at a change of 0.4, because a
  # larger change gives a color that the reader does not know as a color of
  # the scheme. A map gets the adjustment with no limit, and a warning.
  defp change(%Palette{change: change}, subject, true) do
    limit = Palette.Builtin.limit()

    if change > limit,
      do: [
        "the adjustment changes a color of #{subject} by #{Float.round(change, 2)} in " <>
          "lightness, more than #{limit}, so the color can look different from the color of the map"
      ],
      else: []
  end

  defp change(_palette, _subject, _adjust?), do: []

  defp warning({role, measure, value, minimum}, subject, suggestions),
    do: measure(subject, role, measure, value, minimum) <> ". " <> fix(role, suggestions)

  defp measure(subject, role, :wcag, ratio, minimum),
    do:
      "#{subject} gives #{role} a contrast of #{Float.round(ratio, 2)}:1, and WCAG asks for #{minimum}:1"

  defp measure(subject, role, :apca, lc, minimum),
    do:
      "#{subject} gives #{role} a lightness contrast of Lc #{round(lc)}, and APCA asks for Lc #{minimum}"

  # The dimmed text passes when each role of text passes.
  defp fix(:dimmed_text, _suggestions), do: "It passes when each role of text passes"

  defp fix(role, suggestions) do
    {slot, _on} = Keyword.fetch!(Palette.roles(), role)

    case Map.fetch(suggestions, slot) do
      {:ok, color} -> "The color #{color} for #{slot} passes"
      :error -> "No lightness of the color of #{slot} passes"
    end
  end
end
