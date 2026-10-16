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

    test "the compiler refuses a name that is not a series, and gives the names of the series" do
      assert_raise ArgumentError,
                   ~r/the highlight option names "Sales", and the chart has no series with that name. The series are "Orders", "Returns"\./,
                   fn -> bars(highlight: [["Orders", "Sales"]]) end
    end

    test "the compiler refuses a pie, a series with an overlay option, and frames" do
      assert_raise ArgumentError, ~r/a pie chart takes no highlight option/, fn ->
        Builder.chart(:pie,
          title: "Hours",
          categories: ["Press", "Paint"],
          highlight: ["Hours"],
          elements: [Builder.series("Hours", [3, 1])]
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
