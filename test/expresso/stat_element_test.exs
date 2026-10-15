defmodule Expresso.StatElementTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Stat

  doctest Stat

  defp render(stat) do
    [Builder.slide("s", elements: [stat])]
    |> Builder.deck(name: "stats")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find(".screen figure.stat")
  end

  test "a stat is a figure with the number, its prefix and suffix, and the label" do
    [figure] = render(Builder.stat(4.2, prefix: "$", suffix: "M", label: "revenue"))

    assert figure |> Floki.find(".stat-prefix") |> Floki.text() == "$"
    assert figure |> Floki.find(".stat-number") |> Floki.text() == "4.2"
    assert figure |> Floki.find(".stat-suffix") |> Floki.text() == "M"
    assert figure |> Floki.find("figcaption.stat-label") |> Floki.text() == "revenue"
  end

  test "a screen reader reads the whole value from a hidden text, and not the number that counts" do
    [figure] = render(Builder.stat(1250, prefix: "$", count: true))

    assert figure |> Floki.find(".stat-value > span[aria-hidden=true] .stat-number") != []
    assert figure |> Floki.find(".stat-text") |> Floki.text() == "$1,250"
  end

  test "the digits have a comma in each group of three, and the decimals come from the value" do
    assert render(Builder.stat(1_234_567)) |> Floki.find(".stat-number") |> Floki.text() ==
             "1,234,567"

    assert render(Builder.stat(1_234_567, group: false))
           |> Floki.find(".stat-number")
           |> Floki.text() ==
             "1234567"

    assert render(Builder.stat(99.95)) |> Floki.find(".stat-number") |> Floki.text() == "99.95"

    assert render(Builder.stat(12, decimals: 2)) |> Floki.find(".stat-number") |> Floki.text() ==
             "12.00"
  end

  test "count gives the number the class stat-count, the values of the count and its format" do
    [figure] = render(Builder.stat(1250, count: true, from: 900))
    [number] = Floki.find(figure, ".stat-number")

    assert Floki.attribute(number, "class") == ["stat-number stat-count"]
    assert Floki.attribute(number, "style") == ["--stat-from: 900; --stat-to: 1250;"]
    assert Floki.attribute(number, "data-decimals") == ["0"]
    assert Floki.attribute(number, "data-group") == ["true"]

    [still] = render(Builder.stat(1250))
    assert still |> Floki.find(".stat-number") |> Floki.attribute("class") == ["stat-number"]
  end

  test "count gives the texts of the number at rest, with each digit, one time each" do
    texts = fn stat ->
      [figure] = render(stat)
      figure |> Floki.find(".stat-number") |> Floki.attribute("data-texts")
    end

    assert texts.(Builder.stat(1_234_567, count: true, from: 5)) == [~s(["5","1,234,567"])]
    assert texts.(Builder.stat(12_345.67, count: true)) == [~s(["0.00","12,345.67"])]
    assert texts.(Builder.stat(1250, count: true, from: 1250)) == [~s(["1,250"])]
    assert texts.(Builder.stat(1250)) == []
  end

  test "a stat without a label has no caption, and a stat takes the overlay options" do
    [figure] = render(Builder.stat(3, at: [from: 2]))
    assert Floki.find(figure, "figcaption") == []
    assert Floki.attribute(figure, "data-on") == ["2"]
  end

  test "the compiler refuses a value that is not a number" do
    assert_raise ArgumentError, ~r/value/, fn -> Builder.stat("1,250") end
    assert_raise ArgumentError, ~r/decimals/, fn -> Builder.stat(1, decimals: -1) end
  end

  test "the DSL writes a stat with its options in the block, in a column and in a callout" do
    defmodule Deck do
      use Expresso

      slide "s" do
        columns do
          column do
            stat 1250 do
              label "orders"
              count true
            end
          end
        end

        callout :note do
          stat 3
        end
      end
    end

    assert {:ok, deck} = Expresso.to_deck(Deck)
    document = deck |> Expresso.Deck.render() |> Floki.parse_document!()
    assert document |> Floki.find(".screen .column .stat .stat-label") |> Floki.text() == "orders"
    assert document |> Floki.find(".screen .callout .stat-number") |> Floki.text() == "3"
  end
end
