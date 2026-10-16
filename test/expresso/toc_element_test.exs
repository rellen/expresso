defmodule Expresso.TocElementTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.{Toc, TocEntry}

  doctest Toc
  doctest Expresso.SectionTransformer

  # A deck with a slide before the first section, then three sections. The
  # second section has two slides.
  defp deck(toc_slide, toc) do
    [
      Builder.slide("intro"),
      Builder.slide("why", section: "Why"),
      Builder.slide("how", section: "How"),
      Builder.slide("how more"),
      Builder.slide("end", section: "End")
    ]
    |> List.update_at(toc_slide - 1, &%{&1 | elements: [toc]})
    |> Builder.deck(name: "sections")
  end

  defp render(deck) do
    deck
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
  end

  defp entries(document, slide) do
    for li <- LazyHTML.query(document, "#slide-#{slide} .toc-entry") do
      {LazyHTML.text(li), li |> LazyHTML.attribute("class") |> hd(),
       li |> LazyHTML.attribute("aria-current") |> List.first()}
    end
  end

  test "a toc lists each section, with a link to its first slide" do
    deck = deck(1, Builder.toc())
    [%{elements: [toc]} | _] = deck.slides

    assert [%TocEntry{text: "Why"}, %TocEntry{text: "How"}, %TocEntry{text: "End"}] =
             toc.elements

    document = render(deck)
    links = LazyHTML.query(document, "#slide-1 .toc a.goto")

    assert LazyHTML.attribute(links, "href") == ["#2.1", "#3.1", "#5.1"]
    assert Enum.all?(LazyHTML.attribute(links, "data-commands"), &(&1 =~ "goto"))

    assert document |> LazyHTML.query("#slide-1 nav.toc") |> LazyHTML.attribute("aria-label") == [
             "Contents"
           ]
  end

  test "a toc before the first section marks no entry" do
    document = render(deck(1, Builder.toc()))

    assert entries(document, 1) == [
             {"Why", "toc-entry toc-none", nil},
             {"How", "toc-entry toc-none", nil},
             {"End", "toc-entry toc-none", nil}
           ]
  end

  test "the section of the slide of a toc is the current entry, also on a later slide of the section" do
    for slide <- [3, 4] do
      document = render(deck(slide, Builder.toc()))

      assert entries(document, slide) == [
               {"Why", "toc-entry toc-earlier", nil},
               {"How", "toc-entry toc-current", "location"},
               {"End", "toc-entry toc-later", nil}
             ]
    end
  end

  test "the progress option gives the toc a class" do
    for progress <- Toc.progress_values() do
      class = progress |> Atom.to_string() |> String.replace("_", "-")
      document = render(deck(3, Builder.toc(progress: progress)))

      assert document |> LazyHTML.query("#slide-3 nav.toc") |> LazyHTML.attribute("class") == [
               "toc toc-#{class}"
             ]
    end

    assert_raise ArgumentError, ~r/progress/, fn -> Builder.toc(progress: :fade) end
  end

  test "reveal gives each entry its own step, and dim dims each entry when a later one shows" do
    deck = deck(1, Builder.toc(reveal: true, dim: true))
    [%{elements: [toc], metadata: metadata} | _] = deck.slides

    assert metadata.max_step == 3
    assert Enum.map(toc.elements, & &1.steps) == [[1, 2, 3], [2, 3], [3]]

    assert Enum.map(toc.elements, fn entry -> Enum.map(entry.on, & &1.steps) end) ==
             [[[2, 3]], [[3]], []]
  end

  test "without reveal, the entries show with the toc" do
    deck = deck(1, Builder.toc(at: [from: 2]))
    [%{elements: [toc], metadata: metadata} | _] = deck.slides

    assert metadata.max_step == 2
    assert toc.steps == [2]
    assert Enum.map(toc.elements, & &1.steps) == [nil, nil, nil]
  end

  test "a text box, a column and the DSL hold a toc" do
    defmodule Deck do
      use Expresso

      slide "contents" do
        text_box do
          toc()
        end

        columns do
          column do
            toc do
              reveal true
            end
          end
        end
      end

      slide "one" do
        section "One"
      end
    end

    document = Deck |> Expresso.to_deck() |> elem(1) |> render()
    assert texts(document, "#slide-1 .text-box .toc-entry") == ["One"]
    assert texts(document, "#slide-1 .column .toc-entry") == ["One"]
  end

  test "each slide gets the title of its section in its metadata" do
    deck = deck(1, Builder.toc())
    sections = Enum.map(deck.slides, &Map.get(&1.metadata, :section))
    assert sections == [nil, "Why", "How", "How", "End"]
  end

  test "a toc in a deck without a section is an error" do
    assert_raise Spark.Error.DslError,
                 ~r/a toc lists the sections of the deck, and no slide has the section option/,
                 fn ->
                   Builder.deck([Builder.slide("contents", elements: [Builder.toc()])], name: "x")
                 end
  end

  test "the title of a section is text, and not HTML" do
    deck =
      Builder.deck(
        [
          Builder.slide("contents", elements: [Builder.toc()]),
          Builder.slide("a", section: "<b>A</b>")
        ],
        name: "x"
      )

    document = render(deck)
    assert texts(document, "#slide-1 .toc-link") == ["<b>A</b>"]
    assert count(document, "#slide-1 .toc-link:not(:has(b))") == 1
  end
end
