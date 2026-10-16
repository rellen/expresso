defmodule Expresso.StatElementTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Stat

  doctest Stat

  defp render(stat) do
    [Builder.slide("s", elements: [stat])]
    |> Builder.deck(name: "stats")
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
    |> LazyHTML.query(".screen figure.stat")
    |> Enum.to_list()
  end

  # The texts of the number of the one figure.
  defp numbers(stat) do
    [figure] = render(stat)
    texts(figure, ".stat-number")
  end

  test "a stat is a figure with the number, its prefix and suffix, and the label" do
    [figure] = render(Builder.stat(4.2, prefix: "$", suffix: "M", label: "revenue"))

    assert texts(figure, ".stat-prefix") == ["$"]
    assert texts(figure, ".stat-number") == ["4.2"]
    assert texts(figure, ".stat-suffix") == ["M"]
    assert texts(figure, "figcaption.stat-label") == ["revenue"]
  end

  test "a screen reader reads the whole value from a hidden text, and not the number that counts" do
    [figure] = render(Builder.stat(1250, prefix: "$", count: true))

    assert count(figure, ".stat-value > span[aria-hidden=true] .stat-number") == 1
    assert texts(figure, ".stat-text") == ["$1,250"]
  end

  test "the digits have a comma in each group of three, and the decimals come from the value" do
    assert numbers(Builder.stat(1_234_567)) == ["1,234,567"]
    assert numbers(Builder.stat(1_234_567, group: false)) == ["1234567"]
    assert numbers(Builder.stat(99.95)) == ["99.95"]
    assert numbers(Builder.stat(12, decimals: 2)) == ["12.00"]
  end

  test "count gives the number the class stat-count, the values of the count and its format" do
    [figure] = render(Builder.stat(1250, count: true, from: 900))
    [number] = LazyHTML.query(figure, ".stat-number") |> Enum.to_list()

    assert LazyHTML.attribute(number, "class") == ["stat-number stat-count"]
    assert LazyHTML.attribute(number, "style") == ["--stat-from: 900; --stat-to: 1250;"]
    assert LazyHTML.attribute(number, "data-decimals") == ["0"]
    assert LazyHTML.attribute(number, "data-group") == ["true"]

    [still] = render(Builder.stat(1250))

    assert still |> LazyHTML.query(".stat-number") |> LazyHTML.attribute("class") == [
             "stat-number"
           ]
  end

  test "count gives the texts of the number at rest, with each digit, one time each" do
    texts = fn stat ->
      [figure] = render(stat)
      figure |> LazyHTML.query(".stat-number") |> LazyHTML.attribute("data-texts")
    end

    assert texts.(Builder.stat(1_234_567, count: true, from: 5)) == [~s(["5","1,234,567"])]
    assert texts.(Builder.stat(12_345.67, count: true)) == [~s(["0.00","12,345.67"])]
    assert texts.(Builder.stat(1250, count: true, from: 1250)) == [~s(["1,250"])]

    [still] = render(Builder.stat(1250))
    assert count(still, ".stat-number:not([data-texts])") == 1
  end

  test "a stat without a label has no caption, and a stat takes the overlay options" do
    [figure] = render(Builder.stat(3, at: [from: 2]))
    assert figure |> LazyHTML.filter(":not(:has(figcaption))") |> Enum.count() == 1
    assert LazyHTML.attribute(figure, "data-on") == ["2"]
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
    document = deck |> Expresso.Deck.render() |> LazyHTML.from_document()
    assert texts(document, ".screen .column .stat .stat-label") == ["orders"]
    assert texts(document, ".screen .callout .stat-number") == ["3"]
  end
end
