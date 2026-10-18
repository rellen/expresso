defmodule Expresso.ChartFlowCopiesTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart.Sankey

  defp figure(chart), do: chart |> one_slide() |> document() |> screen("figure.chart") |> only!()

  # The class and the geometry of each mark of a drawing, in the order of
  # the document.
  defp marks(node) do
    for mark <- LazyHTML.query(node, "path, rect") do
      for attribute <- ~w(class d x y width height),
          do: mark |> LazyHTML.attribute(attribute) |> List.first()
    end
  end

  # The marks of each layer of the present view, and the marks of each copy
  # for paper and for the handout view.
  defp layers_and_copies(figure) do
    layers = figure |> LazyHTML.query("figure.chart > svg > g.chart-layer") |> Enum.map(&marks/1)
    copies = figure |> LazyHTML.query("figure.chart-copy > svg") |> Enum.map(&marks/1)
    {layers, copies}
  end

  defp alluvial(timeline) do
    Builder.chart(:alluvial,
      title: "Travel",
      levels: ["2020", "2022", "2024"],
      categories: ["Car/Car/Bus", "Car/Bus"],
      timeline: for({label, values} <- timeline, do: frame(label, values))
    )
  end

  defp frame(label, values),
    do: Builder.frame(label, elements: [Builder.series("People", values)])

  describe "the copies of a chart with frames" do
    test "each copy of a sankey has the colors, the scale and the columns of its layer" do
      figure =
        Builder.chart(:sankey,
          title: "T",
          timeline: [
            Builder.frame("1", flows: [Builder.flow("A", "Y", 10)]),
            Builder.frame("2", flows: [Builder.flow("X", "Y", 4)])
          ]
        )
        |> figure()

      {layers, copies} = layers_and_copies(figure)
      assert length(copies) == 2
      assert copies == layers

      [_first, second] = figure |> LazyHTML.query("figure.chart-copy") |> Enum.to_list()
      assert count(second, "rect.chart-node.chart-c3") == 1
    end

    test "each copy of a chord chart and of an alluvial chart has the layout of its layer" do
      chord =
        Builder.chart(:chord,
          title: "Trade",
          timeline: [
            Builder.frame("1", flows: [Builder.flow("A", "B", 10), Builder.flow("B", "C", 2)]),
            Builder.frame("2", flows: [Builder.flow("C", "A", 4)])
          ]
        )

      for chart <- [chord, alluvial([{"1", [2, 3]}, {"2", [4, 1]}])] do
        {layers, copies} = chart |> figure() |> layers_and_copies()
        assert length(copies) == 2
        assert copies == layers
      end
    end

    test "a frame without a node of the last column renders" do
      {layers, copies} =
        alluvial([{"1", [2, 3]}, {"2", [0, 3]}]) |> figure() |> layers_and_copies()

      assert copies == layers

      sankey =
        Builder.chart(:sankey,
          title: "T",
          timeline: [
            Builder.frame("1", flows: [Builder.flow("A", "Losses", 10)]),
            Builder.frame("2", flows: [Builder.flow("A", "Y", 4)])
          ],
          flows: [Builder.node("Losses", column: 4)]
        )

      {layers, copies} = sankey |> figure() |> layers_and_copies()
      assert copies == layers
    end

    test "a copy has no morph key, so the morph between two slides finds one mark" do
      chart =
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North", "South"],
          timeline: [
            Builder.frame("2024", elements: [Builder.series("S", [1, 2], morph: "orders")]),
            Builder.frame("2025", elements: [Builder.series("S", [3, 4])])
          ]
        )

      document = chart |> one_slide() |> document()
      assert count(screen(document, "figure.chart"), ~s([data-morph-key="orders"])) == 1
      assert count(screen(document, "figure.chart-copy"), "[data-morph-key]") == 0
    end
  end

  describe "a flow with the value zero" do
    test "the checks do not count it, so the error names the problem" do
      assert_raise ArgumentError, ~r/so give 2 titles/, fn ->
        Builder.chart(:alluvial,
          title: "T",
          levels: ["2020", "2022", "2024"],
          categories: ["Car/Car/Bus", "Car/Bus"],
          elements: [Builder.series("People", [0, 3])]
        )
      end

      assert_raise ArgumentError, ~r/the node entity "C" names no node of the flows/, fn ->
        Builder.chart(:sankey,
          title: "T",
          flows: [
            Builder.flow("A", "B", 5),
            Builder.flow("B", "C", 0),
            Builder.node("C", column: 3)
          ]
        )
      end
    end

    test "the layout ignores the column of a node that no link touches" do
      links = [
        %{from: "A", to: "B", value: 5, series: 1},
        %{from: "B", to: "C", value: 0, series: 1}
      ]

      settings = %{"C" => %Expresso.Element.Node{name: "C", column: 3}}

      layout = Sankey.layout(links, 8, settings)
      assert Enum.map(layout.nodes, & &1.name) == ["A", "B"]
      assert length(layout.xs) == 2
    end
  end

  describe "a node inside a frame" do
    test "the Builder and the DSL give the error of the placement check" do
      assert_raise ArgumentError, ~r/a node is inside a frame, and a frame holds flow/, fn ->
        Builder.chart(:sankey,
          title: "T",
          timeline: [
            Builder.frame("1", flows: [Builder.flow("a", "b", 1), Builder.node("b")]),
            Builder.frame("2", flows: [Builder.flow("a", "b", 2)])
          ]
        )
      end

      assert_raise Spark.Error.DslError,
                   ~r/a node is inside a frame, and a frame holds flow/,
                   fn ->
                     defmodule NodeInFrame do
                       use Expresso

                       slide "s" do
                         chart :sankey do
                           title "t"

                           frame "2024" do
                             flow "a", "b", 1
                             node "b", label: "Bee"
                           end

                           frame "2025" do
                             flow "a", "b", 2
                           end
                         end
                       end
                     end
                   end
    end
  end

  describe "reveal" do
    test "the steps of a sankey follow the column of a node entity" do
      chart =
        Builder.chart(:sankey,
          title: "T",
          reveal: true,
          flows: [
            Builder.flow("A", "B", 5),
            Builder.flow("C", "B", 3),
            Builder.node("C", column: 2)
          ]
        )

      assert [%{values: [5, 0]}, %{values: [0, 3]}] = chart.elements

      steps =
        chart
        |> figure()
        |> LazyHTML.query("figure.chart > svg > g.chart-series")
        |> Enum.map(&LazyHTML.attribute(&1, "data-on"))

      assert steps == [["1 2"], ["2"]]
    end
  end
end
