defmodule Expresso.IconElementTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Icon, as: IconElement

  doctest Expresso.Icon
  doctest IconElement

  defp document(slides, opts \\ []) do
    slides
    |> Builder.deck(Keyword.merge([name: "icons"], opts))
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
  end

  defp slide(elements), do: [Builder.slide("s", elements: elements)]

  test "an icon is a figure with the SVG of a Lucide icon, its size, its color and its label" do
    document =
      document(slide([Builder.icon("rocket", label: "Launch", size: "5rem", color: :accent)]))

    [figure] = document |> LazyHTML.query(".screen figure.icon") |> Enum.to_list()

    assert LazyHTML.attribute(figure, "class") == ["icon icon-accent"]
    assert LazyHTML.attribute(figure, "style") == ["--icon-size: 5rem;"]
    assert [svg] = figure |> LazyHTML.query("svg.icon-svg") |> Enum.to_list()
    assert LazyHTML.attribute(svg, "aria-hidden") == ["true"]
    assert LazyHTML.attribute(svg, "stroke") == ["currentColor"]
    assert count(svg, "path") == 4
    assert texts(figure, "figcaption.icon-label") == ["Launch"]
  end

  test "an icon without a label has no caption, and the default size and color" do
    [figure] =
      [Builder.icon("check")]
      |> slide()
      |> document()
      |> LazyHTML.query(".screen figure.icon")
      |> Enum.to_list()

    assert LazyHTML.attribute(figure, "class") == ["icon icon-text"]
    assert LazyHTML.attribute(figure, "style") == ["--icon-size: 3em;"]
    assert figure |> LazyHTML.filter(":not(:has(figcaption))") |> Enum.count() == 1
  end

  test ":icon:name: in a text area and in an item becomes an inline icon" do
    list =
      Builder.list(elements: [Builder.item("Ship :icon:rocket:")])

    document = document(slide([Builder.text_area(text: "A :icon:check: and :icon:check:"), list]))

    assert count(document, ".screen .text-area svg.icon-inline") == 2
    assert count(document, ".screen .item svg.icon-inline") == 1
    refute LazyHTML.to_html(document) =~ ":icon:"
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

    [element, inline] = document |> LazyHTML.query(".screen svg") |> Enum.to_list()
    assert LazyHTML.attribute(element, "class") == ["icon-svg"]
    assert LazyHTML.attribute(inline, "class") == ["icon-inline"]

    html = LazyHTML.to_html(element)
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
    document = deck |> Expresso.Deck.render() |> LazyHTML.from_document()

    assert document
           |> LazyHTML.query(".screen .column figure.icon")
           |> LazyHTML.attribute("data-on") == ["2"]

    assert count(document, ".screen .callout figure.icon svg") == 1
  end
end
