defmodule Expresso.MorphTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder

  doctest Expresso.Morph

  defp render_slides(slides, opts \\ []) do
    slides
    |> Builder.deck(Keyword.merge([name: "morph"], opts))
    |> document()
  end

  defp modes(document) do
    document
    |> screen("section.slide")
    |> Enum.flat_map(&LazyHTML.attribute(&1, "data-morph"))
  end

  test "each slide has the morph of the deck, :auto by default, and a slide replaces it" do
    slides = [Builder.slide("a"), Builder.slide("b", morph: :off), Builder.slide("c")]

    assert modes(render_slides(slides)) == ["auto", "off", "auto"]
    assert modes(render_slides(slides, morph: :named)) == ["named", "off", "named"]
  end

  test "the morph option of an element gives its key, on each kind" do
    document =
      render_slides([
        Builder.slide("a",
          elements: [
            Builder.text_area(text: "Expresso", morph: "brand"),
            Builder.stat(3, morph: "count"),
            Builder.text_area(text: "No key")
          ]
        )
      ])

    keys =
      document
      |> screen("[data-morph-key]")
      |> Enum.flat_map(&LazyHTML.attribute(&1, "data-morph-key"))

    assert keys == ["brand", "count"]
  end

  test "the compiler refuses a mode that is not :auto, :named or :off" do
    assert_raise ArgumentError, ~r/morph/, fn -> Builder.slide("a", morph: :fade) end
    assert_raise ArgumentError, ~r/morph/, fn -> Builder.deck([], name: "x", morph: true) end
  end

  test "the DSL takes the morph of the deck, of a slide and of an element" do
    defmodule Deck do
      use Expresso

      morph :named

      slide "a" do
        text_area(text: "Expresso", morph: "brand")
      end

      slide "b" do
        morph :auto

        text_area do
          text "Expresso"
          morph "brand"
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(Deck)
    document = document(deck)
    assert modes(document) == ["named", "auto"]
    assert count(document, ~s(.screen [data-morph-key="brand"])) == 2
  end

  @poster "examples/animations/clip.png"

  # The signature of the element with a class on each slide, in the present
  # view.
  defp signatures(slides, class) do
    slides
    |> render_slides()
    |> screen(".#{class}")
    |> Enum.map(&(&1 |> LazyHTML.attribute("data-morph-signature") |> List.first()))
  end

  # A slide for each element.
  defp slides(elements) do
    for {element, index} <- Enum.with_index(elements),
        do: Builder.slide("s#{index}", elements: [element])
  end

  test "two elements with the same text get the same signature, and a different text a different one" do
    [first, second, third] =
      [
        Builder.text_area(text: "A <em>box</em>"),
        Builder.text_area(text: "A   <strong>box</strong>"),
        Builder.text_area(text: "A crate")
      ]
      |> slides()
      |> signatures("text-area")

    assert first == second
    assert first != third
  end

  test "the kind is part of the signature" do
    [text] =
      signatures([Builder.slide("one", elements: [Builder.text_area(text: "cups")])], "text-area")

    [stat] =
      signatures([Builder.slide("one", elements: [Builder.stat(1, label: "cups")])], "stat")

    assert text != stat
  end

  test "a kind without a content and an element with a morph key get no signature" do
    assert [nil] =
             [
               Builder.slide("one",
                 elements: [Builder.text_box(elements: [Builder.text_area(text: "a")])]
               )
             ]
             |> signatures("text-box")

    assert [nil] =
             [Builder.slide("one", elements: [Builder.text_area(text: "a", morph: "key")])]
             |> signatures("text-area")
  end

  test "a video and a sound compare their file, and not their poster or title" do
    [clip, run, again] =
      [
        Builder.video("examples/animations/clip.webm", title: "a", poster: @poster),
        Builder.video("examples/line4/run.webm", title: "a", poster: @poster),
        Builder.video("examples/line4/run.webm",
          title: "b",
          poster: "examples/animations/demo.png"
        )
      ]
      |> slides()
      |> signatures("video")

    assert clip != run
    assert run == again

    [bell, chime] =
      [
        Builder.audio("examples/animations/chime.ogg", title: "a"),
        Builder.audio("examples/animations/chime.ogg", title: "b")
      ]
      |> slides()
      |> signatures("audio")

    assert bell == chime
  end

  test "an embed compares its address, and not its fallback image" do
    [first, second, other] =
      [
        Builder.embed("https://example.com/", title: "a", fallback: @poster),
        Builder.embed("https://example.com/", title: "b"),
        Builder.embed("https://example.org/", title: "a", fallback: @poster)
      ]
      |> slides()
      |> signatures("embed")

    assert first == second
    assert first != other
  end

  test "a code compares its language, a stat its label, and an icon its drawing" do
    [elixir, more_elixir, js] =
      [
        Builder.code("elixir", text: "x = 1"),
        Builder.code("elixir", text: "y = 2"),
        Builder.code("js", text: "x")
      ]
      |> slides()
      |> signatures("code")

    assert elixir == more_elixir
    assert elixir != js

    [cups, more_cups] =
      [Builder.stat(1, label: "cups"), Builder.stat(2, label: "cups")]
      |> slides()
      |> signatures("stat")

    assert cups == more_cups

    [check, danger_check, coffee] =
      [Builder.icon("check"), Builder.icon("check", color: :danger), Builder.icon("coffee")]
      |> slides()
      |> signatures("icon")

    assert check == danger_check
    assert check != coffee
  end

  @tag :tmp_dir
  test "a diagram compares its SVG, so two drawings without a text differ and two copies pair",
       %{tmp_dir: tmp_dir} do
    circle = ~s(<svg viewBox="0 0 10 10"><circle cx="5" cy="5" r="4"/></svg>)
    square = ~s(<svg viewBox="0 0 10 10"><rect width="8" height="8"/></svg>)

    for {name, svg} <- [{"circle.svg", circle}, {"square.svg", square}, {"copy.svg", circle}],
        do: File.write!(Path.join(tmp_dir, name), svg)

    File.write!(Path.join(tmp_dir, "empty.svg"), "<svg></svg>")

    [first, other, copy, empty] =
      ["circle.svg", "square.svg", "copy.svg", "empty.svg"]
      |> Enum.map(&Builder.diagram(Path.join(tmp_dir, &1)))
      |> slides()
      |> signatures("diagram")

    assert first != nil
    assert first != other
    assert first == copy
    assert empty == nil
  end

  test "a shape compares its kind and its text" do
    box = [x: "10%", y: "10%", width: "20%", height: "20%"]

    [rect, ellipse, moved, labeled] =
      [
        Builder.shape(:rect, box),
        Builder.shape(:ellipse, box),
        Builder.shape(:rect, Keyword.put(box, :x, "50%")),
        Builder.shape(:rect, Keyword.put(box, :text, "Cup"))
      ]
      |> slides()
      |> signatures("shape")

    assert rect != nil
    assert rect != ellipse
    assert rect == moved
    assert rect != labeled

    [line, arrow] =
      [
        Builder.shape(:line, from: ["5%", "5%"], to: ["50%", "50%"]),
        Builder.shape(:arrow, from: ["5%", "5%"], to: ["50%", "50%"])
      ]
      |> slides()
      |> signatures("shape")

    assert line != arrow
  end

  test "an element with an empty content gets no signature" do
    assert [nil] =
             [Builder.slide("one", elements: [Builder.text_area(text: "  ")])]
             |> signatures("text-area")
  end

  test "the heading of the default template has the signature of its text" do
    [first, second, other] =
      [
        Builder.slide("a", heading: "Coffee"),
        Builder.slide("b", heading: "Coffee"),
        Builder.slide("c", heading: "Tea")
      ]
      |> signatures("slide-heading-container")

    assert first == second
    assert first == Expresso.Morph.signature("heading", "Coffee")
    assert first != other
  end
end
