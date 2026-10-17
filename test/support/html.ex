defmodule Expresso.Test.HTML do
  @moduledoc """
  Shortens the steps and the LazyHTML queries that the unit tests use most

  "The HTML in a unit test" in `docs/development.md` tells how to write a test
  with LazyHTML. Put `import Expresso.Test.HTML` in the test module.

  A test of the HTML usually makes a deck, renders it and queries the
  document:

      chart |> one_slide() |> document() |> screen("figure.chart") |> only!()

  A module that imports this module cannot define a private function with
  the same name and arity, such as `document/1`. A private `document/0` or
  `screen/1` can call these functions.
  """

  alias Expresso.Builder

  @doc """
  Render a deck, or the deck of a DSL module, and parse the document
  """
  @spec document(Expresso.Deck.t() | module()) :: LazyHTML.t()
  def document(%Expresso.Deck{} = deck),
    do: deck |> Expresso.Deck.render() |> LazyHTML.from_document()

  def document(module) when is_atom(module), do: module |> Expresso.parse() |> document()

  @doc """
  Make a deck with one slide, `"s"`, that holds the elements

  `elements` is one element or a list. `slide_opts` go to
  `Expresso.Builder.slide/2`, and `deck_opts` go to
  `Expresso.Builder.deck/2`. The deck has the name `"test"` unless
  `deck_opts` give a name, so each slide shows a deck name, as in a deck of a
  user.
  """
  @spec one_slide(struct() | [struct()], keyword(), keyword()) :: Expresso.Deck.t()
  def one_slide(elements, slide_opts \\ [], deck_opts \\ []) do
    [Builder.slide("s", [elements: List.wrap(elements)] ++ slide_opts)]
    |> Builder.deck(Keyword.merge([name: "test"], deck_opts))
  end

  @doc """
  Query the present view: the nodes that a selector finds inside `.screen`

  The document also writes each slide into the handout view and into the
  thumbnails of the menu, so a query without the scope finds each node more
  than one time. `selector` is one selector, and not a list with commas.
  """
  @spec screen(LazyHTML.t(), String.t()) :: LazyHTML.t()
  def screen(html, selector), do: LazyHTML.query(html, ".screen " <> selector)

  @doc """
  Return the one node of a query, or fail the test when the query found a
  different number of nodes
  """
  @spec only!(LazyHTML.t()) :: LazyHTML.t()
  def only!(nodes) do
    case Enum.to_list(nodes) do
      [node] -> node
      found -> ExUnit.Assertions.flunk("The query found #{length(found)} nodes, and not one.")
    end
  end

  @doc """
  Return the number of the nodes that a selector finds
  """
  @spec count(LazyHTML.t(), String.t()) :: non_neg_integer()
  def count(html, selector), do: html |> LazyHTML.query(selector) |> Enum.count()

  @doc """
  Return the text of each node that a selector finds
  """
  @spec texts(LazyHTML.t(), String.t()) :: [String.t()]
  def texts(html, selector), do: html |> LazyHTML.query(selector) |> Enum.map(&LazyHTML.text/1)
end
