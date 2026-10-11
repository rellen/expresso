defmodule Expresso.CalloutElementTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Callout

  doctest Callout

  defp render(elements, opts \\ []) do
    [Builder.slide("s", Keyword.merge([elements: List.wrap(elements)], opts))]
    |> Builder.deck(name: "callouts")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

  defp text(text), do: Builder.text_area(text: text)

  test "a callout is a note with the class of its kind, a header and a body" do
    document = render(Builder.callout(:warning, elements: [text("Back up the data first.")]))
    [callout] = Floki.find(document, ".screen .callout")

    assert Floki.attribute(callout, "class") == ["callout callout-warning"]
    assert Floki.attribute(callout, "role") == ["note"]
    assert callout |> Floki.find(".callout-title") |> Floki.text() == "Warning"
    assert callout |> Floki.find(".callout-body .text-area") |> Floki.text() =~ "Back up"
  end

  test "each kind has its own icon, hidden from a screen reader" do
    icons =
      for kind <- Callout.kinds() do
        [svg] = kind |> Builder.callout() |> render() |> Floki.find(".screen .callout-icon")
        assert Floki.attribute(svg, "aria-hidden") == ["true"]
        assert Floki.attribute(svg, "viewbox") == ["0 0 24 24"]
        svg |> Floki.find("path") |> Floki.attribute("d")
      end

    assert length(Enum.uniq(icons)) == length(Callout.kinds())
  end

  test "the title option replaces the name of the kind, and title false removes the header" do
    titled = render(Builder.callout(:definition, title: "Release", elements: [text("x")]))
    assert titled |> Floki.find(".screen .callout-title") |> Floki.text() == "Release"

    bare = render(Builder.callout(:tip, title: false, elements: [text("x")]))
    assert Floki.find(bare, ".screen .callout-title") == []
    assert Floki.find(bare, ".screen .callout-body .text-area") != []
  end

  test "the title is text, and not HTML" do
    document = render(Builder.callout(:note, title: "<b>Bold</b>"))
    assert document |> Floki.find(".screen .callout-title") |> Floki.text() == "<b>Bold</b>"
    assert Floki.find(document, ".screen .callout-title b") == []
  end

  test "the compiler refuses an unknown kind and a title that is not a string or false" do
    assert_raise ArgumentError, ~r/kind/, fn -> Builder.callout(:danger) end

    assert_raise ArgumentError, ~r/the title option of a callout is a string, or false/, fn ->
      Builder.callout(:note, title: true)
    end
  end

  test "a callout takes the overlay options, and its elements show at their own steps" do
    callout =
      Builder.callout(:tip,
        at: [from: 2],
        elements: [text("first"), Builder.text_area(text: "second", at: [from: 3])]
      )

    deck = Builder.deck([Builder.slide("s", elements: [callout])], name: "d")
    [%{elements: [callout]} = slide] = deck.slides

    assert slide.metadata.max_step == 3
    assert callout.steps == [2, 3]
    # A child without at shows at each step at which its parent shows.
    assert Enum.map(callout.elements, & &1.steps) == [nil, [3]]
  end

  test "a text box and a column hold a callout" do
    boxed = Builder.text_box(elements: [Builder.callout(:note, elements: [text("in a box")])])

    columns =
      Builder.columns(
        elements: [Builder.column(elements: [Builder.callout(:caution, elements: [text("x")])])]
      )

    document = render([boxed, columns])
    assert length(Floki.find(document, ".screen .text-box .callout-note")) == 1
    assert length(Floki.find(document, ".screen .column .callout-caution")) == 1
  end

  test "the DSL writes a callout with its options in the block" do
    defmodule Deck do
      use Expresso

      slide "s" do
        callout :important do
          title "Read this"
          at from: 2
          text_area(text: "The text.")
        end
      end
    end

    assert {:ok, %Expresso.Deck{slides: [%{elements: [callout]}]}} = Expresso.to_deck(Deck)
    assert %Callout{kind: :important, title: "Read this", steps: [2]} = callout
  end
end
