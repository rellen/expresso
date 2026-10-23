defmodule Expresso.ChartScatterTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart.{Encoding, Scale}
  alias Expresso.Element.Chart.Scatter.{Data, Labels, Legend}

  doctest Scale
  doctest Encoding
  doctest Legend
  doctest Data
  doctest Labels

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
             ~w(200 400 600 800 1000 1200 1400 0 500 1000 1500 2000 2500)

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

  # The points of the example of issue #426: a region for the symbol and the
  # color, and the users for the size.
  defp regions(opts \\ []) do
    services(opts, [
      Builder.point("api", x: 1200, y: 840, symbol: "EU", color: "EU", size: 30_000),
      Builder.point("web", x: 400, y: 2100, symbol: "US", color: "US", size: 120_000),
      Builder.point("jobs", x: 900, y: 150, symbol: "EU", color: "EU", size: 2_000)
    ])
  end

  # The scale of each mark from its style, in the order of the SVG.
  defp radii(figure) do
    for style <- figure |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("style") do
      [w] = Regex.run(~r/--chart-w: ([-\d.]+);/, style, capture: :all_but_first)
      elem(Float.parse(w), 0)
    end
  end

  describe "the symbol, the color and the size" do
    test "each category of the color is a group, with its color and its item of the legend" do
      figure = figure(regions(symbol_label: "Region", size_label: "Users"))

      [eu, us] = figure |> LazyHTML.query("g.chart-series") |> Enum.to_list()
      assert count(eu, "path.chart-point") == 2
      assert texts(eu, ".chart-name") == ["EU"]
      assert texts(us, ".chart-name") == ["US"]

      [style | _rest] = eu |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("style")
      assert style =~ "--series: var(--chart-1);"
      [style] = us |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("style")
      assert style =~ "--series: var(--chart-2);"

      # The symbol and the color take one field, so the chart has one legend
      # of the categories, with the title of the symbol, and a legend of the
      # sizes.
      assert texts(figure, ".chart-axis-title") == ["Region", "Users"]
      assert texts(figure, ".chart-name") == ["100000", "20000", "5000", "EU", "US"]
      assert count(figure, "circle.chart-size") == 3
    end

    test "a category of the symbol takes the symbols in order, and a point can name a symbol" do
      points = [
        Builder.point("a", x: 1, y: 1, symbol: "gold"),
        Builder.point("b", x: 2, y: 2, symbol: "silver"),
        Builder.point("c", x: 3, y: 3, symbol: :star)
      ]

      figure = figure(services([symbol_label: "Tier"], points))
      paths = figure |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("d")

      assert paths ==
               [Encoding.path(:circle), Encoding.path(:square), Encoding.path(:star)]

      assert texts(figure, ".chart-name") == ["gold", "silver"]
      assert texts(figure, ".chart-axis-title") == ["Tier"]
    end

    test "a color of a role, and a point without a color in a chart with categories" do
      points = [
        Builder.point("a", x: 1, y: 1, color: "core"),
        Builder.point("b", x: 2, y: 2, color: :danger),
        Builder.point("c", x: 3, y: 3)
      ]

      styles =
        figure(services([], points))
        |> LazyHTML.query("path.chart-point")
        |> LazyHTML.attribute("style")

      assert Enum.map(styles, &(Regex.run(~r/--series: ([^;]+);/, &1) |> List.last())) ==
               ["var(--chart-1)", "var(--danger)", "var(--muted)"]
    end

    test "the area of a mark grows in proportion to its size, and the larger marks come first" do
      radii = regions() |> figure() |> radii()

      # The order of the SVG: the group EU with api, then jobs, and the group
      # US with web.
      [api, jobs, web] = radii
      assert api > jobs
      assert_in_delta api * api / (web * web), 30_000 / 120_000, 0.01
      assert_in_delta jobs * jobs / (web * web), 2_000 / 120_000, 0.01
    end

    test "opacity gives each mark its opacity" do
      styles =
        regions(opacity: 0.6)
        |> figure()
        |> LazyHTML.query("path.chart-point")
        |> LazyHTML.attribute("style")

      assert Enum.all?(styles, &(&1 =~ "opacity: 0.6;"))
    end

    test "the table has a column for the category and for the size" do
      figure = figure(regions(symbol_label: "Region", size_label: "Users"))

      assert texts(figure, "table.chart-table thead th") == ["x", "y", "Region", "Users"]

      rows =
        for row <- LazyHTML.query(figure, "table.chart-table tbody tr"), do: texts(row, "th, td")

      assert hd(rows) == ["api", "1200", "840", "EU", "30000"]
    end

    test "a bubble chart draws the points with their sizes" do
      figure =
        Builder.chart(:bubble,
          title: "Users",
          elements: [
            Builder.point("a", x: 1, y: 1, size: 4),
            Builder.point("b", x: 2, y: 2, size: 1)
          ]
        )
        |> figure()

      assert LazyHTML.attribute(figure, "class") == ["chart chart-bubble"]
      assert [40.0, 20.0] = radii(figure)
    end
  end

  describe "the series" do
    defp teams(opts \\ []) do
      services(opts, [
        Builder.series("Core",
          symbol: :square,
          elements: [
            Builder.point("api", x: 1, y: 2),
            Builder.point("db", x: 2, y: 3, color: :danger)
          ]
        ),
        Builder.series("Edge", elements: [Builder.point("cdn", x: 3, y: 1, symbol: :star)])
      ])
    end

    test "a series is a group, and it gives its symbol and its color to its points" do
      figure = figure(teams(color_label: "Team"))
      [core, edge] = figure |> LazyHTML.query("g.chart-series") |> Enum.to_list()

      assert core |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("d") ==
               [Encoding.path(:square), Encoding.path(:square)]

      styles = core |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("style")

      assert Enum.map(styles, &(Regex.run(~r/--series: ([^;]+);/, &1) |> List.last())) ==
               ["var(--chart-1)", "var(--danger)"]

      [path] = edge |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("d")
      assert path == Encoding.path(:star)
      [style] = edge |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("style")
      assert style =~ "--series: var(--chart-2);"

      # The legend shows each series by its name, with its symbol and its color.
      assert texts(core, ".chart-name") == ["Core"]
      assert texts(edge, ".chart-name") == ["Edge"]
      assert texts(figure, ".chart-axis-title") == ["Team"]

      assert texts(figure, "table.chart-table thead th") == ["x", "y", "Team"]
    end

    test "a series takes the symbol and the color of a role" do
      figure =
        services([], [
          Builder.series("Core", color: :accent, elements: [Builder.point("a", x: 1, y: 1)])
        ])
        |> figure()

      [style] = figure |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("style")
      assert style =~ "--series: var(--accent);"
    end

    test "the errors of a series" do
      assert_raise ArgumentError,
                   ~r/holds point entities or series of points, and not both/,
                   fn ->
                     services([], [
                       Builder.point("a", x: 1, y: 1),
                       Builder.series("S", elements: [Builder.point("b", x: 1, y: 1)])
                     ])
                   end

      assert_raise ArgumentError,
                   ~r/the series "S" of a scatter chart holds point entities, and no values/,
                   fn ->
                     services([], [Builder.series("S", [1, 2])])
                   end

      assert_raise ArgumentError, ~r/the series "S" of a scatter chart needs a point/, fn ->
        services([], [Builder.series("S")])
      end

      assert_raise ArgumentError,
                   ~r/the point "a" is in a series, and the series is its category/,
                   fn ->
                     services([], [
                       Builder.series("S",
                         elements: [Builder.point("a", x: 1, y: 1, color: "EU")]
                       )
                     ])
                   end

      assert_raise ArgumentError, ~r/two points have the name "a"/, fn ->
        services([], [
          Builder.series("S", elements: [Builder.point("a", x: 1, y: 1)]),
          Builder.series("T", elements: [Builder.point("a", x: 2, y: 2)])
        ])
      end

      assert_raise ArgumentError, ~r/so the series "S" of a bar chart takes neither/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["a"],
          elements: [Builder.series("S", [1], color: :accent)]
        )
      end
    end
  end

  describe "the labels" do
    test "labels :all gives each point a label that moves with its mark" do
      figure = figure(services(labels: :all))

      assert texts(figure, "text.chart-point-label") == ["api", "web", "jobs"]

      [style | _rest] =
        figure |> LazyHTML.query("text.chart-point-label") |> LazyHTML.attribute("style")

      [mark | _rest] =
        figure |> LazyHTML.query("path.chart-point") |> LazyHTML.attribute("style")

      # The label and the mark of a point read the same place.
      place = &Regex.run(~r/--chart-u: [^;]+; --chart-v: [^;]+;/, &1)
      assert place.(style) == place.(mark)
    end

    test "a list of names gives a label to those points, and the default is no label" do
      assert texts(figure(services(labels: ["web"])), "text.chart-point-label") == ["web"]
      assert count(figure(services()), "text.chart-point-label") == 0
    end

    test "two close points put their labels on two sides, so the labels do not cover each other" do
      points = [Builder.point("alpha", x: 10, y: 10), Builder.point("beta", x: 10.3, y: 10)]

      anchors =
        services([labels: :all, x_range: {0, 20}, y_range: {0, 20}], points)
        |> figure()
        |> LazyHTML.query("text.chart-point-label")
        |> LazyHTML.attribute("text-anchor")

      assert anchors == ["end", "start"]
    end

    test "a name of the labels option that is not a point" do
      assert_raise ArgumentError,
                   ~r/the labels option names "db", and the chart has no point/,
                   fn ->
                     services(labels: ["db"])
                   end
    end
  end

  describe "a CSV file" do
    @moduletag :tmp_dir

    @services """
    service,cost,load,region,users
    api,1200,840,EU,"30,000"
    web,400,2100,US,"120,000"
    jobs,900,150,,"2,000"
    """

    defp from_file(tmp_dir, opts, text \\ @services) do
      path = Path.join(tmp_dir, "services.csv")
      File.write!(path, text)
      [%{elements: [chart]}] = one_slide(services([src: path] ++ opts, [])).slides
      chart
    end

    test "the options name the columns, and each row is a point", %{tmp_dir: tmp_dir} do
      chart = from_file(tmp_dir, x: "cost", y: "load", color: "region", size: "users")

      points = Enum.flat_map(chart.elements, & &1.elements)

      # Each category of the color is a group, and the point without a
      # category is in the last group.
      assert Enum.map(points, &{&1.name, &1.x, &1.y, &1.color, &1.size}) == [
               {"api", 1200, 840, "EU", 30_000},
               {"web", 400, 2100, "US", 120_000},
               {"jobs", 900, 150, nil, 2_000}
             ]
    end

    test "the chart of a file draws a mark for each row", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "services.csv")
      File.write!(path, @services)

      figure =
        services([src: path, x: "cost", y: "load", symbol: "region", label: "service"], [])
        |> figure()

      assert count(figure, "path.chart-point") == 3
      assert texts(figure, ".chart-name") == ["EU", "US"]
    end

    test "a column that the file does not have", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "services.csv")
      File.write!(path, @services)

      assert_raise Spark.Error.DslError,
                   ~r/has no column "price" for the x option. The columns are "service", "cost"/,
                   fn -> services([src: path, x: "price", y: "load"], []) |> one_slide() end
    end

    test "a cell that is not a number", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "services.csv")
      File.write!(path, "name,x,y\napi,cheap,3\n")

      assert_raise Spark.Error.DslError,
                   ~r/line 2 of the chart file .* has "cheap" as its x, and the x is a number/,
                   fn -> services([src: path], []) |> one_slide() end
    end

    test "a column option without src, and src with points" do
      assert_raise ArgumentError,
                   ~r/the x option names a column of a CSV file, so it needs the src option/,
                   fn ->
                     services(x: "cost")
                   end

      assert_raise ArgumentError, ~r/takes the src option or points, and not both/, fn ->
        services(src: "a.csv")
      end
    end
  end

  describe "the errors" do
    test "a point of a bubble chart without a size" do
      assert_raise ArgumentError,
                   ~r/a bubble chart needs a size for each point, and the point "b"/,
                   fn ->
                     Builder.chart(:bubble,
                       title: "Users",
                       elements: [
                         Builder.point("a", x: 1, y: 1, size: 4),
                         Builder.point("b", x: 2, y: 2)
                       ]
                     )
                   end
    end

    test "a size of zero, and a point without a size beside points with one" do
      assert_raise ArgumentError, ~r/the point "a" has the size 0/, fn ->
        services([], [Builder.point("a", x: 1, y: 1, size: 0)])
      end

      assert_raise ArgumentError, ~r/the point "b" has no size, and other points have one/, fn ->
        services([], [Builder.point("a", x: 1, y: 1, size: 3), Builder.point("b", x: 2, y: 2)])
      end
    end

    test "more categories of the symbol than symbols, and of the color than colors" do
      points = for n <- 1..7, do: Builder.point("p#{n}", x: n, y: n, symbol: "s#{n}")

      assert_raise ArgumentError, ~r/the symbol takes at most 6 categories/, fn ->
        services([], points)
      end

      points = for n <- 1..9, do: Builder.point("p#{n}", x: n, y: n, color: "c#{n}")

      assert_raise ArgumentError, ~r/the color takes at most 8 categories/, fn ->
        services([], points)
      end
    end

    test "an opacity outside 0 to 1" do
      assert_raise ArgumentError, ~r/the opacity of a mark is a number from 0 to 1/, fn ->
        services(opacity: 1.5)
      end
    end

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
