defmodule Expresso.Overlay.Verifier do
  @moduledoc """
  The check of the overlays

  `Expresso.VerifierTransformer` runs it after the other transformers, one
  time for each deck module at compile time, so an error stops the compile.
  It calls `Expresso.Overlay.Check.slide/1` for each slide. An error from the
  check becomes a `Spark.Error.DslError` with the path of the slide. It then
  calls `Expresso.Overlay.Properties.registered_state/2`, which refuses a state
  that takes the name of a property that the theme registers.
  """

  use Spark.Dsl.Verifier

  alias Expresso.Dsl
  alias Expresso.Overlay.{Check, Properties}
  alias Shoddy.Result
  alias Spark.Dsl.Verifier

  @doc """
  Check the steps and the states of each slide of the deck
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    dsl_state |> Dsl.map_slides(&check_slide/1) |> Result.ignore()
  end

  defp check_slide(slide) do
    with :ok <- Check.slide(slide), do: Properties.registered_state(slide)
  end
end
