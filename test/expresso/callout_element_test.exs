defmodule Expresso.CalloutElementTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Callout

  doctest Callout

  defp render(elements, opts \\ []), do: elements |> one_slide(opts) |> document()

  defp text(text), do: Builder.text_area(text: text)

  test "a callout is a note with the class of its kind, a header and a body" do
    document = render(Builder.callout(:warning, elements: [text("Back up the data first.")]))
    [callout] = document |> screen(".callout") |> Enum.to_list()

    assert LazyHTML.attribute(callout, "class") == ["callout callout-warning"]
    assert LazyHTML.attribute(callout, "role") == ["note"]
    assert texts(callout, ".callout-title") == ["Warning"]
    assert callout |> LazyHTML.query(".callout-body .text-area") |> LazyHTML.text() =~ "Back up"
  end

  test "each kind has its own icon, hidden from a screen reader" do
    icons =
      for kind <- Callout.kinds() do
        [svg] =
          kind
          |> Builder.callout()
          |> render()
          |> screen(".callout-icon")
          |> Enum.to_list()

        assert LazyHTML.attribute(svg, "aria-hidden") == ["true"]
        assert LazyHTML.attribute(svg, "viewBox") == ["0 0 24 24"]
        svg |> LazyHTML.query("path") |> LazyHTML.attribute("d")
      end

    assert length(Enum.uniq(icons)) == length(Callout.kinds())
  end

  test "the title option replaces the name of the kind, and title false removes the header" do
    titled = render(Builder.callout(:definition, title: "Release", elements: [text("x")]))
    assert texts(titled, ".screen .callout-title") == ["Release"]

    bare = render(Builder.callout(:tip, title: false, elements: [text("x")]))
    assert count(bare, ".screen .callout:not(:has(.callout-title))") == 1
    assert count(bare, ".screen .callout-body .text-area") == 1
  end

  test "the title is text, and not HTML" do
    document = render(Builder.callout(:note, title: "<b>Bold</b>"))
    assert texts(document, ".screen .callout-title") == ["<b>Bold</b>"]
    assert count(document, ".screen .callout-title:not(:has(b))") == 1
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

    deck = one_slide(callout)
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
    assert count(document, ".screen .text-box .callout-note") == 1
    assert count(document, ".screen .column .callout-caution") == 1
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
