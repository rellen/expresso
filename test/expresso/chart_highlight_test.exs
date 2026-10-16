defmodule Expresso.ChartHighlightTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.{Chart, Focus}

  defmodule Deck do
    use Expresso

    name "highlight"

    slide "orders" do
      chart :bar do
        title "Orders and returns"
        categories ["2023", "2024"]
        highlight ["Returns", ["Orders", "Returns"]]
        whole_first true
        series "Orders", [180, 240]
        series "Returns", [22, 19]
      end
    end
  end

  defp bars(opts \\ []) do
    Builder.chart(
      :bar,
      [
        title: "Orders",
        categories: ["2023", "2024"],
        elements: [Builder.series("Orders", [120, 180]), Builder.series("Returns", [14, 22])]
      ] ++ opts
    )
  end

  defp slide(elements), do: [Builder.slide("s", elements: elements)] |> Builder.deck(name: "c")

  defp chart(deck) do
    [slide] = deck.slides
    Enum.find(slide.elements, &match?(%Chart{}, &1))
  end

  defp document(deck), do: deck |> Expresso.Deck.render() |> LazyHTML.from_document()

  # The rules of the groups in the generated style block.
  defp rules(document) do
    document
    |> texts("head style")
    |> List.last()
    |> String.split("\n")
    |> Enum.filter(&(&1 =~ "--chart-dim"))
  end

  describe "the steps" do
    test "the DSL takes highlight and whole_first, and the whole chart shows first" do
      deck = Expresso.parse(Deck)
      [slide] = deck.slides

      assert %Chart{highlight: ["Returns", ["Orders", "Returns"]], whole_first: true} =
               chart = chart(deck)

      assert [%Focus{series: [2], steps: [2]}, %Focus{series: [1, 2], steps: [3]}] = chart.focus
      assert slide.metadata.max_step == 3
    end

    test "each group takes one step after a pause, and a later element takes the next step" do
      deck =
        slide([
          Builder.pause(),
          bars(highlight: ["Orders", "Returns"]),
          Builder.text_box(at: :next, elements: [Builder.text_area(text: "After")])
        ])

      [slide] = deck.slides

      assert Enum.map(chart(deck).focus, & &1.steps) == [[2], [3]]
      assert Enum.find(slide.elements, &match?(%Expresso.Element.TextBox{}, &1)).steps == [4]
      assert slide.metadata.max_step == 4
    end
  end

  describe "the document" do
    test "each series names its color number, and each group dims the other series at its step" do
      html = [bars(highlight: ["Returns", ["Orders", "Returns"]])] |> slide() |> document()

      [figure] = html |> LazyHTML.query(".screen figure.chart") |> Enum.to_list()
      [el] = LazyHTML.attribute(figure, "data-el")

      assert figure |> LazyHTML.query("g.chart-series") |> LazyHTML.attribute("data-series") ==
               ["1", "2"]

      assert rules(html) == [
               ~s|section[data-step="1"] [data-el="#{el}"] [data-series]:not([data-series="2"]) { --chart-dim: 1; }|,
               ~s|section[data-step="2"] [data-el="#{el}"] [data-series]:not([data-series="1"]):not([data-series="2"]) { --chart-dim: 1; }|
             ]
    end

    test "a chart without the option has no data-series and no rule of a group" do
      html = [bars()] |> slide() |> document()

      assert count(html, ".screen figure.chart:not(:has([data-series]))") == 1
      assert count(html, ".screen figure.chart:not([data-el])") == 1
      assert rules(html) == []
    end

    test "a line chart takes the option" do
      html =
        [
          Builder.chart(:line,
            title: "Visitors",
            categories: ["Jan", "Feb"],
            highlight: ["Shop"],
            elements: [Builder.series("Web", [4, 5]), Builder.series("Shop", [1, 2])]
          )
        ]
        |> slide()
        |> document()

      assert html
             |> LazyHTML.query(".screen g.chart-series:has(polyline.chart-line)")
             |> LazyHTML.attribute("data-series") == ["1", "2"]

      assert [rule] = rules(html)
      assert rule =~ ~s|[data-series]:not([data-series="2"])|
    end

    test "the series of a chart with the effect grow keep their numbers" do
      html =
        [bars(highlight: ["Orders"], effect: :grow, at: [from: 1])]
        |> slide()
        |> document()

      assert count(html, ".screen figure.chart path.chart-bar.chart-mark") == 4

      assert html
             |> LazyHTML.query(".screen figure.chart g.chart-series")
             |> LazyHTML.attribute("data-series") == ["1", "2"]

      assert [_rule] = rules(html)
    end

    @tag :tmp_dir
    test "a chart with src takes the names of the series of its file", %{tmp_dir: tmp_dir} do
      src = Path.join(tmp_dir, "data.csv")
      File.write!(src, "Month,Web,Shop\nJan,4,1\nFeb,5,2\n")

      deck = slide([Builder.chart(:line, title: "Visitors", src: src, highlight: ["Shop"])])

      assert [%Focus{series: [2], steps: [1]}] = chart(deck).focus
    end
  end

  describe "the categories" do
    # The value of `data-keys` of each mark with the attribute in the present
    # view, with the classes of the mark.
    defp keyed(html) do
      html
      |> LazyHTML.query(".screen [data-keys]")
      |> Enum.map(&{hd(LazyHTML.attribute(&1, "class")), hd(LazyHTML.attribute(&1, "data-keys"))})
    end

    test "a group of categories dims each mark of the other categories, and a series step can follow" do
      html = [bars(highlight: ["2024", "Returns"])] |> slide() |> document()
      [el] = html |> LazyHTML.query(".screen figure.chart") |> LazyHTML.attribute("data-el")

      assert keyed(html) == [
               {"chart-category", "c1"},
               {"chart-category", "c2"},
               {"chart-bar", "c1"},
               {"chart-value", "c1"},
               {"chart-bar", "c2"},
               {"chart-value", "c2"},
               {"chart-bar", "c1"},
               {"chart-value", "c1"},
               {"chart-bar", "c2"},
               {"chart-value", "c2"}
             ]

      assert count(html, ".screen .chart-swatch:not([data-keys])") == 2

      assert rules(html) == [
               ~s|section[data-step="1"] [data-el="#{el}"] [data-keys]:not([data-keys~="c2"]) { --chart-dim: 1; }|,
               ~s|section[data-step="2"] [data-el="#{el}"] [data-series]:not([data-series="2"]) { --chart-dim: 1; }|
             ]
    end

    test "a line dims at each step of a group of categories, and a dot and the end keep their category" do
      html =
        [
          Builder.chart(:line,
            title: "Visitors",
            categories: ["Jan", "Feb"],
            highlight: ["Jan"],
            elements: [Builder.series("Web", [4, 5])]
          )
        ]
        |> slide()
        |> document()

      assert {"chart-line", ""} in keyed(html)
      assert {"chart-dot", "c1"} in keyed(html)
      assert {"chart-dot", "c2"} in keyed(html)
      assert {"chart-end", "c2"} in keyed(html)
    end

    test "a pie takes the option, and its slice and its part of the legend have the key" do
      html =
        [
          Builder.chart(:pie,
            title: "Hours",
            categories: ["Press", "Paint"],
            highlight: ["Paint", "Press"],
            elements: [Builder.series("Hours", [3, 1])]
          )
        ]
        |> slide()
        |> document()

      assert keyed(html) == [
               {"chart-slice chart-c1", "c1"},
               {"chart-slice chart-c2", "c2"},
               {"chart-swatch chart-c1", "c1"},
               {"chart-name", "c1"},
               {"chart-swatch chart-c2", "c2"},
               {"chart-name", "c2"}
             ]

      assert [first, second] = rules(html)
      assert first =~ ~s|[data-keys]:not([data-keys~="c2"])|
      assert second =~ ~s|[data-keys]:not([data-keys~="c1"])|
    end

    test "the marks of a chart with the effect grow have the keys" do
      html =
        [bars(highlight: ["2023"], effect: :grow, at: [from: 1])]
        |> slide()
        |> document()

      assert count(html, ~s|.screen path.chart-bar.chart-mark[data-keys="c1"]|) == 2
      assert count(html, ~s|.screen g.chart-mark[data-keys="c1"] > text.chart-value|) == 2
      assert count(html, ~s|.screen text.chart-category.chart-mark[data-keys="c1"]|) == 1
    end
  end

  describe "the parts of a treemap and of a sunburst" do
    @categories ["Production/Press", "Production/Paint", "Office/IT", "Logistics"]

    defp parts(kind, highlight, opts \\ []) do
      [
        Builder.chart(
          kind,
          [
            title: "Hours",
            categories: @categories,
            highlight: highlight,
            elements: [Builder.series("Hours", [40, 25, 15, 30])]
          ] ++ opts
        )
      ]
      |> slide()
      |> document()
    end

    test "a mark of a part holds the keys of the part, of its groups and of its parts" do
      html = parts(:treemap, ["Production", "Office/IT"])

      assert keyed(html) == [
               {"chart-group", "p1 p2 p3"},
               {"chart-tile", "p1 p2"},
               {"chart-tile", "p1 p3"},
               {"chart-mark chart-label", "p1 p2 p3"},
               {"chart-mark chart-label", "p1 p2"},
               {"chart-mark chart-label", "p1 p3"},
               {"chart-tile", "p6"},
               {"chart-mark chart-label", "p6"},
               {"chart-group", "p4 p5"},
               {"chart-tile", "p4 p5"},
               {"chart-mark chart-label", "p4 p5"},
               {"chart-mark chart-label", "p4 p5"}
             ]

      assert [first, second] = rules(html)
      assert first =~ ~s|[data-keys]:not([data-keys~="p1"])|
      assert second =~ ~s|[data-keys]:not([data-keys~="p5"])|
    end

    test "a sunburst gives the keys to its rings, its labels and the parts of its legend" do
      html = parts(:sunburst, ["Production/Paint"])

      assert {"chart-ring chart-c1 chart-depth-2", "p1 p3"} in keyed(html)
      assert {"chart-mark chart-label", "p1 p3"} in keyed(html)
      assert {"chart-swatch chart-c1", "p1 p2 p3"} in keyed(html)
      assert {"chart-name", "p1 p2 p3"} in keyed(html)
      assert {"chart-name", "p6"} in keyed(html)
      assert [rule] = rules(html)
      assert rule =~ ~s|[data-keys]:not([data-keys~="p3"])|
    end

    test "a name takes the separator of the chart, and a category can be a list of levels" do
      html =
        [
          Builder.chart(:treemap,
            title: "Hours",
            categories: [["I/O", "Disks"], ["I/O", "Network"], ["CPU"]],
            separator: " > ",
            highlight: ["I/O > Disks"],
            elements: [Builder.series("Hours", [3, 2, 4])]
          )
        ]
        |> slide()
        |> document()

      assert [rule] = rules(html)
      assert rule =~ ~s|[data-keys]:not([data-keys~="p2"])|
    end

    test "the compiler gives the parts and the groups for a name that is not one of them" do
      assert_raise ArgumentError,
                   ~r/the chart has no series and no part or group with that name. The series are "Hours". The parts and the groups are "Production", "Production\/Press", "Production\/Paint", "Office", "Office\/IT", "Logistics"\./,
                   fn -> parts(:treemap, ["Press"]) end
    end
  end

  describe "the errors" do
    test "the compiler refuses an option that the highlight option does not take with it" do
      for {opts, message} <- [
            {[whole_first: true], "the whole_first option of a chart needs the highlight option"},
            {[highlight: ["Orders"], reveal: true],
             "a chart takes the reveal option or the highlight option, and not both"},
            {[highlight: ["Orders"], dim: true],
             "the highlight option dims the other series itself"},
            {[highlight: []], "the highlight option needs one group or more"},
            {[highlight: [[]]], "a group of the highlight option needs one name or more"}
          ] do
        assert_raise ArgumentError, ~r/#{Regex.escape(message)}/, fn -> bars(opts) end
      end
    end

    test "the compiler refuses a name that is not a series or a category, and gives the names" do
      assert_raise ArgumentError,
                   ~r/the highlight option names "Sales", and the chart has no series and no category with that name. The series are "Orders", "Returns". The categories are "2023", "2024"\./,
                   fn -> bars(highlight: [["Orders", "Sales"]]) end
    end

    test "the compiler refuses a name of a series and a category, and a group of both" do
      assert_raise ArgumentError, ~r/the chart has a series and a category with that name/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["Orders", "2024"],
          highlight: ["Orders"],
          elements: [Builder.series("Orders", [1, 2])]
        )
      end

      assert_raise ArgumentError,
                   ~r/a group of the highlight option names series or categories, and not both/,
                   fn -> bars(highlight: [["Orders", "2024"]]) end
    end

    test "the compiler refuses a sankey, a series with an overlay option, and frames" do
      assert_raise ArgumentError, ~r/a sankey chart takes no highlight option/, fn ->
        Builder.chart(:sankey,
          title: "Flows",
          categories: [["Coal", "Power"]],
          highlight: ["Coal"],
          elements: [Builder.series("Flow", [3])]
        )
      end

      assert_raise ArgumentError, ~r/a series of the chart takes no at option/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["2023"],
          highlight: ["Orders"],
          elements: [Builder.series("Orders", [1], at: 2)]
        )
      end

      assert_raise ArgumentError, ~r/a chart with frames takes no highlight option/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North"],
          highlight: ["Orders"],
          timeline: [
            Builder.frame("2024", elements: [Builder.series("Orders", [1])]),
            Builder.frame("2025", elements: [Builder.series("Orders", [2])])
          ]
        )
      end
    end

    test "the verifier refuses a group at a step at which the chart does not show" do
      assert_raise Spark.Error.DslError,
                   ~r/the group of the highlight option has the step 1, and the chart does not show at that step/,
                   fn -> slide([bars(at: 2, highlight: ["Orders", "Returns"])]) end
    end
  end
end
