defmodule Expresso.LinkPreviewVerifier do
  @moduledoc """
  The Spark verifier of the options of a link preview

  The `card` option gives the picture of the preview of a link, and the tag
  `og:image` holds its absolute address. The address comes from the `url`
  option, so a deck with a card and with no address is an error at compile
  time. `Expresso.LinkPreview` gives the rules of the options.
  """

  use Spark.Dsl.Verifier

  alias Spark.Dsl.Verifier

  @doc """
  Return an error for a deck with the `card` option and no `url` option
  """
  @impl Verifier
  @spec verify(map()) :: :ok | {:error, Spark.Error.DslError.t()}
  def verify(dsl_state) do
    card = Verifier.get_option(dsl_state, [:deck], :card)
    url = Verifier.get_option(dsl_state, [:deck], :url)

    if card != nil and url == nil do
      {:error,
       Spark.Error.DslError.exception(
         module: Verifier.get_persisted(dsl_state, :module),
         path: [:deck, :card],
         message: Expresso.LinkPreview.card_needs_url()
       )}
    else
      :ok
    end
  end
end
