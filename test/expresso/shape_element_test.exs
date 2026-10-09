defmodule Expresso.ShapeElementTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Shape

  doctest Shape

  defp document(elements) do
    [Builder.slide("s", elements: elements)]
    |> Builder.deck(name: "shapes")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

  defp box(kind, opts \\ []),
    do: Builder.shape(kind, [x: "10%", y: "20%", width: "30%", height: "15%"] ++ opts)

  test "the shapes of a slide go into one layer over the slide, and not in their place" do
    html =
      document([
        Builder.text_box(elements: [Builder.text_area(text: "Text"), box(:rect)]),
        Builder.shape(:arrow, from: ["5%", "50%"], to: ["40%", "60%"])
      ])

    [layer] = Floki.find(html, ".screen section.slide > .shapes")

    assert layer |> Floki.children() |> Enum.map(&elem(&1, 0)) == ["div", "svg"]
    assert Floki.find(html, ".screen .text-box .shape") == []
    assert html |> Floki.find(".handout-page > .shapes") |> length() == 1
    assert html |> Floki.find(".menu-thumb > .shapes") |> length() == 1
  end

  test "a rectangle and an ellipse are a box at their place, with a text and a fill" do
    [rect, ellipse] =
      [box(:rect, text: "A note", fill: true), box(:ellipse)]
      |> document()
      |> Floki.find(".screen .shape")

    assert Floki.attribute(rect, "class") == ["shape shape-rect"]
    assert Floki.attribute(rect, "style") == ["left: 10%; top: 20%; width: 30%; height: 15%"]
    assert Floki.attribute(rect, "data-fill") == ["data-fill"]
    assert Floki.text(rect) == "A note"

    assert Floki.attribute(ellipse, "class") == ["shape shape-ellipse"]
    assert Floki.attribute(ellipse, "data-fill") == []
  end

  test "a line goes from point to point, and an arrow has a head with an id of its own in each copy" do
    html =
      document([
        Builder.shape(:line, from: ["5%", "50%"], to: ["40%", "60%"]),
        Builder.shape(:arrow, from: ["5%", "50%"], to: ["40%", "60%"])
      ])

    [line, arrow] = Floki.find(html, ".screen svg.shape")

    assert [{"line", attributes, []}] = Floki.find(line, "line")

    assert Map.new(attributes) |> Map.take(~w(x1 y1 x2 y2)) ==
             %{"x1" => "5%", "y1" => "50%", "x2" => "40%", "y2" => "60%"}

    assert Floki.find(line, "marker") == []

    [id] = arrow |> Floki.find("marker") |> Floki.attribute("id")
    assert Floki.find(arrow, "line") |> Floki.attribute("marker-end") == ["url(##{id})"]

    ids = html |> Floki.find("svg.shape-line marker") |> Enum.flat_map(&Floki.attribute(&1, "id"))
    assert length(ids) == length(Enum.uniq(ids))
  end

  test "a shape takes the overlay options" do
    [rect] =
      [box(:rect, at: [from: 2], class: "note")] |> document() |> Floki.find(".screen .shape")

    assert Floki.attribute(rect, "data-on") == ["2"]
    assert Floki.attribute(rect, "class") == ["shape shape-rect note"]
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
