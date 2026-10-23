defmodule Expresso.ChartScatterTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart.Scale

  doctest Scale

  defp services(opts \\ [], points \\ nil) do
    points =
      points ||
        [
          Builder.point("api", x: 1200, y: 840),
          Builder.point("web", x: 400, y: 2100),
          Builder.point("jobs", x: 900, y: 150)
        ]

    Builder.chart(:scatter, [title: "Services", elements: points] ++ opts)
  end

  defp figure(chart) do
    [figure] = chart |> one_slide() |> document() |> screen("figure.chart") |> Enum.to_list()
    figure
  end

  # The place of each mark from its style: the value of `--chart-u` and of
  # `--chart-v`.
  defp places(figure) do
    for style <- figure |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("style") do
      [u] = Regex.run(~r/--chart-u: ([-\d.]+);/, style, capture: :all_but_first)
      [v] = Regex.run(~r/--chart-v: ([-\d.]+);/, style, capture: :all_but_first)
      {elem(Float.parse(u), 0), elem(Float.parse(v), 0)}
    end
  end

  test "a scatter plot draws one mark for each point, the axes and a table" do
    figure = figure(services(x_label: "Cost", y_label: "Requests"))

    assert LazyHTML.attribute(figure, "class") == ["chart chart-scatter"]
    assert count(figure, "path.chart-point") == 3
    assert texts(figure, ".chart-axis-title") == ["Cost", "Requests"]

    assert texts(figure, ".chart-tick") ==
             ~w(400 600 800 1000 1200 0 500 1000 1500 2000 2500)

    assert texts(figure, "table.chart-table thead th") == ["Cost", "Requests"]

    rows =
      for row <- LazyHTML.query(figure, "table.chart-table tbody tr"), do: texts(row, "th, td")

    assert rows == [["api", "1200", "840"], ["web", "400", "2100"], ["jobs", "900", "150"]]
  end

  test "a mark goes to the place of its values on the two axes" do
    [api, web, jobs] = figure(services()) |> places()

    # A larger x is further to the right, and a larger y is further up.
    assert elem(web, 0) < elem(jobs, 0) and elem(jobs, 0) < elem(api, 0)
    assert elem(web, 1) < elem(api, 1) and elem(api, 1) < elem(jobs, 1)
  end

  test "x_range and y_range give the ends of the axes" do
    figure = figure(services(x_range: {0, 2000}, y_range: {0, 3000}))
    assert texts(figure, ".chart-tick") == ~w(0 500 1000 1500 2000 0 1000 2000 3000)
  end

  test "a logarithmic axis has a tick at each power of ten" do
    points = [Builder.point("a", x: 3, y: 1), Builder.point("b", x: 4000, y: 2)]
    figure = figure(services([x_scale: :log], points))

    assert texts(figure, ".chart-tick") |> Enum.take(5) == ~w(1 10 100 1000 10000)
  end

  test "a point takes the class option and the overlay options" do
    points = [
      Builder.point("a", x: 1, y: 1, class: "core", at: 2),
      Builder.point("b", x: 2, y: 2)
    ]

    figure = figure(services([], points))

    assert figure |> LazyHTML.query("g[data-on='2'] path.chart-point.core") |> Enum.count() == 1
  end

  describe "the errors" do
    test "two points with one name" do
      points = [Builder.point("a", x: 1, y: 1), Builder.point("a", x: 2, y: 2)]

      assert_raise ArgumentError, ~r/two points have the name "a"/, fn ->
        services([], points)
      end
    end

    test "a point without x or y" do
      assert_raise ArgumentError, ~r/required :y option not found/, fn ->
        Builder.point("a", x: 1)
      end
    end

    test "a scatter plot without points" do
      assert_raise ArgumentError, ~r/a scatter chart needs a point/, fn -> services([], []) end
    end

    test "a value of zero on a logarithmic axis" do
      points = [Builder.point("a", x: 0, y: 1), Builder.point("b", x: 2, y: 2)]

      assert_raise ArgumentError,
                   ~r/a logarithmic x axis needs values more than zero, and the point "a" has x 0/,
                   fn -> services([x_scale: :log], points) end
    end

    test "a value outside the range" do
      assert_raise ArgumentError,
                   ~r/the point "api" has x 1200, outside the x_range \{0, 1000\}/,
                   fn -> services(x_range: {0, 1000}) end
    end

    test "a range from a high value to a low value" do
      assert_raise ArgumentError, ~r/the y_range option goes from the low value/, fn ->
        services(y_range: {100, 0})
      end
    end

    test "an option of the other kinds" do
      assert_raise ArgumentError, ~r/a scatter chart takes no categories option/, fn ->
        services(categories: ["a"])
      end
    end

    test "a point in a bar chart, and an axis option of a bar chart" do
      assert_raise ArgumentError, ~r/so a bar chart takes no point entity/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["2025"],
          elements: [Builder.point("a", x: 1, y: 1)]
        )
      end

      assert_raise ArgumentError, ~r/so a bar chart takes no x_label option/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["2025"],
          x_label: "Cost",
          elements: [Builder.series("Orders", [1])]
        )
      end
    end
  end
end
