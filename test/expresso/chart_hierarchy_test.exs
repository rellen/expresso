defmodule Expresso.ChartHierarchyTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart.{Csv, Hierarchy}

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

  defp figure(chart),
    do: chart |> one_slide() |> document() |> screen("figure.chart") |> Enum.to_list()

  describe "the tree" do
    test "a slash in a category names a part of a group, in the order of the first category" do
      [production, support, office] = Hierarchy.tree(@categories, "/")

      assert {production.name, production.color, Enum.map(production.children, & &1.name)} ==
               {"Production", 1, ["Press", "Paint"]}

      assert {support.name, support.color, hd(support.children).index} == {"Support", 2, 2}
      assert {office.name, office.index, office.children} == {"Office", 3, []}
      assert Enum.map(Hierarchy.flatten([production]), & &1.id) == [1, 2, 3]
    end

    test "the categories of one group need not be neighbors" do
      [a, b] = Hierarchy.tree(["A/x", "B", "A/y"], "/")
      assert {a.name, Enum.map(a.children, & &1.index), b.name} == {"A", [0, 2], "B"}
    end

    test "the check refuses an empty part, a category two times and more than 8 groups" do
      assert {:error, message} = Hierarchy.check(["A//x"], "/")
      assert message =~ "a level with no name"

      assert {:error, message} = Hierarchy.check(["A/x", "A / x"], "/")
      assert message =~ "\"A/x\" shows two times"

      assert {:error, message} = Hierarchy.check(Enum.map(1..9, &"G#{&1}"), "/")
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

  describe "the separator and the levels" do
    test "the separator option gives a different text between two levels" do
      chart =
        chart(:treemap,
          categories: ["I/O > Disks", "I/O > Network", "CPU"],
          separator: " > ",
          elements: [Builder.series("Load", [3, 2, 5])]
        )

      [figure] = figure(chart)
      svg = LazyHTML.query(figure, "figure.chart > svg")
      assert texts(svg, ".chart-head") == ["I/O"]
      assert count(svg, "rect.chart-tile") == 3
    end

    test "a category can be a list of its levels" do
      chart =
        chart(:sunburst,
          categories: [["I/O", "Disks"], ["I/O", "Network"], ["CPU"]],
          elements: [Builder.series("Load", [3, 2, 5])]
        )

      [figure] = figure(chart)
      assert count(figure, "figure.chart > svg circle.chart-depth-2") == 2

      rows = texts(figure, "table.chart-table tbody th")
      assert rows == ["I/O / Disks", "I/O / Network", "CPU"]
    end

    test "a list of levels and the levels option are for a treemap or a sunburst" do
      assert_raise ArgumentError, ~r/a category of a bar chart is a string/, fn ->
        Builder.chart(:bar,
          title: "Load",
          categories: [["I/O", "Disks"]],
          elements: [Builder.series("Load", [3])]
        )
      end

      assert_raise ArgumentError, ~r/the separator option needs at least one character/, fn ->
        chart(:treemap, separator: "")
      end

      assert_raise ArgumentError, ~r/the levels option names columns of a CSV file/, fn ->
        chart(:treemap, levels: ["Division", "Team"])
      end
    end

    @tag :tmp_dir
    test "the levels option reads the levels from columns of a CSV file", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "hours.csv")

      File.write!(path, """
      Division,Team,Hours
      Production,Press,62
      Production,Paint,48
      R&D/Ops,Lab,20
      Office,,15
      """)

      chart = Builder.chart(:treemap, title: "Hours", src: path, levels: ["Division", "Team"])
      [figure] = figure(chart)
      svg = LazyHTML.query(figure, "figure.chart > svg")

      assert texts(svg, ".chart-head") == [
               "Production",
               "R&D/Ops"
             ]

      assert texts(svg, ".chart-part") == [
               "Press",
               "Paint",
               "Lab",
               "Office"
             ]
    end

    @tag :tmp_dir
    test "the levels option works with the frames option", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "hours.csv")

      File.write!(path, """
      year,Division,Team,Hours
      2024,Production,Press,62
      2024,Office,,15
      2025,Office,,30
      2025,Production,Press,40
      """)

      chart =
        Builder.chart(:sunburst,
          title: "Hours",
          src: path,
          frames: "year",
          levels: ["Division", "Team"]
        )

      [%{elements: [chart]}] =
        one_slide(chart).slides

      assert chart.categories == [["Production", "Press"], ["Office"]]
      assert Enum.map(chart.timeline, &hd(&1.elements).values) == [[62, 15], [40, 30]]
    end

    test "the reader gives an error for a missing column and an empty level before a name" do
      assert {:error, message} =
               Csv.table("Division,Hours\nA,1\n", "a.csv", levels: ["Division", "Team"])

      assert message =~ "has no column \"Team\" for the levels"

      assert {:error, message} =
               Csv.table("Division,Team,Hours\n,Press,1\n", "a.csv", levels: ["Division", "Team"])

      assert message =~
               "line 2 of the chart file \"a.csv\" has an empty level before a level with a name"
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

      assert LazyHTML.attribute(figure, "class") == ["chart chart-treemap"]
      svg = LazyHTML.query(figure, "figure.chart > svg")
      assert count(svg, "rect.chart-group") == 2
      assert count(svg, "rect.chart-tile") == 4

      assert texts(svg, ".chart-head") == [
               "Production",
               "Support"
             ]

      assert texts(svg, ".chart-part") == [
               "Press",
               "Paint",
               "Office",
               "Stops"
             ]

      assert texts(svg, ".chart-part-value") == [
               "60",
               "40",
               "30",
               "20"
             ]

      assert count(svg, "g.chart-c1 rect") == 3
    end

    test "each box of a treemap reads its place and its size from its channels" do
      [figure] = figure(chart(:treemap))
      [press | _] = LazyHTML.query(figure, "figure.chart > svg rect.chart-tile") |> Enum.to_list()
      [style] = LazyHTML.attribute(press, "style")

      assert style =~ ~r/--chart-u: [\d.]+; --chart-v: [\d.]+;/
      assert style =~ ~r/--chart-w: calc\(0 \+ \([\d.]+ - 0\) \* var\(--chart-shown, 1\)\);/
    end

    test "a sunburst draws a ring for each level, and a legend of the groups in percent" do
      [figure] = figure(chart(:sunburst))
      svg = LazyHTML.query(figure, "figure.chart > svg")

      assert count(svg, "circle.chart-ring.chart-depth-1") == 3
      assert count(svg, "circle.chart-ring.chart-depth-2") == 3
      assert count(svg, "line.chart-gap") == 6

      assert texts(svg, ".chart-name") ==
               ["Production 66.7%", "Office 20%", "Support 13.3%"]
    end

    test "the frames of a treemap move its boxes at their steps" do
      timeline = [
        Builder.frame("2024", elements: [Builder.series("Hours", [60, 40, 20, 30])]),
        Builder.frame("2025", elements: [Builder.series("Hours", [20, 40, 60, 30])])
      ]

      html =
        chart(:treemap, elements: [], timeline: timeline)
        |> one_slide()
        |> Expresso.Deck.render()

      assert html =~ ~r/section\[data-step="2"\] \[data-el="s1-e1"\] \{[^}]*--rw2: [\d.]+;/
      document = LazyHTML.from_document(html)
      assert count(document, ".screen .chart-frames figure.chart-copy") == 2
    end

    @tag :tmp_dir
    test "a CSV file gives the groups with a slash, as for the other charts", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "hours.csv")

      File.write!(
        path,
        "Machine,Hours\nProduction/Press,60\nProduction/Paint,40\nSupport/Stops,20\n"
      )

      [figure] = figure(Builder.chart(:treemap, title: "Hours", src: path))
      assert count(figure, "figure.chart > svg rect.chart-tile") == 3
    end
  end
end
