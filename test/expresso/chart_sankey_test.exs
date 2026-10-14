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

  # A chart of the flows of @flows. The option `nodes` adds node entities to
  # the flows, as the DSL puts them under the same key.
  defp chart(opts \\ []) do
    {nodes, opts} = Keyword.pop(opts, :nodes, [])
    flows = for {from, to, value} <- @flows, do: Builder.flow(from, to, value)
    Builder.chart(:sankey, Keyword.merge([title: "Energy", flows: flows ++ nodes], opts))
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
            flow "Coal", "Electricity", 120
            flow "Electricity", "Homes", 120.5
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

    test "a sankey takes no effect :grow, and no reveal with frames" do
      assert_raise ArgumentError, ~r/with frames takes no reveal/, fn ->
        Builder.chart(:sankey,
          title: "Frames",
          reveal: true,
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

    test "each label is at the right of its node, and the last column keeps room for its labels" do
      svg = chart() |> figure() |> Floki.find("figure.chart > svg")
      labels = Floki.find(svg, "text.chart-node-label")

      assert labels |> Enum.map(&hd(Floki.attribute(&1, "text-anchor"))) |> Enum.uniq() == [
               "start"
             ]

      # "Industry 125" is the widest label of the last column: 12 characters.
      [right] =
        for label <- labels, Floki.text(label) == "Industry 125" do
          {x, ""} = label |> Floki.attribute("x") |> hd() |> Float.parse()
          x + 12 * 10
        end

      assert right <= 800
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

  describe "the frames" do
    defp frames do
      Builder.chart(:sankey,
        title: "Energy",
        timeline: [
          Builder.frame("2015",
            flows: [
              Builder.flow("Coal", "Electricity", 180),
              Builder.flow("Electricity", "Homes", 180)
            ]
          ),
          Builder.frame("2025",
            flows: [
              Builder.flow("Coal", "Electricity", 40),
              Builder.flow("Solar", "Electricity", 90),
              Builder.flow("Electricity", "Homes", 130)
            ]
          )
        ]
      )
    end

    test "the flows of each frame give the links of each frame, with zero for a link that is not in it" do
      chart = frames()

      assert chart.categories == [
               ["Coal", "Electricity"],
               ["Electricity", "Homes"],
               ["Solar", "Electricity"]
             ]

      assert [[%{values: [180, 180, 0]}], [%{values: [40, 130, 90]}]] =
               Enum.map(chart.timeline, & &1.elements)
    end

    test "a sankey with frames draws a layer for each frame, and the layers fade at their steps" do
      html = render(frames())
      figure = html |> Floki.parse_document!() |> Floki.find(".screen figure.chart")
      layers = Floki.find(figure, "figure.chart > svg > g.chart-layer")

      assert Enum.map(layers, &Floki.attribute(&1, "style")) == [
               ["opacity: var(--k1, 1);"],
               ["opacity: var(--k2, 0);"]
             ]

      # Solar has no flow in 2015, so the first layer has no node for it.
      [first, second] = layers
      assert first |> Floki.find("rect.chart-node") |> length() == 3
      assert second |> Floki.find("rect.chart-node") |> length() == 4
      assert Floki.text(Floki.find(figure, "text.chart-frame")) =~ "2015"
      assert html =~ ~r/section\[data-step="2"\] \[data-el="s1-e1"\] \{[^}]*--k2: 1;/

      headers = figure |> Floki.find("table.chart-table thead th") |> Enum.map(&Floki.text/1)
      assert headers == ["From", "To", "2015", "2025"]
    end

    test "the frames share the columns, the order and the scale of the nodes" do
      [one, two] =
        Sankey.layout_frames(
          [
            [%{from: "A", to: "B", value: 10, series: 1}],
            [
              %{from: "A", to: "B", value: 5, series: 1},
              %{from: "C", to: "B", value: 5, series: 1}
            ]
          ],
          8
        )

      [a1, b1] = one.nodes
      [a2, b2, c2] = two.nodes
      assert {a1.name, b1.name, a2.name, b2.name, c2.name} == {"A", "B", "A", "B", "C"}
      assert_in_delta a2.height * 2, a1.height, 0.01
      assert_in_delta b2.height, b1.height, 0.01
      assert {a1.color, b1.color} == {a2.color, b2.color}
    end

    @tag :tmp_dir
    test "a CSV file gives the frames with the frames option and the levels option", %{
      tmp_dir: tmp_dir
    } do
      path = Path.join(tmp_dir, "energy.csv")

      File.write!(path, """
      year,from,to,GWh
      2015,Coal,Electricity,180
      2015,Electricity,Homes,180
      2025,Coal,Electricity,40
      2025,Electricity,Homes,40
      """)

      chart =
        Builder.chart(:sankey, title: "Energy", src: path, levels: ["from", "to"], frames: "year")

      figure = figure(chart)
      assert figure |> Floki.find("g.chart-layer") |> length() == 2

      assert figure |> Floki.find("table.chart-table tbody tr") |> Enum.map(&Floki.text/1) ==
               ["CoalElectricity18040", "ElectricityHomes18040"]
    end

    test "a frame holds flows or a series, and a flow in a frame is for a sankey" do
      assert_raise ArgumentError, ~r/a bar chart takes no flow/, fn ->
        Builder.chart(:bar,
          title: "Bar",
          timeline: [Builder.frame("1", flows: [Builder.flow("A", "B", 1)])]
        )
      end

      assert_raise ArgumentError,
                   ~r/each frame of a sankey with flows holds flows, and no series/,
                   fn ->
                     Builder.chart(:sankey,
                       title: "Mixed",
                       timeline: [
                         Builder.frame("1", flows: [Builder.flow("A", "B", 1)]),
                         Builder.frame("2", elements: [Builder.series("x", [1])])
                       ]
                     )
                   end
    end
  end

  describe "the node entity" do
    defp rect_of(figure, label) do
      figure
      |> Floki.find("figure.chart > svg rect.chart-node")
      |> Enum.zip(Floki.find(figure, "figure.chart > svg text.chart-node-label"))
      |> Enum.find_value(fn {rect, text} ->
        String.starts_with?(Floki.text(text), label) && rect
      end)
    end

    defp number(element, attribute) do
      {number, ""} = element |> Floki.attribute(attribute) |> hd() |> Float.parse()
      number
    end

    test "a node gives the label, the class, the column and the order of a node" do
      figure =
        chart(
          nodes: [
            Builder.node("Heat", label: "District heat", class: "warm"),
            Builder.node("Industry", column: 4),
            Builder.node("Gas", order: 0)
          ]
        )
        |> figure()

      labels = figure |> Floki.find("text.chart-node-label") |> Enum.map(&Floki.text/1)
      assert "District heat 40" in labels

      assert figure |> Floki.find("rect.chart-node.warm") |> length() == 1
      assert number(rect_of(figure, "Industry"), "x") > number(rect_of(figure, "Homes"), "x")
      assert number(rect_of(figure, "Gas"), "y") < number(rect_of(figure, "Coal"), "y")

      rows = figure |> Floki.find("table.chart-table tbody tr") |> Enum.map(&Floki.text/1)
      assert "GasDistrict heat40" in rows
    end

    test "a node is for a sankey, one time, for a node of the flows, in a later column" do
      assert_raise ArgumentError, ~r/a bar chart takes no node/, fn ->
        Builder.chart(:bar,
          title: "Bar",
          categories: ["a"],
          elements: [Builder.series("x", [1])],
          flows: [Builder.node("a")]
        )
      end

      assert_raise ArgumentError, ~r/"Gas" has two node entities/, fn ->
        chart(nodes: [Builder.node("Gas"), Builder.node("Gas", label: "Natural gas")])
      end

      assert_raise ArgumentError, ~r/"Oil" names no node of the flows/, fn ->
        chart(nodes: [Builder.node("Oil")])
      end

      assert_raise ArgumentError,
                   ~r/"Electricity" in column 3 to "Homes" in column 2 goes to the left/,
                   fn ->
                     chart(
                       nodes: [
                         Builder.node("Electricity", column: 3),
                         Builder.node("Homes", column: 2)
                       ]
                     )
                   end
    end
  end

  describe "the labels" do
    test "a short node shows its label when the label has room in its column" do
      figure =
        Builder.chart(:sankey,
          title: "Funnel",
          flows: [
            Builder.flow("Visits", "Trial", 2400),
            Builder.flow("Visits", "Bounced", 7600),
            Builder.flow("Trial", "Paid", 600),
            Builder.flow("Trial", "Left", 1800),
            Builder.flow("Paid", "Renewed", 450),
            Builder.flow("Paid", "Cancelled", 150)
          ]
        )
        |> figure()

      labels = figure |> Floki.find("text.chart-node-label") |> Enum.map(&Floki.text/1)

      assert "Cancelled 150" in labels
      assert length(labels) == 7
    end

    test "a short node hides its label when it would cover another label" do
      figure =
        Builder.chart(:sankey,
          title: "Small",
          flows: [
            Builder.flow("A", "B", 1000),
            Builder.flow("A", "C", 2),
            Builder.flow("A", "D", 2)
          ]
        )
        |> figure()

      labels = figure |> Floki.find("text.chart-node-label") |> Enum.map(&Floki.text/1)

      assert "C 2" in labels
      refute "D 2" in labels
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

  describe "an alluvial chart" do
    defp alluvial(opts \\ []) do
      Builder.chart(
        :alluvial,
        Keyword.merge(
          [
            title: "Commute",
            categories: [["Car", "Car", "Home"], ["Car", "Bike", "Bike"], ["Bike", "Car", "Car"]],
            elements: [Builder.series("People", [5, 3, 2])]
          ],
          opts
        )
      )
    end

    test "one name is one node in each column, and a name can follow the same name" do
      chart = alluvial()

      assert chart.categories == [
               [{0, "Car"}, {1, "Car"}],
               [{1, "Car"}, {2, "Home"}],
               [{0, "Car"}, {1, "Bike"}],
               [{1, "Bike"}, {2, "Bike"}],
               [{0, "Bike"}, {1, "Car"}],
               [{1, "Car"}, {2, "Car"}]
             ]

      assert [%{values: [5, 5, 3, 3, 2, 2]}] = chart.elements
    end

    test "the nodes of one name have one color and one place in each column" do
      figure = alluvial() |> figure()
      rects = Floki.find(figure, "figure.chart > svg rect.chart-node")

      labels =
        figure
        |> Floki.find("figure.chart > svg text.chart-node-label")
        |> Enum.map(&Floki.text/1)

      assert labels == ["Car 8", "Car 7", "Home 5", "Bike 3", "Bike 3", "Bike 2", "Car 2"]

      colors =
        rects
        |> Enum.zip(labels)
        |> Map.new(fn {rect, label} ->
          [class] = Floki.attribute(rect, "class")
          {label, class}
        end)

      assert colors["Car 8"] == colors["Car 7"]
      assert colors["Car 7"] == colors["Car 2"]
      assert colors["Bike 2"] == colors["Bike 3"]
      refute colors["Car 8"] == colors["Bike 2"]

      # The names keep the order of the data in each column: Car, Home, Bike.
      ys =
        for {rect, label} <- Enum.zip(rects, labels), into: %{} do
          {label, rect |> Floki.attribute("y") |> hd() |> Float.parse() |> elem(0)}
        end

      assert ys["Car 2"] < ys["Home 5"]
      assert ys["Home 5"] < ys["Bike 3"]
      assert ys["Car 8"] < ys["Bike 2"]
    end

    test "the levels give a title to each column, and the table names the column" do
      figure = alluvial(levels: ["2020", "2023", "2026"]) |> figure()

      assert figure |> Floki.find("text.chart-column") |> Enum.map(&Floki.text/1) ==
               ["2020", "2023", "2026"]

      rows =
        figure
        |> Floki.find("table.chart-table tbody tr")
        |> Enum.map(fn row -> row |> Floki.find("th, td") |> Enum.map(&Floki.text/1) end)

      assert ["Car (2020)", "Car (2023)", "5"] in rows
      assert ["Car (2023)", "Home (2026)", "5"] in rows

      untitled = alluvial() |> figure()
      assert Floki.find(untitled, "text.chart-column") == []
      assert Floki.text(Floki.find(untitled, "tbody tr th")) =~ "Car (Column 1)"
    end

    test "a flow is a path of two columns, and a node entity applies to each column" do
      chart =
        Builder.chart(:alluvial,
          title: "Votes",
          flows: [
            Builder.flow("Red", "Red", 40),
            Builder.flow("Red", "Blue", 10),
            Builder.flow("Blue", "Blue", 30),
            Builder.node("Red", label: "Red party", class: "red")
          ]
        )

      figure = figure(chart)

      assert figure |> Floki.find("rect.chart-node.red") |> length() == 2

      assert figure |> Floki.find("text.chart-node-label") |> Enum.map(&Floki.text/1) ==
               ["Red party 50", "Red party 40", "Blue 40", "Blue 30"]
    end

    @tag :tmp_dir
    test "a CSV file with levels gives the paths and the titles", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "commute.csv")
      File.write!(path, "start,end,people\nCar,Car,5\nCar,Bike,3\n")

      figure =
        Builder.chart(:alluvial, title: "Commute", src: path, levels: ["start", "end"])
        |> figure()

      assert figure |> Floki.find("text.chart-column") |> Enum.map(&Floki.text/1) ==
               ["start", "end"]

      assert figure |> Floki.find("rect.chart-node") |> length() == 3
    end

    test "reveal shows one column of links at each step" do
      chart = alluvial(reveal: true)

      assert [%{values: [5, 0, 3, 0, 2, 0]}, %{values: [0, 5, 0, 3, 0, 2]}] = chart.elements
    end

    test "the errors" do
      assert_raise ArgumentError, ~r/gives a title for each column, so it names 3 columns/, fn ->
        alluvial(levels: ["2020", "2026"])
      end

      assert_raise ArgumentError,
                   ~r/node entity of an alluvial chart takes no column option/,
                   fn ->
                     Builder.chart(:alluvial,
                       title: "Votes",
                       flows: [Builder.flow("Red", "Red", 4), Builder.node("Red", column: 2)]
                     )
                   end

      assert_raise ArgumentError,
                   ~r/the levels option of a sankey names two columns or more/,
                   fn ->
                     alluvial(levels: ["2020"])
                   end
    end
  end
end
