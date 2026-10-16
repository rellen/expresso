defmodule Expresso.ShapeElementTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Shape

  doctest Shape

  defp document(elements) do
    [Builder.slide("s", elements: elements)]
    |> Builder.deck(name: "shapes")
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
  end

  defp box(kind, opts \\ []),
    do: Builder.shape(kind, [x: "10%", y: "20%", width: "30%", height: "15%"] ++ opts)

  test "the shapes of a slide go into one layer over the slide, and not in their place" do
    html =
      document([
        Builder.text_box(elements: [Builder.text_area(text: "Text")]),
        box(:rect),
        Builder.shape(:arrow, from: ["5%", "50%"], to: ["40%", "60%"])
      ])

    [layer] = LazyHTML.query(html, ".screen section.slide > .shapes") |> Enum.to_list()

    assert layer |> LazyHTML.child_nodes() |> LazyHTML.to_tree() |> Enum.map(&elem(&1, 0)) ==
             ["div", "svg"]

    assert count(html, ".screen .text-box:not(:has(.shape))") == 1
    assert count(html, ".handout-page > .shapes") == 1
    assert count(html, ".menu-thumb > .shapes") == 1
  end

  test "a rectangle and an ellipse are a box at their place, with a text and a fill" do
    [rect, ellipse] =
      [box(:rect, text: "A note", fill: true), box(:ellipse)]
      |> document()
      |> LazyHTML.query(".screen .shape")
      |> Enum.to_list()

    assert LazyHTML.attribute(rect, "class") == ["shape shape-rect"]
    assert LazyHTML.attribute(rect, "style") == ["left: 10%; top: 20%; width: 30%; height: 15%"]
    assert LazyHTML.attribute(rect, "data-fill") == ["data-fill"]
    assert LazyHTML.text(rect) == "A note"

    assert LazyHTML.attribute(ellipse, "class") == ["shape shape-ellipse"]
    assert LazyHTML.attribute(ellipse, "data-fill") == []
  end

  test "a line goes from point to point, and an arrow has a head with an id of its own in each copy" do
    html =
      document([
        Builder.shape(:line, from: ["5%", "50%"], to: ["40%", "60%"]),
        Builder.shape(:arrow, from: ["5%", "50%"], to: ["40%", "60%"])
      ])

    [line, arrow] = LazyHTML.query(html, ".screen svg.shape") |> Enum.to_list()

    assert [{"line", attributes, []}] = line |> LazyHTML.query("line") |> LazyHTML.to_tree()

    assert Map.new(attributes) |> Map.take(~w(x1 y1 x2 y2)) ==
             %{"x1" => "5%", "y1" => "50%", "x2" => "40%", "y2" => "60%"}

    assert line |> LazyHTML.filter(":not(:has(marker))") |> Enum.count() == 1

    [id] = arrow |> LazyHTML.query("marker") |> LazyHTML.attribute("id")
    assert LazyHTML.query(arrow, "line") |> LazyHTML.attribute("marker-end") == ["url(##{id})"]

    ids = html |> LazyHTML.query("svg.shape-line marker") |> LazyHTML.attribute("id")
    assert length(ids) > 1
    assert Enum.uniq(ids) == ids
  end

  test "a shape takes the overlay options" do
    [rect] =
      [box(:rect, at: [from: 2], class: "note")]
      |> document()
      |> LazyHTML.query(".screen .shape")
      |> Enum.to_list()

    assert LazyHTML.attribute(rect, "data-on") == ["2"]
    assert LazyHTML.attribute(rect, "class") == ["shape shape-rect note"]
  end

  test "the compiler refuses a shape without the options of its kind" do
    assert_raise ArgumentError, ~r/needs the option x/, fn -> Builder.shape(:rect) end
    assert_raise ArgumentError, ~r/needs the options from and to/, fn -> Builder.shape(:arrow) end

    assert_raise ArgumentError, ~r/not from and to/, fn ->
      box(:ellipse, from: ["0%", "0%"])
    end

    assert_raise ArgumentError, ~r/not x, y, width, height, text or fill/, fn ->
      Builder.shape(:line, from: ["0%", "0%"], to: ["1%", "1%"], text: "x")
    end

    assert_raise ArgumentError, ~r/kind/, fn -> Builder.shape(:star) end
    assert_raise ArgumentError, ~r/a point/, fn -> Builder.shape(:line, from: ["1%"]) end
  end
end
