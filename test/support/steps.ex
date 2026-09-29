defmodule Expresso.Test.Steps do
  @moduledoc """
  Reads the list of the steps from a rendered document

  `Expresso.Renderer` writes the list as JSON into the element
  `script#expresso-deck`. The tests read it from the HTML, as the presenter
  does in a browser.
  """

  @doc "Render a deck, and return the decoded list of its steps"
  @spec read(Expresso.Deck.t()) :: map()
  def read(deck) do
    deck
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find("script#expresso-deck")
    |> Floki.text(js: true)
    |> JSON.decode!()
  end
end
