defmodule Expresso.ChartChordTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart.Chord

  doctest Chord

  defp chart(opts \\ []) do
    Builder.chart(
      :chord,
      [
        title: "Moves",
        flows: [
          Builder.flow("A", "B", 4),
          Builder.flow("B", "A", 2),
          Builder.flow("A", "C", 1),
          Builder.flow("C", "B", 3)
        ]
      ] ++ opts
    )
  end

  defp figure(chart), do: chart |> one_slide() |> document() |> screen("figure.chart") |> only!()

  defp labels(figure),
    do: texts(figure, "text.chart-node-label")

  describe "the drawing" do
    test "each node is an arc, and each flow is a chord in the color of its source" do
      figure = figure(chart())

      assert LazyHTML.attribute(figure, "class") == ["chart chart-chord"]
      assert count(figure, "g.chart-nodes path.chart-node") == 3
      assert count(figure, "path.chart-chord") == 4

      # A flows out 5 and in 2, B out 2 and in 7, and C out 3 and in 1.
      assert labels(figure) == ["A 7", "B 9", "C 4"]

      colors =
        figure
        |> LazyHTML.query("path.chart-chord")
        |> Enum.map(&(&1 |> LazyHTML.attribute("class") |> hd()))

      assert Enum.at(colors, 0) == Enum.at(colors, 2)
      refute Enum.at(colors, 0) == Enum.at(colors, 1)
    end

    test "a chord follows the inner edge at its two ends and passes the center" do
      [d | _] =
        chart()
        |> figure()
        |> LazyHTML.query("path.chart-chord")
        |> Enum.at(0)
        |> LazyHTML.attribute("d")

      assert [_, _] = Regex.scan(~r/Q400,225 /, d)
      assert [_, _] = Regex.scan(~r/ A\d/, d)
    end

    test "the table holds each flow" do
      rows =
        chart()
        |> figure()
        |> LazyHTML.query("table.chart-table tbody tr")
        |> Enum.map(fn row -> texts(row, "th, td") end)

      assert rows == [["A", "B", "4"], ["B", "A", "2"], ["A", "C", "1"], ["C", "B", "3"]]
    end

    test "a node entity gives a label, a class and an order" do
      figure =
        Builder.chart(:chord,
          title: "Moves",
          flows: [
            Builder.flow("A", "B", 4),
            Builder.flow("B", "C", 2),
            Builder.node("C", label: "Sea", class: "far", order: 0)
          ]
        )
        |> figure()

      assert labels(figure) == ["Sea 2", "A 4", "B 6"]
      assert count(figure, "path.chart-node.far") == 1
    end
  end

  describe "the steps" do
    test "reveal makes one series for each source, and the arcs show with the chart" do
      chart = chart(reveal: true)

      assert [
               %{name: "A", values: [4, 0, 1, 0]},
               %{name: "B", values: [0, 2, 0, 0]},
               %{name: "C", values: [0, 0, 0, 3]}
             ] = chart.elements

      figure = figure(chart)
      series = LazyHTML.query(figure, "figure.chart > svg > g.chart-series")

      assert Enum.map(series, &LazyHTML.attribute(&1, "data-on")) == [["1 2 3"], ["2 3"], ["3"]]

      assert [nodes] =
               LazyHTML.query(figure, "figure.chart > svg > g.chart-nodes") |> Enum.to_list()

      assert LazyHTML.attribute(nodes, "data-on") == []
    end

    test "frames share one scale, so a smaller frame leaves a gap in the ring" do
      chart =
        Builder.chart(:chord,
          title: "Moves",
          timeline: [
            Builder.frame("2024", flows: [Builder.flow("A", "B", 4), Builder.flow("B", "A", 4)]),
            Builder.frame("2025", flows: [Builder.flow("A", "B", 2), Builder.flow("B", "A", 2)])
          ]
        )

      [first, second] = Chord.layout(frames(chart), 52, %{})
      ends = fn layout -> layout.arcs |> List.last() |> Map.get(:d) end

      assert length(first.arcs) == 2
      refute ends.(first) == ends.(second)
      assert figure(chart) |> LazyHTML.query("g.chart-layer") |> Enum.count() == 2
    end
  end

  describe "the errors" do
    test "a flow to the same node and a node entity with a column" do
      assert_raise ArgumentError, ~r/goes from "A" to "A"/, fn ->
        Builder.chart(:chord, title: "Self", flows: [Builder.flow("A", "A", 1)])
      end

      assert_raise ArgumentError, ~r/a node entity of a chord chart takes no column option/, fn ->
        chart(flows: [Builder.flow("A", "B", 1), Builder.node("A", column: 2)])
      end
    end
  end

  defp frames(chart) do
    for frame <- chart.timeline do
      [series] = frame.elements

      for {[from, to], value} <- Enum.zip(chart.categories, series.values),
          do: %{from: from, to: to, value: value, series: 1}
    end
  end
end
