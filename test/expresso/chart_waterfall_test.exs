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

  test "a highlight puts a group of columns in focus, with their labels and connectors" do
    figure = figure(cash(highlight: ["Costs", ["Mid year", "End"]]))
    costs = LazyHTML.query(figure, "[data-keys=\"c7\"]")

    # The column, its connector, its two labels and its category.
    assert count(costs, "rect.chart-waterfall-down") == 1
    assert count(costs, "line.chart-waterfall-line") == 1
    assert texts(costs, "text") |> Enum.sort() == Enum.sort(["-50", "100", "Costs"])

    style = cash(highlight: ["Costs"]) |> one_slide() |> document() |> LazyHTML.query("style")
    assert LazyHTML.text(style) =~ "[data-keys]:not([data-keys~=\"c7\"]) { --chart-dim: 1; }"
  end

  test "highlight takes no reveal and no dim" do
    assert error(fn -> cash(highlight: ["Costs"], reveal: true) end) =~
             "takes the reveal option or the highlight option"

    assert error(fn -> cash(highlight: ["Costs"], dim: true) end) =~ "takes no dim option"
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

  describe "the direction :horizontal" do
    test "a bar starts at the running total before it, and its length is its change" do
      [start, sales, services, middle, _grants, interest, costs, last] =
        boxes(figure(cash(direction: :horizontal)))

      left = start.u

      # The start and each total stand on zero at the left edge of the plot.
      assert_in_delta middle.u, left, 0.2
      assert_in_delta last.u, left, 0.2

      # A change starts at the end of the bar before it.
      assert_in_delta sales.u, start.u + start.w, 0.2
      assert_in_delta services.u, sales.u + sales.w, 0.2
      assert_in_delta middle.u + middle.w, services.u + services.w, 0.2

      # A decrease ends at the running total after it.
      assert_in_delta costs.u + costs.w, interest.u + interest.w, 0.2
      assert_in_delta last.u + last.w, costs.u, 0.2

      # The length of a bar is in proportion to its change, and the bars go
      # down the plot with one thickness.
      assert_in_delta sales.w / start.w, 40 / 50, 0.01
      assert_in_delta costs.w / start.w, 50 / 50, 0.01
      assert start.v < sales.v and sales.v < last.v
      assert Enum.uniq(Enum.map([start, sales, last], & &1.h)) |> length() == 1
    end

    test "the categories go down the left side, and the ticks along the bottom" do
      figure =
        figure(cash(direction: :horizontal, category_label: "Quarter", value_label: "Cash"))

      assert figure
             |> LazyHTML.query(".chart-category")
             |> LazyHTML.attribute("text-anchor")
             |> Enum.uniq() == ["end"]

      assert texts(figure, ".chart-axis-title") == ["Cash", "Quarter"]

      # A connector goes down from one bar to the next bar.
      assert figure
             |> LazyHTML.query("line.chart-waterfall-line")
             |> LazyHTML.attribute("x2")
             |> Enum.uniq() == ["0"]
    end

    test "the labels go at the end of each bar" do
      figure = figure(cash(direction: :horizontal))

      assert texts(figure, ".chart-value") == ["50", "120", "+10", "100"]
      assert texts(figure, ".chart-waterfall-change") == ~w(+40 +30 +20 -50)
      assert texts(figure, ".chart-running") == ~w(90 120 130 150 100)
    end

    test "a span goes down at the right of the bars" do
      figure = figure(cash(direction: :horizontal, spans: true))

      [path | _rest] =
        figure |> LazyHTML.query("path.chart-waterfall-span") |> LazyHTML.attribute("d")

      assert path =~ ~r/^M-8 0H0V[\d.]+H-8/
      assert texts(figure, ".chart-span-value") == ["+70", "-20"]
    end

    test "the other kinds refuse direction" do
      assert error(fn ->
               Builder.chart(:bar,
                 title: "Bar",
                 categories: ~w(a),
                 elements: [Builder.series("A", [1])],
                 direction: :horizontal
               )
             end) =~ "the direction option is for a waterfall chart"
    end
  end

  describe "the spans" do
    test "spans true draws an arrow from each total to the next, with the sum between" do
      figure = figure(cash(spans: true))

      assert count(figure, "path.chart-waterfall-span") == 2
      assert texts(figure, ".chart-span-value") == ["+70", "-20"]
    end

    test "a span leaves out two totals with no change between them" do
      figure = figure(cash([spans: true], [50, :total, 10, :total], ~w(a b c d)))
      assert texts(figure, ".chart-span-value") == ["+10"]
    end

    test "a span shows with the last change before the total at its end" do
      [_base | changes] =
        cash(spans: true, reveal: true)
        |> figure()
        |> LazyHTML.query("g.chart-series")
        |> Enum.to_list()

      assert Enum.map(changes, &texts(&1, ".chart-span-value")) == [[], ["+70"], [], [], ["-20"]]
    end

    test "a span goes over the labels of the highest column between its totals" do
      figure = figure(cash(spans: true))

      [first, second] =
        for style <-
              figure
              |> LazyHTML.query("g:has(> path.chart-waterfall-span)")
              |> LazyHTML.attribute("style") do
          [v] = Regex.run(~r/--chart-v: ([-\d.]+);/, style, capture: :all_but_first)
          elem(Float.parse(v), 0)
        end

      [_start, _sales, services, _middle, _grants, interest | _rest] = boxes(figure)
      assert first < services.v - 26
      assert second < interest.v - 26
    end

    test "the other kinds refuse spans" do
      assert error(fn ->
               Builder.chart(:bar,
                 title: "Bar",
                 categories: ~w(a),
                 elements: [Builder.series("A", [1])],
                 spans: true
               )
             end) =~ "the spans option is for a waterfall chart"
    end
  end

  describe "the steps" do
    # The text of the style block of the document of a chart.
    defp style(chart) do
      chart |> one_slide() |> document() |> LazyHTML.query("style") |> LazyHTML.text()
    end

    test "reveal gives each change its own step, and the totals show with the chart" do
      groups = cash(reveal: true) |> figure() |> LazyHTML.query("g.chart-series")

      # The first group holds the start and the totals, and it has no steps of
      # its own, so it shows with the chart. Each change is a group with its
      # own step.
      assert LazyHTML.attribute(groups, "data-on") ==
               ["2 3 4 5 6", "3 4 5 6", "4 5 6", "5 6", "6"]

      [base | changes] = Enum.to_list(groups)
      assert count(base, "rect.chart-waterfall-total") == 3
      assert Enum.map(changes, &count(&1, "rect.chart-waterfall-bar")) == [1, 1, 1, 1, 1]
    end

    test "each later total grows at the step of each change before it" do
      text = style(cash(reveal: true))

      # The total "Mid year" is column 3 and "End" is column 7. Their numbers
      # count to the running total at each step.
      for {step, middle, last} <- [{2, 90, 90}, {3, 120, 120}, {4, 120, 130}, {6, 120, 100}] do
        assert text =~
                 ~r/section\[data-step="#{step}"\] \[data-el="[^"]+"\] \{[^}]*--n3: #{middle};[^}]*--n7: #{last};/
      end

      # The first state is in the style attribute of each number.
      figure = figure(cash(reveal: true))
      assert texts(figure, ".chart-value") == ["50", "50", "50"]
      assert count(figure, "tspan.chart-count") == 2
    end

    test "totals :complete shows a total at the step of the change before it" do
      groups =
        cash(reveal: true, totals: :complete) |> figure() |> LazyHTML.query("g.chart-series")

      counts = Enum.map(groups, &count(&1, "rect.chart-waterfall-total"))

      # The start is in the first group, "Mid year" goes with "Services", and
      # "End" goes with "Costs".
      assert counts == [1, 0, 1, 0, 0, 1]

      assert texts(figure(cash(reveal: true, totals: :complete)), ".chart-value") ==
               ~w(50 120 100)

      refute style(cash(reveal: true, totals: :complete)) =~ "--n3:"
    end

    test "a connector shows with the later of its two columns" do
      [base | changes] =
        cash(reveal: true) |> figure() |> LazyHTML.query("g.chart-series") |> Enum.to_list()

      # The connectors at the left of "Sales" and of "Services" go with them,
      # and so do the connectors at the right of each change into a total.
      assert count(base, "line.chart-waterfall-line") == 0
      assert Enum.map(changes, &count(&1, "line.chart-waterfall-line")) == [1, 2, 1, 1, 2]
    end

    test "dim dims each change when a later change shows, and not the totals" do
      groups =
        cash(reveal: true, dim: true) |> one_slide() |> document() |> screen("g.chart-series")

      assert Enum.count(LazyHTML.attribute(groups, "data-el")) == 4
    end

    test "the effect :grow grows each column from its base" do
      styles =
        cash(reveal: true, effect: :grow)
        |> figure()
        |> LazyHTML.query("rect.chart-waterfall-up")
        |> LazyHTML.attribute("style")

      assert Enum.all?(
               styles,
               &(&1 =~ ~r/--chart-h: calc\(0 \+ \([\d.]+ - 0\) \* var\(--chart-shown, 1\)\);/)
             )
    end

    test "the overview shows the last state" do
      assert style(cash(reveal: true)) =~
               ~r/\.menu-thumb[^{]*\{[^}]*--n3: 120;[^}]*--n7: 100;/
    end

    test "the compiler refuses totals without reveal, and a series with steps of its own" do
      assert error(fn -> cash(totals: :complete) end) =~ "so totals :complete needs reveal true"

      assert error(fn ->
               Builder.chart(:waterfall,
                 title: "Cash",
                 categories: @categories,
                 reveal: true,
                 elements: [Builder.series("Cash", @values, at: 2)]
               )
             end) =~ "so the series takes no at option and no on entity"

      assert error(fn ->
               Builder.chart(:bar,
                 title: "Bar",
                 categories: ~w(a),
                 elements: [Builder.series("A", [1])],
                 totals: :complete
               )
             end) =~ "the totals option is for a waterfall chart"
    end
  end

  describe "the frames" do
    defp years(opts \\ [], later \\ [60, 50, -40, :total]) do
      Builder.chart(
        :waterfall,
        [
          title: "Cash",
          categories: ~w(Start Sales Costs End),
          elements: [],
          timeline: [
            Builder.frame("2024", elements: [Builder.series("Cash", [50, 40, -30, :total])]),
            Builder.frame("2025", elements: [Builder.series("Cash", later)])
          ]
        ] ++ opts
      )
    end

    test "each frame moves the columns to its values, and the totals count" do
      text = style(years())

      # The total "End" is column 3: 60 in 2024 and 70 in 2025.
      assert text =~ ~r/section\[data-step="2"\] \[data-el="[^"]+"\] \{[^}]*--n3: 70;/

      figure = figure(years())
      assert texts(figure, ".chart-frame") == ["2024", "2025"]
      assert count(figure, "tspan.chart-count") >= 2
    end

    test "the text of a change has one copy for each frame" do
      figure = figure(years())
      assert texts(figure, "figure.chart > svg .chart-waterfall-change") == ~w(+40 +50 -30 -40)
    end

    test "the table has a change and a total for each frame" do
      figure = figure(years())

      assert texts(figure, "table.chart-table thead th") ==
               ["Change 2024", "Total 2024", "Change 2025", "Total 2025"]

      rows =
        for row <- LazyHTML.query(figure, "table.chart-table tbody tr"), do: texts(row, "th, td")

      assert hd(rows) == ["Start", "", "50", "", "60"]
    end

    test "paper and the handout view show each frame as a small chart" do
      figure = figure(years())
      assert count(figure, ".chart-frames figure.chart-copy") == 2
      assert count(figure, ".chart-frames rect.chart-waterfall-bar") == 8
    end

    test "with reveal, the changes of the first frame show first, then each later frame" do
      text = style(years(reveal: true))

      # Step 1 holds the start and the totals, steps 2 and 3 the changes, and
      # step 4 the frame 2025.
      assert text =~ ~r/section\[data-step="3"\] \[data-el="[^"]+"\] \{[^}]*--n3: 60;/
      assert text =~ ~r/section\[data-step="4"\] \[data-el="[^"]+"\] \{[^}]*--n3: 70;/
    end

    test "the overview shows the frame of the thumbnail option" do
      assert style(years(thumbnail: :last)) =~ ~r/\.menu-thumb[^{]*\{[^}]*--n3: 70;/
    end

    test "a later frame has its totals at the places of the first frame" do
      assert error(fn -> years([], [60, :total, -40, :total]) end) =~
               "has its totals at the places of the totals of the first frame"
    end
  end

  describe "a CSV file" do
    @moduletag :tmp_dir

    @cash """
    Quarter,Cash
    Start,50
    Sales,40
    Services,30
    Mid year,total
    Grants,10
    Interest,20
    Costs,-50
    End,total 100
    """

    defp from_file(tmp_dir, text) do
      path = Path.join(tmp_dir, "cash.csv")
      File.write!(path, text)
      Builder.chart(:waterfall, title: "Cash", src: path)
    end

    test "a cell total marks a total column, and total 100 gives its value",
         %{tmp_dir: tmp_dir} do
      from_csv = figure(from_file(tmp_dir, @cash))
      from_dsl = figure(cash(category_label: "Quarter"))

      assert boxes(from_csv) == boxes(from_dsl)
      assert texts(from_csv, ".chart-value") == ["50", "120", "100"]
      assert texts(from_csv, ".chart-axis-title") == ["Quarter"]
      assert texts(from_csv, "table.chart-table th") == texts(from_dsl, "table.chart-table th")
    end

    test "the compiler refuses a cell that is not a value, and a total that does not agree",
         %{tmp_dir: tmp_dir} do
      bad = String.replace(@cash, "Grants,10", "Grants,ten")

      assert_raise Spark.Error.DslError,
                   ~r/line 6 of the chart file ".*cash.csv" needs 1 values, and a value is a number, total, or total and a number/,
                   fn -> one_slide(from_file(tmp_dir, bad)) end

      wrong = String.replace(@cash, "total 100", "total 90")

      assert_raise Spark.Error.DslError,
                   ~r/the total "End" of the series "Cash" is 90, and the sum of the values before it is 100/,
                   fn -> one_slide(from_file(tmp_dir, wrong)) end
    end

    test "the frames option names the column of the frame of each row", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "years.csv")

      File.write!(path, """
      year,Quarter,Cash
      2024,Start,50
      2024,Sales,40
      2024,End,total
      2025,Start,60
      2025,Sales,-20
      2025,End,total 40
      """)

      figure = figure(Builder.chart(:waterfall, title: "Cash", src: path, frames: "year"))

      assert texts(figure, ".chart-frame") == ["2024", "2025"]

      assert texts(figure, "table.chart-table thead th") |> Enum.take(3) ==
               ["Quarter", "Change 2024", "Total 2024"]
    end

    test "a file with two columns of values gives two series, and the chart refuses them",
         %{tmp_dir: tmp_dir} do
      assert_raise Spark.Error.DslError,
                   ~r/a waterfall chart has one series, and this chart has 2/,
                   fn ->
                     one_slide(from_file(tmp_dir, "Quarter,A,B\nStart,1,2\n"))
                   end
    end
  end
end
