defmodule Expresso.ChartParallelSetsTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Chart.ParallelSets

  doctest ParallelSets

  defp chart(opts \\ []) do
    Builder.chart(
      :parallel_sets,
      Keyword.merge(
        [
          title: "Titanic",
          categories: [
            ["First", "Adult", "Yes"],
            ["First", "Adult", "No"],
            ["Crew", "Adult", "No"],
            "First/Adult/Yes"
          ],
          elements: [Builder.series("People", [5, 3, 8, 2])]
        ],
        opts
      )
    )
  end

  defp figure(chart) do
    [figure] =
      [Builder.slide("s", elements: [chart])]
      |> Builder.deck(name: "sets")
      |> Expresso.Deck.render()
      |> Floki.parse_document!()
      |> Floki.find(".screen figure.chart")

    figure
  end

  describe "the data" do
    test "each category is a path with one node for each column, and the same paths add" do
      chart = chart()

      assert chart.categories == [
               [{0, "First"}, {1, "Adult"}, {2, "Yes"}],
               [{0, "First"}, {1, "Adult"}, {2, "No"}],
               [{0, "Crew"}, {1, "Adult"}, {2, "No"}]
             ]

      assert [%{values: [7, 3, 8]}] = chart.elements
    end

    test "reveal makes one series for each node of the first column" do
      chart = chart(reveal: true)

      assert [%{name: "First", values: [7, 3, 0]}, %{name: "Crew", values: [0, 0, 8]}] =
               chart.elements
    end

    test "the frames share the paths" do
      chart =
        Builder.chart(:parallel_sets,
          title: "Votes",
          categories: [["Red", "Red"], ["Red", "Blue"]],
          timeline: [
            Builder.frame("2020", elements: [Builder.series("People", [4, 1])]),
            Builder.frame("2024", elements: [Builder.series("People", [2, 0])])
          ]
        )

      assert [%{elements: [%{values: [4, 1]}]}, %{elements: [%{values: [2, 0]}]}] =
               chart.timeline

      figure = figure(chart)
      assert figure |> Floki.find("figure.chart > svg g.chart-layer") |> length() == 2
    end
  end

  describe "the drawing" do
    test "each path is one ribbon, in the color of its first node" do
      figure = figure(chart())
      ribbons = Floki.find(figure, "figure.chart > svg path.chart-link")

      assert length(ribbons) == 3

      # A ribbon of three columns has one shape for each of its two links.
      for ribbon <- ribbons do
        [d] = Floki.attribute(ribbon, "d")
        assert d |> String.split("M") |> length() == 3
      end

      classes = Enum.map(ribbons, &(&1 |> Floki.attribute("class") |> hd()))
      assert Enum.at(classes, 0) == Enum.at(classes, 1)
      refute Enum.at(classes, 0) == Enum.at(classes, 2)
    end

    test "only the nodes of the first column have colors" do
      figure = figure(chart())

      assert Floki.attribute(figure, "class") == ["chart chart-parallel-sets"]
      rects = Floki.find(figure, "figure.chart > svg rect.chart-node")

      assert length(rects) == 5
      assert figure |> Floki.find("rect.chart-node-plain") |> length() == 3
      assert figure |> Floki.find("rect.chart-c1") |> length() == 1
      assert figure |> Floki.find("rect.chart-c2") |> length() == 1
    end

    test "a ribbon keeps its place through a node" do
      figure = figure(chart())
      [d | _] = figure |> Floki.find("path.chart-link") |> hd() |> Floki.attribute("d")

      # The first link ends at the node of the second column where the
      # second link starts.
      [first, second] = String.split(d, " M")

      [_x, end_y] =
        first
        |> String.split(" L")
        |> hd()
        |> String.split(" ")
        |> List.last()
        |> String.split(",")

      [_x, start_y] = second |> String.split(" ") |> hd() |> String.split(",")
      assert end_y == start_y
    end

    test "the nodes and their labels show with the chart, and the ribbons with their series" do
      figure = figure(chart(reveal: true))
      series = Floki.find(figure, "figure.chart > svg > g.chart-series")

      assert Enum.map(series, &Floki.attribute(&1, "data-on")) == [["1 2"], ["2"]]
      assert [nodes] = Floki.find(figure, "figure.chart > svg > g.chart-nodes")
      assert Floki.attribute(nodes, "data-on") == []
    end

    test "the levels give the titles of the columns and the headers of the table" do
      figure = figure(chart(levels: ["Class", "Age", "Survived"]))

      assert figure |> Floki.find("text.chart-column") |> Enum.map(&Floki.text/1) ==
               ["Class", "Age", "Survived"]

      assert figure |> Floki.find("thead th") |> Enum.map(&Floki.text/1) ==
               ["Class", "Age", "Survived", "Value"]

      assert figure
             |> Floki.find("tbody tr")
             |> hd()
             |> Floki.find("th, td")
             |> Enum.map(&Floki.text/1) ==
               ["First", "Adult", "Yes", "7"]
    end
  end

  describe "the errors" do
    test "a path with another number of columns" do
      assert_raise ArgumentError, ~r/names one node for each column/, fn ->
        Builder.chart(:parallel_sets,
          title: "Paths",
          categories: [["A", "B"], ["A", "B", "C"]],
          elements: [Builder.series("People", [1, 2])]
        )
      end
    end

    test "levels that do not name each column, and a node entity with a column" do
      assert_raise ArgumentError,
                   ~r/the levels option of a parallel sets chart gives a title for each column, so give 3 titles/,
                   fn -> chart(levels: ["A", "B"]) end

      assert_raise ArgumentError, ~r/takes no column option/, fn ->
        Builder.chart(:parallel_sets,
          title: "Votes",
          flows: [Builder.flow("Red", "Blue", 4), Builder.node("Red", column: 2)]
        )
      end
    end
  end
end
