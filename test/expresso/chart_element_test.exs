defmodule Expresso.ChartElementTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart
  alias Expresso.Element.Chart.Plot

  doctest Chart
  doctest Plot

  defp bars(opts \\ []) do
    Builder.chart(
      :bar,
      [
        title: "Orders",
        categories: ["2023", "2024"],
        elements: [Builder.series("Orders", [120, 180]), Builder.series("Returns", [14, 22])]
      ] ++ opts
    )
  end

  defp figures(chart),
    do: chart |> one_slide() |> document() |> screen("figure.chart") |> Enum.to_list()

  test "a bar chart draws a bar and a value for each value, a legend and a table" do
    [figure] = figures(bars())

    assert LazyHTML.attribute(figure, "class") == ["chart chart-bar"]
    assert figure |> LazyHTML.query("svg") |> LazyHTML.attribute("aria-label") == ["Orders"]
    assert figure |> LazyHTML.query("svg") |> LazyHTML.attribute("viewBox") == ["0 0 800 450"]

    [orders, returns] = LazyHTML.query(figure, "g.chart-series") |> Enum.to_list()
    assert LazyHTML.attribute(orders, "class") == ["chart-series chart-c1"]
    assert LazyHTML.attribute(returns, "class") == ["chart-series chart-c2"]
    assert count(orders, "path.chart-bar") == 2
    assert texts(orders, "text.chart-value") == ["120", "180"]
    assert texts(orders, ".chart-name") == ["Orders"]

    assert texts(figure, ".chart-category") == ["2023", "2024"]
    assert texts(figure, ".chart-tick") == ~w(0 50 100 150 200)

    rows = for row <- LazyHTML.query(figure, "table.chart-table tbody tr"), do: LazyHTML.text(row)
    assert rows == ["202312014", "202418022"]
    assert texts(figure, "table.chart-table caption") == ["Orders"]
  end

  test "the corner of the table is a cell, so each header of the table has a name" do
    [figure] = figures(bars())

    heads = texts(figure, "table.chart-table thead th")
    assert heads == ["Orders", "Returns"]
    assert count(figure, "table.chart-table thead td") == 1
  end

  test "values false hides the values of the bars, and one series has no legend" do
    [figure] =
      Builder.chart(:bar,
        title: "Orders",
        categories: ["2023"],
        values: false,
        elements: [Builder.series("Orders", [120])]
      )
      |> figures()

    assert figure |> LazyHTML.filter(":not(:has(.chart-value))") |> Enum.count() == 1
    assert figure |> LazyHTML.filter(":not(:has(.chart-name))") |> Enum.count() == 1
  end

  test "reveal gives each series its own step, and dim dims the earlier series" do
    html = bars(reveal: true, dim: true) |> one_slide() |> document()

    [orders, returns] =
      html |> screen("figure.chart g.chart-series") |> Enum.to_list()

    assert LazyHTML.attribute(orders, "data-on") == ["1 2"]
    assert LazyHTML.attribute(orders, "data-el") != []
    assert LazyHTML.attribute(returns, "data-on") == ["2"]

    assert html
           |> screen("section.slide")
           |> LazyHTML.attribute("data-max-step") == ["2"]
  end

  test "a line chart draws a line, a dot for each value and the name and the last value at the end" do
    [figure] =
      Builder.chart(:line,
        title: "Visitors",
        categories: ["Jan", "Feb", "Mar"],
        elements: [Builder.series("Web", [4, 5, 7])]
      )
      |> figures()

    assert [points] =
             figure |> LazyHTML.query("polyline.chart-line") |> LazyHTML.attribute("points")

    assert points |> String.split(" ") |> length() == 3
    assert count(figure, "circle.chart-dot") == 3
    assert texts(figure, ".chart-end") == ["Web 7"]
  end

  test "a pie draws a slice and a part in percent for each category" do
    [figure] =
      Builder.chart(:pie,
        title: "Hours",
        categories: ["Press", "Paint"],
        elements: [Builder.series("Hours", [3, 1])]
      )
      |> figures()

    assert figure
           |> LazyHTML.query("path.chart-slice")
           |> Enum.flat_map(&LazyHTML.attribute(&1, "class")) ==
             ["chart-slice chart-c1", "chart-slice chart-c2"]

    assert texts(figure, ".chart-name") ==
             ["Press 75%", "Paint 25%"]
  end

  @tag :tmp_dir
  test "src reads the categories and the series from a CSV file", %{tmp_dir: tmp_dir} do
    File.write!(Path.join(tmp_dir, "data.csv"), "Month,Web,Shop\nJan,4,1.5\n\nFeb,5,2\n")

    code = """
    defmodule Expresso.ChartElementTest.CsvDeck do
      use Expresso
      name "csv"
      root #{inspect(tmp_dir)}

      slide "s" do
        chart :line do
          title "Visitors"
          src "data.csv"
          reveal true
        end
      end
    end
    """

    Code.compile_string(code)
    {:ok, deck} = Expresso.to_deck(Expresso.ChartElementTest.CsvDeck)
    [%Chart{categories: categories, elements: series}] = hd(deck.slides).elements

    assert categories == ["Jan", "Feb"]
    assert Enum.map(series, &{&1.name, &1.values}) == [{"Web", [4, 5]}, {"Shop", [1.5, 2]}]
    assert Enum.map(series, & &1.steps) == [[1, 2], [2]]
  end

  test "a chart of very small values has an axis, and its labels have no exponent" do
    tiny =
      Builder.chart(:bar,
        title: "T",
        categories: ["A", "B"],
        elements: [Builder.series("S", [1.0e-7, 2.0e-7])]
      )

    [figure] = figures(tiny)
    assert texts(figure, "text.chart-value") == ["0.0000001", "0.0000002"]
    ticks = texts(figure, "text.chart-tick")
    assert List.first(ticks) == "0" and List.last(ticks) == "0.0000002"
    assert ticks |> Enum.uniq() |> length() == length(ticks)

    small =
      Builder.chart(:bar,
        title: "T",
        categories: ["A"],
        elements: [Builder.series("S", [0.00025])]
      )

    [figure] = figures(small)
    assert texts(figure, "text.chart-value") == ["0.00025"]
    refute figure |> LazyHTML.text() |> String.contains?("e-")

    # A label keeps at most 100 decimals, so a value under 1.0e-253 does not
    # stop the render.
    smallest =
      Builder.chart(:bar,
        title: "T",
        categories: ["A"],
        elements: [Builder.series("S", [1.0e-300])]
      )

    assert [_figure] = figures(smallest)
  end

  test "the CSV reader names the line of a bad row" do
    chart = %Chart{kind: :bar, title: "x", src: "test/fixtures/missing.csv"}
    assert {:error, "cannot read the chart file" <> _rest} = Chart.build(chart)

    path =
      Path.join(System.tmp_dir!(), "expresso-chart-#{System.unique_integer([:positive])}.csv")

    File.write!(path, "Year,Orders\n2023,12\n2024,many\n")
    assert {:error, message} = Chart.build(%Chart{chart | src: path})
    assert message =~ "line 3 of the chart file"
    File.rm!(path)
  end

  test "the compiler refuses a chart that does not agree with its kind" do
    series = fn values -> Builder.series("A", values) end

    assert_raise ArgumentError, ~r/needs 2 numbers/, fn ->
      Builder.chart(:bar, title: "x", categories: ["a", "b"], elements: [series.([1])])
    end

    assert_raise ArgumentError, ~r/needs the categories option or the src option/, fn ->
      Builder.chart(:bar, title: "x", elements: [series.([1])])
    end

    assert_raise ArgumentError, ~r/needs a series/, fn ->
      Builder.chart(:bar, title: "x", categories: ["a"])
    end

    assert_raise ArgumentError, ~r/at most 8 series/, fn ->
      Builder.chart(:line,
        title: "x",
        categories: ["a"],
        elements: for(_ <- 1..9, do: series.([1]))
      )
    end

    assert_raise ArgumentError, ~r/a pie has one series/, fn ->
      Builder.chart(:pie, title: "x", categories: ["a"], elements: [series.([1]), series.([2])])
    end

    assert_raise ArgumentError, ~r/takes no reveal option/, fn ->
      Builder.chart(:pie, title: "x", categories: ["a"], reveal: true, elements: [series.([1])])
    end

    assert_raise ArgumentError, ~r/zero or more/, fn ->
      Builder.chart(:pie, title: "x", categories: ["a", "b"], elements: [series.([1, -1])])
    end

    assert_raise ArgumentError, ~r/and not both/, fn ->
      Builder.chart(:bar, title: "x", src: "a.csv", categories: ["a"])
    end
  end

  test "the theme gives eight colors of series for its variant, and a theme with two variants switches them" do
    light = Expresso.Palette.Builtin.fetch!(:default)
    dark = Expresso.Palette.Builtin.fetch!(:dracula)

    assert Expresso.Palette.declarations(light) =~ "--chart-1: #2a78d6;"
    assert Expresso.Palette.declarations(light) =~ "--chart-8: #e34948;"
    assert Expresso.Palette.declarations(dark) =~ "--chart-1: #3987e5;"
    assert Expresso.Palette.chart_colors(:light) != Expresso.Palette.chart_colors(:dark)
  end
end
