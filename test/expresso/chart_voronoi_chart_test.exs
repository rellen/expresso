defmodule Expresso.ChartVoronoiChartTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart.Voronoi

  @categories [
    "Production/Press",
    "Production/Paint",
    "Production/Weld",
    "Sales/North",
    "Sales/South",
    "Office"
  ]
  @values [42, 18, 25, 30, 22, 14]

  # The box of the plot of a Voronoi treemap, from `Expresso.Element.Chart`.
  @box %{left: 4, right: 556, top: 4, bottom: 446}

  defp chart(opts \\ []) do
    defaults = [
      title: "Staff",
      categories: @categories,
      elements: [Builder.series("Staff", @values)]
    ]

    Builder.chart(:voronoi, Keyword.merge(defaults, opts))
  end

  defp figure(chart), do: [chart] |> one_slide() |> document() |> screen("figure.chart")

  # The corners of the path of a cell, from its `d` attribute.
  defp polygon(path) do
    [d] = LazyHTML.attribute(path, "d")

    ~r/(-?[\d.]+),(-?[\d.]+)/
    |> Regex.scan(d, capture: :all_but_first)
    |> Enum.map(fn [x, y] -> {number(x), number(y)} end)
  end

  defp number(text) do
    {number, ""} = Float.parse(text)
    number
  end

  defp areas(figure, selector),
    do: figure |> LazyHTML.query(selector) |> Enum.map(&Voronoi.area(polygon(&1)))

  describe "the render" do
    test "a cell for each part, an outline for each group, and a legend of the top-level groups" do
      figure = figure(chart())

      assert count(figure, "path.chart-cell") == 6
      assert count(figure, "path.chart-cell-group") == 2
      assert count(figure, ".chart-swatch") == 3

      assert texts(figure, ".chart-name") == [
               "Production 56.3%",
               "Sales 34.4%",
               "Office 9.3%"
             ]
    end

    test "the cells fill the container of each shape, with an area in proportion to each value" do
      total = Enum.sum(@values)

      for shape <- [:rectangle, :circle, :hexagon, [{0, 0}, {1, 0}, {0.5, 1}]] do
        figure = figure(chart(shape: shape))
        whole = Voronoi.area(Voronoi.container(shape, @box))
        cells = areas(figure, "path.chart-cell")

        # The path rounds each corner to one decimal place.
        assert_in_delta Enum.sum(cells), whole, whole * 0.002, inspect(shape)

        for {area, value} <- Enum.zip(Enum.sort(cells), Enum.sort(@values)) do
          assert_in_delta area, value / total * whole, whole * (Voronoi.limit() + 0.002)
        end
      end
    end

    test "a leaf shows its name and its value, and values false leaves out the value" do
      figure = figure(chart())

      assert texts(figure, ".chart-cell-label .chart-part") |> Enum.sort() ==
               ~w(North Office Paint Press South Weld)

      assert "42" in texts(figure, ".chart-cell-label .chart-part-value")

      figure = figure(chart(values: false))
      assert count(figure, ".chart-cell-label") == 6
      assert count(figure, ".chart-part-value") == 0
    end

    test "a label that does not fit its cell does not show, and the table still gives the part" do
      figure =
        figure(
          chart(
            categories: ["Big", "A part with a long name"],
            elements: [Builder.series("Staff", [990, 10])]
          )
        )

      assert texts(figure, ".chart-cell-label .chart-part") == ["Big"]
      assert "A part with a long name" in texts(figure, ".chart-table td, .chart-table th")
    end

    test "a narrow cell gets a smaller label, and a narrower cell gets the name alone" do
      categories = [
        "Production/Press",
        "Production/Paint",
        "Production/Weld",
        "Production/Cut",
        "Sales/North",
        "Sales/South",
        "Sales/Online",
        "Research/Labs",
        "Research/Field",
        "Office"
      ]

      figure =
        figure(
          chart(
            shape: [{0, 0}, {1, 0}, {0.5, 1}],
            categories: categories,
            elements: [Builder.series("Staff", [42, 18, 25, 9, 30, 22, 12, 16, 8, 14])]
          )
        )

      # Each of the 10 parts has a label.
      assert count(figure, ".chart-cell-label") == 10

      small = texts(figure, ".chart-cell-label-small .chart-part")
      assert "Cut" in small and "Field" in small

      # The small label of Cut holds its value, and the small label of Field
      # has room for its name alone.
      values = fn name ->
        figure
        |> LazyHTML.query(".chart-cell-label-small")
        |> Enum.find(&(texts(&1, ".chart-part") == [name]))
        |> texts(".chart-part-value")
      end

      assert values.("Cut") == ["9"]
      assert values.("Field") == []
      assert "Press" not in small
    end

    test "a part with the value 0 gets no cell and no label" do
      figure = figure(chart(elements: [Builder.series("Staff", [42, 18, 25, 30, 22, 0])]))

      assert count(figure, "path.chart-cell") == 5
      refute "Office" in texts(figure, ".chart-cell-label .chart-part")
    end

    test "the same deck gives the same document" do
      first = [chart(shape: :hexagon)] |> one_slide() |> document() |> LazyHTML.to_html()
      second = [chart(shape: :hexagon)] |> one_slide() |> document() |> LazyHTML.to_html()
      assert first == second
    end
  end

  describe "the options" do
    test "the shape option takes a named shape or a convex polygon of at least 3 points" do
      assert_raise ArgumentError, ~r/a polygon needs at least 3/, fn ->
        chart(shape: [{0, 0}, {1, 1}])
      end

      assert_raise ArgumentError, ~r/is not convex/, fn ->
        chart(shape: [{0, 0}, {1, 0}, {1, 1}, {0.5, 0.2}, {0, 1}])
      end

      assert_raise ArgumentError, ~r/crosses itself/, fn ->
        chart(shape: [{0, 0}, {1, 1}, {1, 0}, {0, 1}])
      end

      assert_raise ArgumentError, ~r/:rectangle, :circle, :hexagon or a list of points/, fn ->
        chart(shape: :star)
      end
    end

    test "only a voronoi chart takes the shape option" do
      assert_raise ArgumentError, ~r/so a treemap chart takes no shape option/, fn ->
        Builder.chart(:treemap,
          title: "Staff",
          categories: @categories,
          shape: :circle,
          elements: [Builder.series("Staff", @values)]
        )
      end
    end

    test "a voronoi chart takes no frames, no count option and no effect :grow" do
      assert_raise ArgumentError, ~r/a voronoi chart takes no frames/, fn ->
        Builder.chart(:voronoi,
          title: "Staff",
          categories: @categories,
          timeline: [
            Builder.frame("2024", elements: [Builder.series("Staff", @values)]),
            Builder.frame("2025", elements: [Builder.series("Staff", @values)])
          ]
        )
      end

      assert_raise ArgumentError, ~r/no effect :grow and no count option/, fn ->
        chart(effect: :grow)
      end

      assert_raise ArgumentError, ~r/no effect :grow and no count option/, fn ->
        chart(elements: [Builder.series("Staff", @values, effect: :grow)])
      end
    end

    test "a voronoi chart takes one series of values of zero or more, as a treemap" do
      assert_raise ArgumentError, ~r/the values of a voronoi are zero or more/, fn ->
        chart(elements: [Builder.series("Staff", [1, -2, 3, 4, 5, 6])])
      end
    end
  end
end
