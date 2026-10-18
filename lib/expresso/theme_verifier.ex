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

  The verifier also gives a warning for each variant that does not dim at the
  `dim_contrast` option of the deck. `dim_messages/2` gives the rules.
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
    ratio = Verifier.get_option(dsl_state, [:deck], :dim_contrast)
    warnings = messages(theme) ++ dim_messages(theme, ratio)
    if warnings == [], do: :ok, else: {:warn, warnings}
  end

  @doc """
  Return the warning of each role of a theme under its minimum of contrast

  `theme` is a value of the `theme` option. `verify/1` and `Expresso.Check`
  call this function.

      iex> Expresso.ThemeVerifier.messages(:dracula)
      []
  """
  @spec messages(term()) :: [String.t()]
  def messages(theme) do
    for {name, palette} <- Palette.variants(theme),
        map?(theme, name),
        warning <- warnings(palette, subject(name), adjust?(theme)),
        do: warning
  end

  @doc """
  Return the warning of each variant of a theme that does not dim at a minimum contrast ratio

  `ratio` is the `dim_contrast` option of the deck, or `nil` for the default
  of 3:1. A variant does not dim when its dim opacity is 1.0: then no opacity
  under 1.0 keeps each role of text at `ratio` on its background. A dimmed
  image, SVG file, embed and video then do not dim, because the style sheet
  dims them with `--dim-opacity`. The warning also names each role of text
  that keeps its color in the state `dim`.

  A variant that fails a minimum of `messages/1` gets no warning here,
  because its warnings of contrast tell the cause.

      iex> Expresso.ThemeVerifier.dim_messages(:default, nil)
      []
      iex> [message] = Expresso.ThemeVerifier.dim_messages(:solarized_light, 4.5)
      iex> message =~ "no role of text dims"
      true
  """
  @spec dim_messages(term(), number() | nil) :: [String.t()]
  def dim_messages(theme, ratio) do
    for {name, palette} <- Palette.variants(theme),
        Palette.problems(palette) == [],
        dimmed = Palette.with_dim_contrast(palette, ratio),
        dimmed.dim_opacity == 1.0,
        do: dim_warning(dimmed, subject(name))
  end

  defp dim_warning(%Palette{dimmed: dimmed, dim_ratio: ratio}, subject) do
    roles = for {role, {_slot, on}} <- Palette.roles(), on != nil, do: role
    full = Enum.filter(roles, fn role -> elem(dimmed[role], 0) == 1.0 end)

    text =
      if length(full) == length(roles),
        do: "no role of text dims",
        else: "the roles #{Enum.join(full, ", ")} do not dim"

    "at a dim contrast of #{ratio_text(ratio)}:1, #{subject} gives --dim-opacity 1.0, so a " <>
      "dimmed image, SVG file, embed and video do not dim, and #{text}. Give a lower " <>
      "dim_contrast or a theme with more contrast. See docs/reference/dim-contrast-option.md"
  end

  defp ratio_text(ratio) when ratio == trunc(ratio), do: Integer.to_string(trunc(ratio))
  defp ratio_text(ratio), do: Float.to_string(ratio)

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
