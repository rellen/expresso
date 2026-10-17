defmodule Expresso.FootnoteElementTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Footnote

  doctest Footnote

  defp render_slides(slides) do
    slides
    |> Builder.deck(name: "footnotes")
    |> document()
  end

  defp claim(text), do: Builder.text_box(elements: [Builder.text_area(text: text)])

  test "the footnotes of a slide go into one numbered list under the slide template, and not in their place" do
    html =
      render_slides([
        Builder.slide("s",
          elements: [
            claim("A claim.<sup>1</sup>"),
            Builder.footnote("The <em>first</em> source."),
            claim("A second claim.<sup>2</sup>"),
            Builder.footnote("The second source.")
          ]
        )
      ])

    [slide] = screen(html, "section.slide") |> Enum.to_list()

    assert texts(slide, "ol.footnotes li.footnote") ==
             ["The first source.", "The second source."]

    assert texts(slide, "ol.footnotes em") == ["first"]
    assert count(slide, ".text-box:not(:has(li.footnote))") == 2
    assert count(slide, ".text-box") == 2
    assert count(html, ".handout-page ol.footnotes") == 1
  end

  test "a slide with no footnote has no list" do
    html = render_slides([Builder.slide("s", elements: [claim("No source.")])])

    assert count(html, "body:not(:has(ol.footnotes))") == 1
    assert count(html, "body:not(:has(.sources))") == 1
  end

  test "a footnote takes the overlay options, and auto_reveal gives it no step of its own" do
    html =
      render_slides([
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

    [always, later] = screen(html, "li.footnote") |> Enum.to_list()

    assert LazyHTML.attribute(always, "data-on") == []
    assert LazyHTML.attribute(later, "data-on") == ["2"]

    assert html |> screen("section.slide") |> LazyHTML.attribute("data-max-step") ==
             [
               "2"
             ]
  end

  test "the handout view ends with a page of the sources of each slide" do
    html =
      render_slides([
        Builder.slide("first", heading: "Processes", elements: [Builder.footnote("Book")]),
        Builder.slide("second", elements: [claim("No source")]),
        Builder.slide("third", elements: [Builder.footnote("Docs"), Builder.footnote("Talk")])
      ])

    assert [sources] = LazyHTML.query(html, ".handout > section.sources") |> Enum.to_list()
    assert texts(sources, "h2") == ["Sources"]
    assert texts(sources, "h3") == ["1. Processes", "3. third"]

    assert sources |> LazyHTML.query("ol") |> Enum.map(&count(&1, "li")) == [1, 2]

    # The page comes after the last page of the slides and before the
    # elements of the speaker view.
    children =
      html |> LazyHTML.query(".handout > *") |> LazyHTML.to_tree() |> Enum.map(&elem(&1, 0))

    assert Enum.take(children, -5) == ["section", "div", "div", "div", "div"]
  end
end
