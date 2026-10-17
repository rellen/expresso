defmodule Expresso.Test.HTMLTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder

  defmodule Deck do
    use Expresso

    name "helpers"

    slide "s" do
      text_box do
        text_area(text: "a")
      end
    end
  end

  defp qr_code, do: Builder.qr_code("https://example.com") |> one_slide() |> document()

  test "document renders a deck and the deck of a DSL module to the same document" do
    assert LazyHTML.to_html(document(Deck)) == LazyHTML.to_html(document(Expresso.parse(Deck)))
  end

  test "one_slide puts the elements on the slide s, and gives the options to the slide and the deck" do
    deck = one_slide(Builder.text_area(text: "a"))
    assert deck.name == "test"
    assert [%{name: "s", elements: [_]}] = deck.slides

    deck = one_slide([], [heading: "Start"], name: "named")
    assert deck.name == "named"
    assert [%{metadata: %{heading: "Start"}}] = deck.slides
  end

  test "screen finds the node of the present view, and not its copies in the handout and the menu" do
    document = qr_code()

    assert count(document, ".qr-code") > 1
    assert document |> screen(".qr-code") |> Enum.count() == 1
  end

  test "only! returns the one node, and fails for a different number of nodes" do
    document = qr_code()

    assert document |> screen(".qr-code") |> only!() |> LazyHTML.tag() == ["figure"]

    assert_raise ExUnit.AssertionError, ~r/found 3 nodes, and not one/, fn ->
      document |> LazyHTML.query(".qr-code") |> only!()
    end

    assert_raise ExUnit.AssertionError, ~r/found 0 nodes, and not one/, fn ->
      document |> screen(".chart") |> only!()
    end
  end
end
