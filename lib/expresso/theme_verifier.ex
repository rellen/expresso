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
    case Verifier.get_option(dsl_state, [:deck], :theme, :default) do
      colors when is_map(colors) -> colors |> Palette.of() |> warnings()
      _name -> :ok
    end
  end

  defp warnings(palette) do
    case Palette.problems(palette) do
      [] -> :ok
      problems -> {:warn, Enum.map(problems, &warning(&1, Palette.suggestions(palette)))}
    end
  end

  defp warning({role, measure, value, minimum}, suggestions),
    do: measure(role, measure, value, minimum) <> ". " <> fix(role, suggestions)

  defp measure(role, :wcag, ratio, minimum),
    do:
      "the theme gives #{role} a contrast of #{Float.round(ratio, 2)}:1, and WCAG asks for #{minimum}:1"

  defp measure(role, :apca, lc, minimum),
    do:
      "the theme gives #{role} a lightness contrast of Lc #{round(lc)}, and APCA asks for Lc #{minimum}"

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
