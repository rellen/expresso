defmodule Expresso.ThemeVerifier do
  @moduledoc """
  The Spark verifier of the contrast of the `theme` option

  It runs one time for each deck module at compile time. A built-in theme
  meets each minimum of `Expresso.Palette`, so only a theme of 16 colors can
  fail. The verifier gives a warning for each role that fails, and the deck
  still compiles. The option itself refuses a value that is not a theme.
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
      colors when is_map(colors) -> colors |> Palette.of() |> Palette.problems() |> warnings()
      _name -> :ok
    end
  end

  defp warnings([]), do: :ok

  defp warnings(problems) do
    {:warn,
     Enum.map(problems, fn
       {role, :wcag, ratio, minimum} ->
         "the theme gives #{role} a contrast of #{Float.round(ratio, 2)}:1, and WCAG asks for #{minimum}:1"

       {role, :apca, lc, minimum} ->
         "the theme gives #{role} a lightness contrast of Lc #{round(lc)}, and APCA asks for Lc #{minimum}"
     end)}
  end
end
