defmodule Expresso.ChartElementTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Chart
  alias Expresso.Element.Chart.Plot

  doctest Chart
  doctest Plot

  defp document(chart, opts \\ []) do
    [Builder.slide("s", [elements: [chart]] ++ opts)]
    |> Builder.deck(name: "charts")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
  end

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

  defp screen(html), do: Floki.find(html, ".screen figure.chart")

  test "a bar chart draws a bar and a value for each value, a legend and a table" do
    [figure] = bars() |> document() |> screen()

    assert Floki.attribute(figure, "class") == ["chart chart-bar"]
    assert figure |> Floki.find("svg") |> Floki.attribute("aria-label") == ["Orders"]
    assert figure |> Floki.find("svg") |> Floki.attribute("viewbox") == ["0 0 800 450"]

    [orders, returns] = Floki.find(figure, "g.chart-series")
    assert Floki.attribute(orders, "class") == ["chart-series chart-c1"]
    assert Floki.attribute(returns, "class") == ["chart-series chart-c2"]
    assert orders |> Floki.find("path.chart-bar") |> length() == 2
    assert orders |> Floki.find("text.chart-value") |> Enum.map(&Floki.text/1) == ["120", "180"]
    assert orders |> Floki.find(".chart-name") |> Floki.text() == "Orders"

    assert figure |> Floki.find(".chart-category") |> Enum.map(&Floki.text/1) == ["2023", "2024"]
    assert figure |> Floki.find(".chart-tick") |> Enum.map(&Floki.text/1) == ~w(0 50 100 150 200)

    rows = for row <- Floki.find(figure, "table.chart-table tbody tr"), do: Floki.text(row)
    assert rows == ["202312014", "202418022"]
    assert figure |> Floki.find("table.chart-table caption") |> Floki.text() == "Orders"
  end

  test "values false hides the values of the bars, and one series has no legend" do
    [figure] =
      Builder.chart(:bar,
        title: "Orders",
        categories: ["2023"],
        values: false,
        elements: [Builder.series("Orders", [120])]
      )
      |> document()
      |> screen()

    assert Floki.find(figure, ".chart-value") == []
    assert Floki.find(figure, ".chart-name") == []
  end

  test "reveal gives each series its own step, and dim dims the earlier series" do
    html = document(bars(reveal: true, dim: true))
    [orders, returns] = html |> screen() |> Floki.find("g.chart-series")

    assert Floki.attribute(orders, "data-on") == ["1 2"]
    assert Floki.attribute(orders, "data-el") != []
    assert Floki.attribute(returns, "data-on") == ["2"]

    assert html |> Floki.find(".screen section.slide") |> Floki.attribute("data-max-step") == [
             "2"
           ]
  end

  test "a line chart draws a line, a dot for each value and the name and the last value at the end" do
    [figure] =
      Builder.chart(:line,
        title: "Visitors",
        categories: ["Jan", "Feb", "Mar"],
        elements: [Builder.series("Web", [4, 5, 7])]
      )
      |> document()
      |> screen()

    assert [points] = figure |> Floki.find("polyline.chart-line") |> Floki.attribute("points")
    assert points |> String.split(" ") |> length() == 3
    assert figure |> Floki.find("circle.chart-dot") |> length() == 3
    assert figure |> Floki.find(".chart-end") |> Floki.text() == "Web 7"
  end

  test "a pie draws a slice and a part in percent for each category" do
    [figure] =
      Builder.chart(:pie,
        title: "Hours",
        categories: ["Press", "Paint"],
        elements: [Builder.series("Hours", [3, 1])]
      )
      |> document()
      |> screen()

    assert figure
           |> Floki.find("path.chart-slice")
           |> Enum.flat_map(&Floki.attribute(&1, "class")) ==
             ["chart-slice chart-c1", "chart-slice chart-c2"]

    assert figure |> Floki.find(".chart-name") |> Enum.map(&Floki.text/1) ==
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
