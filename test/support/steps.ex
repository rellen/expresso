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
    |> LazyHTML.from_document()
    |> LazyHTML.query("script#expresso-deck")
    |> LazyHTML.text()
    |> JSON.decode!()
  end
end
