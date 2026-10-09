defmodule Expresso.FootnoteElementTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Footnote

  doctest Footnote

  defp document(slides) do
    slides
    |> Builder.deck(name: "footnotes")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

  defp claim(text), do: Builder.text_box(elements: [Builder.text_area(text: text)])

  test "the footnotes of a slide go into one numbered list under the slide template, and not in their place" do
    html =
      document([
        Builder.slide("s",
          elements: [
            claim("A claim.<sup>1</sup>"),
            Builder.footnote("The <em>first</em> source."),
            Builder.text_box(elements: [Builder.footnote("The second source.")])
          ]
        )
      ])

    [slide] = Floki.find(html, ".screen section.slide")

    assert slide |> Floki.find("ol.footnotes li.footnote") |> Enum.map(&Floki.text/1) ==
             ["The first source.", "The second source."]

    assert slide |> Floki.find("ol.footnotes em") |> Floki.text() == "first"
    assert Floki.find(slide, ".text-box li.footnote") == []
    assert html |> Floki.find(".handout-page ol.footnotes") |> length() == 1
  end

  test "a slide with no footnote has no list" do
    html = document([Builder.slide("s", elements: [claim("No source.")])])

    assert Floki.find(html, "ol.footnotes") == []
    assert Floki.find(html, ".sources") == []
  end

  test "a footnote takes the overlay options, and auto_reveal gives it no step of its own" do
    html =
      document([
        Builder.slide("s",
          auto_reveal: true,
          elements: [
            claim("One"),
            claim("Two"),
            Builder.footnote("Always"),
            Builder.footnote("With two", at: [from: 2])
          ]
        )
      ])

    [always, later] = Floki.find(html, ".screen li.footnote")

    assert Floki.attribute(always, "data-on") == []
    assert Floki.attribute(later, "data-on") == ["2"]

    assert html |> Floki.find(".screen section.slide") |> Floki.attribute("data-max-step") == [
             "2"
           ]
  end

  test "the handout view ends with a page of the sources of each slide" do
    html =
      document([
        Builder.slide("first", heading: "Processes", elements: [Builder.footnote("Book")]),
        Builder.slide("second", elements: [claim("No source")]),
        Builder.slide("third", elements: [Builder.footnote("Docs"), Builder.footnote("Talk")])
      ])

    assert [sources] = Floki.find(html, ".handout > section.sources")
    assert sources |> Floki.find("h2") |> Floki.text() == "Sources"
    assert sources |> Floki.find("h3") |> Enum.map(&Floki.text/1) == ["1. Processes", "3. third"]

    assert sources |> Floki.find("ol") |> Enum.map(&(Floki.find(&1, "li") |> length())) ==
             [1, 2]

    # The page comes after the last page of the slides and before the
    # elements of the speaker view.
    children = html |> Floki.find(".handout > *") |> Enum.map(&elem(&1, 0))
    assert Enum.take(children, -5) == ["section", "div", "div", "div", "div"]
  end
end
