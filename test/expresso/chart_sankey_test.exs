defmodule Expresso.ChartSankeyTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Chart.Sankey

  doctest Sankey

  @flows [
    {"Coal", "Electricity", 120},
    {"Gas", "Electricity", 95},
    {"Gas", "Heat", 40},
    {"Electricity", "Homes", 90},
    {"Electricity", "Industry", 125},
    {"Heat", "Homes", 40}
  ]

  defp chart(opts \\ []) do
    flows = for {from, to, value} <- @flows, do: Builder.flow(from, to, value)
    Builder.chart(:sankey, Keyword.merge([title: "Energy", flows: flows], opts))
  end

  defp render(chart) do
    [Builder.slide("s", elements: [chart])]
    |> Builder.deck(name: "flows")
    |> Expresso.Deck.render()
  end

  defp figure(chart) do
    [figure] = chart |> render() |> Floki.parse_document!() |> Floki.find(".screen figure.chart")
    figure
  end

  describe "the data" do
    test "a flow is a category of two nodes with its value" do
      chart = chart()

      assert chart.categories == Enum.map(@flows, fn {from, to, _value} -> [from, to] end)
      assert [%{name: "Value", values: [120, 95, 40, 90, 125, 40]}] = chart.elements
      assert chart.flows == []
    end

    test "a category is a path, and the values of the same link add" do
      chart =
        Builder.chart(:sankey,
          title: "Paths",
          categories: [["A", "B", "C"], "A/B", "B / D"],
          elements: [Builder.series("People", [2, 3, 4])]
        )

      assert chart.categories == [["A", "B"], ["B", "C"], ["B", "D"]]
      assert [%{name: "People", values: [5, 2, 4]}] = chart.elements
    end

    test "the DSL takes flow entities" do
      defmodule FlowDeck do
        use Expresso

        slide "energy" do
          chart :sankey do
            title "Energy"
            value_label "TWh"
            flow("Coal", "Electricity", 120)
            flow("Electricity", "Homes", 120.5)
          end
        end
      end

      {:ok, deck} = Expresso.to_deck(FlowDeck)
      [%{elements: [chart]}] = deck.slides
      assert chart.categories == [["Coal", "Electricity"], ["Electricity", "Homes"]]
      assert [%{name: "TWh", values: [120, 120.5]}] = chart.elements
    end

    @tag :tmp_dir
    test "the levels option reads an edge list or the records of an alluvial chart", %{
      tmp_dir: tmp_dir
    } do
      edges = Path.join(tmp_dir, "edges.csv")

      File.write!(
        edges,
        "from,to,TWh\nCoal,Electricity,120\nGas,Electricity,95\nCoal,Electricity,5\n"
      )

      chart = Builder.chart(:sankey, title: "Energy", src: edges, levels: ["from", "to"])
      table = figure(chart) |> Floki.find("table.chart-table tbody tr") |> Enum.map(&Floki.text/1)
      assert table == ["CoalElectricity125", "GasElectricity95"]

      records = Path.join(tmp_dir, "records.csv")

      File.write!(records, """
      class,sex,survived,people
      First,Female,Yes,141
      First,Male,No,118
      Third,Male,No,422
      """)

      chart =
        Builder.chart(:sankey,
          title: "Survival",
          src: records,
          levels: ["class", "sex", "survived"]
        )

      rows = figure(chart) |> Floki.find("table.chart-table tbody tr") |> Enum.map(&Floki.text/1)

      assert rows == [
               "FirstFemale141",
               "FemaleYes141",
               "FirstMale118",
               "MaleNo540",
               "ThirdMale422"
             ]
    end
  end

  describe "the errors" do
    test "a loop, a flow to the same node, a path of one node and a negative value" do
      assert_raise ArgumentError, ~r/make a loop: A → B → A/, fn ->
        Builder.chart(:sankey,
          title: "Loop",
          flows: [Builder.flow("A", "B", 1), Builder.flow("B", "A", 1)]
        )
      end

      assert_raise ArgumentError, ~r/goes from "A" to "A"/, fn ->
        Builder.chart(:sankey, title: "Self", flows: [Builder.flow("A", "A", 1)])
      end

      assert_raise ArgumentError, ~r/names one node/, fn ->
        Builder.chart(:sankey,
          title: "One",
          categories: ["A"],
          elements: [Builder.series("x", [1])]
        )
      end

      assert_raise ArgumentError, ~r/zero or more/, fn ->
        Builder.chart(:sankey, title: "Minus", flows: [Builder.flow("A", "B", -1)])
      end
    end

    test "a flow is for a sankey, and a sankey takes one form of data" do
      assert_raise ArgumentError, ~r/a bar chart takes no flow/, fn ->
        Builder.chart(:bar, title: "Bar", flows: [Builder.flow("A", "B", 1)])
      end

      assert_raise ArgumentError, ~r/takes flow entities, or categories and a series/, fn ->
        chart(categories: [["A", "B"]], elements: [Builder.series("x", [1])])
      end

      assert_raise ArgumentError, ~r/a sankey has one series/, fn ->
        Builder.chart(:sankey,
          title: "Two",
          categories: [["A", "B"]],
          elements: [Builder.series("x", [1]), Builder.series("y", [2])]
        )
      end
    end

    test "a sankey takes no frames, no effect :grow and no count" do
      assert_raise ArgumentError, ~r/a sankey takes no frames/, fn ->
        Builder.chart(:sankey,
          title: "Frames",
          categories: [["A", "B"]],
          timeline: [Builder.frame("1", elements: [Builder.series("x", [1])])]
        )
      end

      assert_raise ArgumentError, ~r/no effect :grow/, fn -> chart(effect: :grow) end

      assert_raise ArgumentError, ~r/no effect :grow/, fn ->
        Builder.chart(:sankey,
          title: "Grow",
          categories: [["A", "B"]],
          elements: [Builder.series("x", [1], effect: :grow)]
        )
      end
    end
  end

  describe "the drawing" do
    test "a sankey draws a node for each node, a ribbon for each link and a label for each node" do
      svg = chart() |> figure() |> Floki.find("figure.chart > svg")

      assert svg |> Floki.find("path.chart-link") |> length() == 6
      assert svg |> Floki.find("rect.chart-node") |> length() == 6

      assert svg |> Floki.find("text.chart-node-label") |> Enum.map(&Floki.text/1) == [
               "Coal 120",
               "Electricity 215",
               "Gas 135",
               "Heat 40",
               "Homes 130",
               "Industry 125"
             ]

      [path | _] = svg |> Floki.find("path.chart-link") |> Floki.attribute("d")
      assert path =~ ~r/^M[\d.]+,[\d.]+ C[\d.]+,[\d.]+ [\d.]+,[\d.]+ [\d.]+,[\d.]+ L.* Z$/
    end

    test "the nodes of the last column have their labels at the left" do
      svg = chart() |> figure() |> Floki.find("figure.chart > svg")

      anchors =
        svg
        |> Floki.find("text.chart-node-label")
        |> Enum.map(&{Floki.text(&1), hd(Floki.attribute(&1, "text-anchor"))})

      assert {"Homes 130", "end"} in anchors
      assert {"Coal 120", "start"} in anchors
    end

    test "values false shows the names of the nodes only" do
      labels = chart(values: false) |> figure() |> Floki.find("text.chart-node-label")
      assert hd(Enum.map(labels, &Floki.text/1)) == "Coal"
    end

    test "the table holds a row for each link" do
      figure = chart(value_label: "TWh") |> figure()

      assert figure |> Floki.find("table.chart-table caption") |> Floki.text() == "Energy (TWh)"

      assert figure |> Floki.find("table.chart-table thead th") |> Enum.map(&Floki.text/1) ==
               ["From", "To", "TWh"]

      assert figure |> Floki.find("table.chart-table tbody tr") |> length() == 6
    end
  end

  describe "reveal" do
    test "reveal makes one series for each column of links, and each shows at its own step" do
      chart = chart(reveal: true)

      assert [%{values: [120, 95, 40, 0, 0, 0]}, %{values: [0, 0, 0, 90, 125, 40]}] =
               chart.elements

      figure = chart |> figure()
      [first, second] = Floki.find(figure, "figure.chart > svg > g.chart-series")

      assert Floki.attribute(first, "data-on") == ["1 2"]
      assert Floki.attribute(second, "data-on") == ["2"]
      assert first |> Floki.find("path.chart-link") |> length() == 3
      assert second |> Floki.find("path.chart-link") |> length() == 3

      # The nodes of the first column, and the nodes that a link of the first
      # column reaches, show at the first step.
      assert first |> Floki.find("rect.chart-node") |> length() == 4
      assert second |> Floki.find("rect.chart-node") |> length() == 2

      labels = Floki.find(figure, "figure.chart > svg > g.chart-labels")
      assert Enum.map(labels, &Floki.attribute(&1, "data-on")) == [["1 2"], ["2"]]
    end
  end
end
