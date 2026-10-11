defmodule Expresso.ChartHierarchyTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Chart.Hierarchy

  doctest Hierarchy

  @categories ["Production/Press", "Production/Paint", "Support/Stops", "Office"]

  defp chart(kind, opts \\ []) do
    defaults = [
      title: "Hours",
      categories: @categories,
      elements: [Builder.series("Hours", [60, 40, 20, 30])]
    ]

    Builder.chart(kind, Keyword.merge(defaults, opts))
  end

  defp figure(chart) do
    [Builder.slide("s", elements: [chart])]
    |> Builder.deck(name: "parts")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find(".screen figure.chart")
  end

  describe "the tree" do
    test "a slash in a category names a part of a group, in the order of the first category" do
      [production, support, office] = Hierarchy.tree(@categories)

      assert {production.name, production.color, Enum.map(production.children, & &1.name)} ==
               {"Production", 1, ["Press", "Paint"]}

      assert {support.name, support.color, hd(support.children).index} == {"Support", 2, 2}
      assert {office.name, office.index, office.children} == {"Office", 3, []}
      assert Enum.map(Hierarchy.flatten([production]), & &1.id) == [1, 2, 3]
    end

    test "the categories of one group need not be neighbors" do
      [a, b] = Hierarchy.tree(["A/x", "B", "A/y"])
      assert {a.name, Enum.map(a.children, & &1.index), b.name} == {"A", [0, 2], "B"}
    end

    test "the check refuses an empty part, a category two times and more than 8 groups" do
      assert {:error, message} = Hierarchy.check(["A//x"])
      assert message =~ "an empty part"

      assert {:error, message} = Hierarchy.check(["A/x", "A / x"])
      assert message =~ "\"A/x\" shows two times"

      assert {:error, message} = Hierarchy.check(Enum.map(1..9, &"G#{&1}"))
      assert message =~ "at most 8 groups"
    end

    test "squarify fills the rectangle with rectangles of the given areas" do
      placed =
        Hierarchy.squarify([{:a, 6}, {:b, 4}, {:c, 3}, {:d, 2}, {:e, 1}], %{
          x: 0,
          y: 0,
          w: 4,
          h: 4
        })

      assert Enum.map(placed, &elem(&1, 0)) == [:a, :b, :c, :d, :e]

      for {key, box} <- placed do
        area = %{a: 6, b: 4, c: 3, d: 2, e: 1}[key]
        assert_in_delta box.w * box.h, area, 1.0e-9

        assert box.x >= 0 and box.y >= 0 and box.x + box.w <= 4 + 1.0e-9 and
                 box.y + box.h <= 4 + 1.0e-9
      end
    end
  end

  describe "the checks of the chart" do
    test "a treemap and a sunburst take one series of values of zero or more, and no reveal" do
      assert_raise ArgumentError, ~r/a treemap has one series/, fn ->
        chart(:treemap,
          elements: [Builder.series("A", [1, 2, 3, 4]), Builder.series("B", [1, 2, 3, 4])]
        )
      end

      assert_raise ArgumentError, ~r/the values of a sunburst are zero or more/, fn ->
        chart(:sunburst, elements: [Builder.series("A", [1, -2, 3, 4])])
      end

      assert_raise ArgumentError,
                   ~r/a treemap has one series, so it takes no reveal option/,
                   fn ->
                     chart(:treemap, reveal: true)
                   end
    end

    test "a category that is also a group gives an error" do
      assert_raise ArgumentError, ~r/the category "Office" is a group of "Office\/IT"/, fn ->
        chart(:treemap,
          categories: ["Office", "Office/IT"],
          elements: [Builder.series("A", [1, 2])]
        )
      end
    end
  end

  describe "the render" do
    test "a treemap draws a box for each group and each part, and a label for each" do
      [figure] = figure(chart(:treemap))

      assert Floki.attribute(figure, "class") == ["chart chart-treemap"]
      svg = Floki.find(figure, "figure.chart > svg")
      assert svg |> Floki.find("rect.chart-group") |> length() == 2
      assert svg |> Floki.find("rect.chart-tile") |> length() == 4

      assert svg |> Floki.find(".chart-head") |> Enum.map(&Floki.text/1) == [
               "Production",
               "Support"
             ]

      assert svg |> Floki.find(".chart-part") |> Enum.map(&Floki.text/1) == [
               "Press",
               "Paint",
               "Office",
               "Stops"
             ]

      assert svg |> Floki.find(".chart-part-value") |> Enum.map(&Floki.text/1) == [
               "60",
               "40",
               "30",
               "20"
             ]

      assert svg |> Floki.find("g.chart-c1 rect") |> length() == 3
    end

    test "each box of a treemap reads its place and its size from its channels" do
      [figure] = figure(chart(:treemap))
      [press | _] = Floki.find(figure, "figure.chart > svg rect.chart-tile")
      [style] = Floki.attribute(press, "style")

      assert style =~ ~r/--chart-u: [\d.]+; --chart-v: [\d.]+;/
      assert style =~ ~r/--chart-w: calc\(0 \+ \([\d.]+ - 0\) \* var\(--chart-shown, 1\)\);/
    end

    test "a sunburst draws a ring for each level, and a legend of the groups in percent" do
      [figure] = figure(chart(:sunburst))
      svg = Floki.find(figure, "figure.chart > svg")

      assert svg |> Floki.find("circle.chart-ring.chart-depth-1") |> length() == 3
      assert svg |> Floki.find("circle.chart-ring.chart-depth-2") |> length() == 3
      assert svg |> Floki.find("line.chart-gap") |> length() == 6

      assert svg |> Floki.find(".chart-name") |> Enum.map(&Floki.text/1) ==
               ["Production 66.7%", "Office 20%", "Support 13.3%"]
    end

    test "the frames of a treemap move its boxes at their steps" do
      timeline = [
        Builder.frame("2024", elements: [Builder.series("Hours", [60, 40, 20, 30])]),
        Builder.frame("2025", elements: [Builder.series("Hours", [20, 40, 60, 30])])
      ]

      html =
        [Builder.slide("s", elements: [chart(:treemap, elements: [], timeline: timeline)])]
        |> Builder.deck(name: "parts")
        |> Expresso.Deck.render()

      assert html =~ ~r/section\[data-step="2"\] \[data-el="s1-e1"\] \{[^}]*--rw2: [\d.]+;/
      document = Floki.parse_document!(html)
      assert document |> Floki.find(".screen .chart-frames figure.chart-copy") |> length() == 2
    end

    @tag :tmp_dir
    test "a CSV file gives the groups with a slash, as for the other charts", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "hours.csv")

      File.write!(
        path,
        "Machine,Hours\nProduction/Press,60\nProduction/Paint,40\nSupport/Stops,20\n"
      )

      [figure] = figure(Builder.chart(:treemap, title: "Hours", src: path))
      assert figure |> Floki.find("figure.chart > svg rect.chart-tile") |> length() == 3
    end
  end
end
