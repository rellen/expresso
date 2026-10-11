defmodule Expresso.IconElementTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Icon, as: IconElement

  doctest Expresso.Icon
  doctest IconElement

  defp document(slides, opts \\ []) do
    slides
    |> Builder.deck(Keyword.merge([name: "icons"], opts))
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

  defp slide(elements), do: [Builder.slide("s", elements: elements)]

  test "an icon is a figure with the SVG of a Lucide icon, its size, its color and its label" do
    document =
      document(slide([Builder.icon("rocket", label: "Launch", size: "5rem", color: :accent)]))

    [figure] = Floki.find(document, ".screen figure.icon")

    assert Floki.attribute(figure, "class") == ["icon icon-accent"]
    assert Floki.attribute(figure, "style") == ["--icon-size: 5rem;"]
    assert [svg] = Floki.find(figure, "svg.icon-svg")
    assert Floki.attribute(svg, "aria-hidden") == ["true"]
    assert Floki.attribute(svg, "stroke") == ["currentColor"]
    assert length(Floki.find(svg, "path")) == 4
    assert figure |> Floki.find("figcaption.icon-label") |> Floki.text() == "Launch"
  end

  test "an icon without a label has no caption, and the default size and color" do
    [figure] = document(slide([Builder.icon("check")])) |> Floki.find(".screen figure.icon")
    assert Floki.attribute(figure, "class") == ["icon icon-text"]
    assert Floki.attribute(figure, "style") == ["--icon-size: 3em;"]
    assert Floki.find(figure, "figcaption") == []
  end

  test ":icon:name: in a text area and in an item becomes an inline icon" do
    list =
      Builder.list(elements: [Builder.item("Ship :icon:rocket:")])

    document = document(slide([Builder.text_area(text: "A :icon:check: and :icon:check:"), list]))

    assert length(Floki.find(document, ".screen .text-area svg.icon-inline")) == 2
    assert length(Floki.find(document, ".screen .item svg.icon-inline")) == 1
    refute Floki.raw_html(document) =~ ":icon:"
  end

  @tag :tmp_dir
  test "the icons option names an SVG file of the deck, takes currentColor, and wins over Lucide",
       %{tmp_dir: tmp_dir} do
    File.cp!("test/fixtures/badge.svg", Path.join(tmp_dir, "badge.svg"))

    document =
      document(slide([Builder.icon("rocket"), Builder.text_area(text: ":icon:badge:")]),
        root: tmp_dir,
        icons: [rocket: "badge.svg", badge: "badge.svg"]
      )

    [element, inline] = Floki.find(document, ".screen svg")
    assert Floki.attribute(element, "class") == ["icon-svg"]
    assert Floki.attribute(inline, "class") == ["icon-inline"]

    html = Floki.raw_html(element)
    assert html =~ ~s(fill="currentColor")
    assert html =~ ~s(stroke="none")
    assert html =~ "stroke: currentColor"
    refute html =~ "#ff0000"
    refute html =~ ~s(width="32")
    refute html =~ "a badge"
  end

  test "a name that no icon has is an error with the names that are near" do
    assert_raise Spark.Error.DslError,
                 ~r/no icon has the name "rokcet". Names that are near: rocket/,
                 fn ->
                   document(slide([Builder.icon("rokcet")]))
                 end

    assert_raise Spark.Error.DslError, ~r/no icon has the name "nope"/, fn ->
      document(slide([Builder.text_area(text: "x :icon:nope:")]))
    end
  end

  @tag :tmp_dir
  test "a file of the icons option that is not there, or not an SVG, is an error", %{
    tmp_dir: tmp_dir
  } do
    assert_raise Spark.Error.DslError,
                 ~r/the icon "logo" of the icons option: .* cannot be read/,
                 fn ->
                   document(slide([]), root: tmp_dir, icons: [logo: "missing.svg"])
                 end

    File.write!(Path.join(tmp_dir, "text.svg"), "no svg here")

    assert_raise Spark.Error.DslError, ~r/has no svg element/, fn ->
      document(slide([]), root: tmp_dir, icons: [logo: "text.svg"])
    end
  end

  test "the compiler refuses a color that is not a role" do
    assert_raise ArgumentError, ~r/color/, fn -> Builder.icon("check", color: :red) end
  end

  test "the DSL writes an icon in a column, in a callout and with the overlay options" do
    defmodule Deck do
      use Expresso

      slide "s" do
        columns do
          column do
            icon "rocket" do
              label "Launch"
              at from: 2
            end
          end
        end

        callout :tip do
          icon("lightbulb")
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(Deck)
    document = deck |> Expresso.Deck.render() |> Floki.parse_document!()

    assert document |> Floki.find(".screen .column figure.icon") |> Floki.attribute("data-on") ==
             ["2"]

    assert length(Floki.find(document, ".screen .callout figure.icon svg")) == 1
  end
end
