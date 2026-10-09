defmodule Expresso.QrCodeElementTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.QrCode

  doctest QrCode

  @address "https://rellen.github.io/expresso/"

  defp render(element) do
    [Builder.slide("s", elements: [element])]
    |> Builder.deck(name: "qr")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find(".screen .qr-code")
  end

  # The dark modules of a path, as {x, y} pairs.
  defp modules(path) do
    for [x, y, w] <- Regex.scan(~r/M(\d+) (\d+)h(\d+)/, path, capture: :all_but_first),
        [x, y, w] = Enum.map([x, y, w], &String.to_integer/1),
        dx <- 0..(w - 1),
        do: {x + dx, y}
  end

  test "is a figure with one SVG, a light square and the path of the dark modules" do
    [figure] = render(Builder.qr_code(@address))
    {path, side} = QrCode.path(@address, :m)

    assert [svg] = Floki.find(figure, "svg")
    assert Floki.attribute(svg, "viewbox") == ["0 0 #{side} #{side}"]
    assert Floki.attribute(svg, "role") == ["img"]
    assert Floki.attribute(svg, "aria-label") == [@address]
    assert figure |> Floki.find("rect.qr-background") |> Floki.attribute("width") == ["#{side}"]
    assert figure |> Floki.find("path.qr-modules") |> Floki.attribute("d") == [path]
    assert Floki.find(figure, "figcaption") == []
  end

  test "the path holds the modules of the matrix of EQRCode, inside a quiet zone of four modules" do
    {path, side} = QrCode.path(@address, :m)
    %EQRCode.Matrix{matrix: matrix} = EQRCode.encode(@address, :m)

    # EQRCode draws a quiet zone of two modules, and the element draws four.
    expected =
      for {row, y} <- matrix |> Tuple.to_list() |> Enum.with_index(2),
          {1, x} <- row |> Tuple.to_list() |> Enum.with_index(2),
          do: {x, y}

    assert side == tuple_size(matrix) + 4
    assert Enum.sort(modules(path)) == Enum.sort(expected)

    for {x, y} <- modules(path) do
      assert x >= 4 and y >= 4 and x < side - 4 and y < side - 4
    end
  end

  test "the label goes under the code, and the title replaces the text for a screen reader" do
    [figure] = render(Builder.qr_code(@address, label: "The slides", title: "The address"))

    assert figure |> Floki.find("figcaption") |> Floki.text() == "The slides"
    assert figure |> Floki.find("svg") |> Floki.attribute("aria-label") == ["The address"]
  end

  test "the size goes into --qr-size, and a percentage becomes a part of the width of the slide" do
    [figure] = render(Builder.qr_code(@address, size: "30%"))
    assert Floki.attribute(figure, "style") == ["--qr-size: 30vw"]

    [figure] = render(Builder.qr_code(@address, size: "300px"))
    assert Floki.attribute(figure, "style") == ["--qr-size: 300px"]
  end

  test "a higher level makes a code with more modules" do
    {_path, low} = QrCode.path(@address, :l)
    {_path, high} = QrCode.path(@address, :h)

    assert high > low
  end

  test "the compiler refuses a level that is not of the standard" do
    assert_raise ArgumentError, ~r/level/, fn ->
      Builder.qr_code(@address, level: :x)
    end
  end

  test "the overlay options apply to the code" do
    [figure] = render(Builder.qr_code(@address, at: [from: 2], class: "big"))

    assert Floki.attribute(figure, "class") == ["qr-code big"]
    assert Floki.attribute(figure, "data-on") == ["2"]
  end
end
