defmodule Expresso.ChartWaterfallTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart.Waterfall

  doctest Waterfall

  @categories ["Start", "Sales", "Services", "Mid year", "Grants", "Interest", "Costs", "End"]
  @values [50, 40, 30, :total, 10, 20, -50, :total]

  defp cash(opts \\ [], values \\ @values, categories \\ @categories) do
    Builder.chart(
      :waterfall,
      [title: "Cash", categories: categories, elements: [Builder.series("Cash", values)]] ++
        opts
    )
  end

  defp figure(chart) do
    [figure] = chart |> one_slide() |> document() |> screen("figure.chart") |> Enum.to_list()
    figure
  end

  # The message of the error of a chart that the check refuses.
  defp error(build) do
    error = assert_raise ArgumentError, build
    String.replace_prefix(Exception.message(error), "chart: ", "")
  end

  # The place and the size of each column from its style: the values of
  # `--chart-u`, `--chart-v`, `--chart-w` and `--chart-h`.
  defp boxes(figure) do
    for style <-
          figure |> LazyHTML.query("rect.chart-waterfall-bar") |> LazyHTML.attribute("style") do
      for name <- ~w(u v w h), into: %{} do
        [value] = Regex.run(~r/--chart-#{name}: ([-\d.]+);/, style, capture: :all_but_first)
        {String.to_atom(name), elem(Float.parse(value), 0)}
      end
    end
  end

  test "a waterfall chart draws one column for each category, the axis and a table" do
    figure = figure(cash())

    assert LazyHTML.attribute(figure, "class") == ["chart chart-waterfall"]
    assert count(figure, "rect.chart-waterfall-bar") == 8
    assert count(figure, "rect.chart-waterfall-total") == 3
    assert count(figure, "rect.chart-waterfall-up") == 4
    assert count(figure, "rect.chart-waterfall-down") == 1
    assert texts(figure, ".chart-category") == @categories
    assert texts(figure, ".chart-tick") == ~w(0 50 100 150)

    assert texts(figure, "table.chart-table thead th") == ["Change", "Total"]

    rows =
      for row <- LazyHTML.query(figure, "table.chart-table tbody tr"), do: texts(row, "th, td")

    assert rows == [
             ["Start", "", "50"],
             ["Sales", "+40", "90"],
             ["Services", "+30", "120"],
             ["Mid year", "", "120"],
             ["Grants", "+10", "130"],
             ["Interest", "+20", "150"],
             ["Costs", "-50", "100"],
             ["End", "", "100"]
           ]
  end

  test "a change starts at the running total before it, and a total starts at zero" do
    [start, sales, services, middle, _grants, interest, costs, last] = boxes(figure(cash()))
    bottom = start.v + start.h

    # The start goes up from zero, and the next change starts at its top.
    assert_in_delta sales.v + sales.h, start.v, 0.2
    assert_in_delta services.v + services.h, sales.v, 0.2

    # A total stands on the base line, and its top is the running total.
    assert_in_delta middle.v + middle.h, bottom, 0.2
    assert_in_delta middle.v, services.v, 0.2

    # A decrease goes down from the running total before it.
    assert_in_delta costs.v, interest.v, 0.2
    assert_in_delta last.v, costs.v + costs.h, 0.2
    assert_in_delta last.v + last.h, bottom, 0.2

    # Each column has the same width, and the columns go from left to right.
    assert Enum.uniq(Enum.map([start, sales, last], & &1.w)) |> length() == 1
    assert start.u < sales.u and sales.u < last.u

    # The height of a column is in proportion to its change: 40 and 50 units.
    assert_in_delta sales.h / start.h, 40 / 50, 0.01
    assert_in_delta costs.h / start.h, 50 / 50, 0.01
  end

  test "a total shows its value, and a change shows its sign and its running total" do
    figure = figure(cash())

    assert texts(figure, ".chart-value") == ["50", "120", "100"]
    assert texts(figure, ".chart-waterfall-change") == ~w(+40 +30 +10 +20 -50)
    assert texts(figure, ".chart-running") == ~w(90 120 130 150 100)
  end

  test "the text of a short change goes over its column" do
    figure = figure(cash([], [500, 4, -300, :total], ["Start", "Small", "Large", "End"]))

    assert texts(figure, ".chart-waterfall-change") == ["-300"]
    assert texts(figure, ".chart-value") == ["500", "+4", "204"]
  end

  test "a dashed line joins the end of each column to the start of the next column" do
    figure = figure(cash())
    assert count(figure, "line.chart-waterfall-line") == 7
  end

  test "values false removes the labels" do
    figure = figure(cash(values: false))

    assert count(figure, ".chart-value, .chart-running, .chart-waterfall-change") == 0
    assert count(figure, "rect.chart-waterfall-bar") == 8
  end

  test "a total with a value agrees with the sum before it" do
    values = [50, 40, 30, {:total, 120}, 10, 20, -50, {:total, 100}]
    assert texts(figure(cash([], values)), ".chart-value") == ["50", "120", "100"]

    assert error(fn -> cash([], [50, 40, 30, {:total, 125}, 10, 20, -50, :total]) end) ==
             "the total \"Mid year\" of the series \"Cash\" is 125, and the sum of the " <>
               "values before it is 120"
  end

  test "a total agrees at the most decimals of the values" do
    assert figure(cash([], [0.1, 0.2, {:total, 0.3}], ~w(a b c))) |> count("rect") == 3

    assert error(fn -> cash([], [119.5, {:total, 120}], ~w(a b)) end) =~
             "is 120, and the sum of the values before it is 119.5"
  end

  test "value_range cuts the axis, and a break mark shows the cut" do
    values = [900, 60, -30, 40, :total]
    categories = ["Start", "Up", "Down", "Up again", "End"]
    figure = figure(cash([value_range: {800, 1000}], values, categories))

    assert texts(figure, ".chart-tick") == ~w(800 850 900 950 1000)
    assert count(figure, ".chart-axis path.chart-break") == 1
    assert count(figure, "path.chart-break") == 3

    # A total stands on the base of the cut axis.
    [start | _rest] = boxes(figure)
    assert_in_delta start.h / (start.v + start.h - 28), 100 / 200, 0.02
  end

  test "an axis that holds zero has no break mark" do
    assert count(figure(cash()), "path.chart-break") == 0
  end

  test "a negative total goes down from zero" do
    figure = figure(cash([], [-20, 50, :total], ~w(Start Up End)))
    [start, up, last] = boxes(figure)

    assert_in_delta start.v + start.h, up.v + up.h, 0.2
    assert last.v < start.v
    assert texts(figure, ".chart-tick") |> hd() == "-20"
  end

  test "a highlight puts a group of columns in focus" do
    chart = cash(highlight: ["Costs"])
    figure = figure(chart)

    assert figure |> LazyHTML.query("rect[data-keys=\"c7\"]") |> Enum.count() == 1
  end

  test "the compiler refuses a waterfall chart with an error in its data" do
    two = [Builder.series("A", [1, 2]), Builder.series("B", [3, 4])]

    assert error(fn ->
             Builder.chart(:waterfall, title: "Two", categories: ~w(a b), elements: two)
           end) ==
             "a waterfall chart has one series, and this chart has 2. Put each change " <>
               "into one series, in the order of the categories."

    assert error(fn -> cash([], [1, 2]) end) ==
             "the series \"Cash\" needs 8 values, one for each category"

    assert error(fn -> cash([], [:total, 1], ~w(a b)) end) ==
             "the first value of the series \"Cash\" is the start of the waterfall, so it " <>
               "is a number"

    assert error(fn -> cash(sort: true) end) ==
             "the sort option puts the bars of a bar chart in order, so a waterfall chart " <>
               "takes no sort option"

    assert error(fn -> cash(value_range: {100, 50}) end) =~
             "gives the low end and then the high end"

    assert error(fn -> cash(value_range: {0, 140}) end) ==
             "the column \"Interest\" reaches 150, and the value_range option is {0, 140}"
  end

  test "the other kinds refuse value_range and the mark of a total" do
    series = [Builder.series("A", [1, :total])]

    assert error(fn ->
             Builder.chart(:bar, title: "Bar", categories: ~w(a b), elements: series)
           end) == "the series \"A\" needs 2 numbers, one for each category"

    assert error(fn ->
             Builder.chart(:bar,
               title: "Bar",
               categories: ~w(a),
               elements: [Builder.series("A", [1])],
               value_range: {0, 2}
             )
           end) ==
             "the value_range option is for a waterfall chart, so a bar chart takes no " <>
               "value_range option"
  end

  test "the DSL takes :total and {:total, value} in a series" do
    defmodule Deck do
      use Expresso

      slide "s" do
        chart :waterfall do
          title "Cash"
          categories ["Start", "Sales", "End"]
          series "Cash", [50, 40, {:total, 90}]
          value_range {0, 100}
        end
      end
    end

    [figure] = Deck |> document() |> screen("figure.chart") |> Enum.to_list()
    assert count(figure, "rect.chart-waterfall-total") == 2
    assert texts(figure, ".chart-value") == ["50", "90"]
  end
end
