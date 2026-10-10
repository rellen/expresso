defmodule Expresso.ChartFramesTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Chart
  alias Expresso.Element.Chart.Csv

  doctest Csv

  defp frame(label, series), do: Builder.frame(label, elements: series)

  defp race(opts \\ []) do
    Builder.chart(
      :bar,
      [
        title: "Orders",
        categories: ["North", "South"],
        timeline: [
          frame("2023", [Builder.series("Orders", [10, 20])]),
          frame("2024", [Builder.series("Orders", [30, 15])]),
          frame("2025", [Builder.series("Orders", [40, 50])])
        ]
      ] ++ opts
    )
  end

  defp deck(elements, opts \\ []) do
    [Builder.slide("s", [elements: elements] ++ opts)]
    |> Builder.deck(name: "frames")
  end

  defp chart(deck) do
    [%{elements: elements}] = deck.slides
    Enum.find(elements, &match?(%Chart{}, &1))
  end

  defp document(deck), do: deck |> Expresso.Deck.render() |> Floki.parse_document!()

  defp style(html) do
    html |> Floki.find("style") |> Enum.map_join("\n", &Floki.text(&1, js: true))
  end

  describe "the steps" do
    test "the first frame shows from the first step, and each later frame takes the next step" do
      deck = deck([race()])
      chart = chart(deck)

      assert Enum.map(chart.timeline, & &1.steps) == [nil, [2], [3]]
      assert hd(deck.slides).metadata.max_step == 3
    end

    test "the frames come after the series of a chart with reveal" do
      chart =
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North"],
          reveal: true,
          timeline: [
            frame("2023", [Builder.series("A", [1]), Builder.series("B", [2])]),
            frame("2024", [Builder.series("A", [3]), Builder.series("B", [4])])
          ]
        )

      chart = chart(deck([chart]))

      assert Enum.map(chart.elements, & &1.steps) == [[1, 2, 3], [2, 3]]
      assert Enum.map(chart.timeline, & &1.steps) == [nil, [3]]
    end

    test "a frame shows until the next frame, and the last frame to the last step" do
      chart = chart(deck([race()], steps: 5))
      assert Enum.map(chart.timeline, & &1.steps) == [nil, [2], [3, 4, 5]]
    end

    test "the frames of a chart with an absolute step start at that step" do
      chart = chart(deck([race(at: 3)]))
      assert Enum.map(chart.timeline, & &1.steps) == [nil, [4], [5]]
    end

    test "a chart with at from: :next shows its first frame at its own step" do
      chart = chart(deck([race(at: [from: :next])]))
      assert chart.steps == [1, 2, 3]
      assert Enum.map(chart.timeline, & &1.steps) == [nil, [2], [3]]
    end
  end

  describe "the checks" do
    test "the series of a chart with frames are in its frames" do
      assert_raise ArgumentError, ~r/holds its series in each frame/, fn ->
        race(elements: [Builder.series("Orders", [1, 2])])
      end
    end

    test "each frame holds the series of the first frame, in the same order" do
      assert_raise ArgumentError, ~r/the frame "2024" needs the series "A", "B"/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North"],
          timeline: [
            frame("2023", [Builder.series("A", [1]), Builder.series("B", [2])]),
            frame("2024", [Builder.series("B", [3]), Builder.series("A", [4])])
          ]
        )
      end
    end

    test "only the series of the first frame take the overlay options" do
      assert_raise ArgumentError, ~r/the frame "2024" gives a series an overlay option/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North"],
          timeline: [
            frame("2023", [Builder.series("A", [1])]),
            frame("2024", [Builder.series("A", [3], at: 2)])
          ]
        )
      end
    end

    test "each frame has a value for each category" do
      assert_raise ArgumentError, ~r/the series "A" needs 2 numbers/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North", "South"],
          timeline: [
            frame("2023", [Builder.series("A", [1, 2])]),
            frame("2024", [Builder.series("A", [3])])
          ]
        )
      end
    end

    test "sort is for a bar chart, and count is for a chart with frames" do
      assert_raise ArgumentError, ~r/a line chart takes no sort option/, fn ->
        Builder.chart(:line,
          title: "Orders",
          categories: ["North"],
          sort: true,
          elements: [Builder.series("A", [1])]
        )
      end

      assert_raise ArgumentError, ~r/the count option .* needs frames/, fn ->
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North"],
          count: true,
          elements: [Builder.series("A", [1])]
        )
      end
    end

    test "the thumbnail option names a frame of the chart" do
      assert_raise ArgumentError, ~r/names frame 4, and the chart has 3 frames/, fn ->
        race(thumbnail: 4)
      end
    end

    test "the frames option needs a CSV file" do
      assert_raise ArgumentError, ~r/the frames option names a column of a CSV file/, fn ->
        race(frames: "year")
      end
    end
  end

  describe "a CSV file with frames" do
    @tag :tmp_dir
    test "the rows of each frame make one frame, in the order of the first frame", %{
      tmp_dir: tmp_dir
    } do
      path = Path.join(tmp_dir, "orders.csv")

      File.write!(path, """
      year,region,Orders,Returns
      2023,North,10,1
      2023,South,20,2
      2024,South,25,3
      2024,North,15,4
      """)

      chart = Builder.chart(:bar, title: "Orders", src: path, frames: "year")
      chart = chart(deck([chart]))

      assert chart.categories == ["North", "South"]
      assert Enum.map(chart.timeline, & &1.label) == ["2023", "2024"]
      [_first, second] = chart.timeline

      assert Enum.map(second.elements, &{&1.name, &1.values}) == [
               {"Orders", [15, 25]},
               {"Returns", [4, 3]}
             ]

      assert Enum.map(chart.elements, & &1.values) == [[10, 20], [1, 2]]
    end

    test "a file without the column, or a frame without a category, gives an error" do
      assert {:error, "the chart file \"a.csv\" has no column \"month\" for the frames"} =
               Csv.frames("year,region,A\n2023,North,1\n", "month", "a.csv")

      assert {:error, message} =
               Csv.frames(
                 "year,region,A\n2023,North,1\n2023,South,2\n2024,North,3\n",
                 "year",
                 "a.csv"
               )

      assert message =~ "the frame \"2024\" of the chart file \"a.csv\" needs the categories"
    end
  end

  describe "the render" do
    test "a chart with frames has an identity, and the style block sets each frame at its step" do
      html = document(deck([race()]))
      [figure] = Floki.find(html, ".screen figure.chart")
      [el] = Floki.attribute(figure, "data-el")
      css = style(html)

      assert css =~ ~s(section[data-step="2"] [data-el="#{el}"] {)
      assert css =~ ~s(section[data-step="3"] [data-el="#{el}"] {)

      # The bar of North in 2024 has its top at the value 30 of the axis.
      assert css =~ ~r/section\[data-step="2"\] \[data-el="#{el}"\] \{[^}]*--b1-0: [\d.]+;/
      assert css =~ ~r/section\[data-step="2"\] \[data-el="#{el}"\] \{[^}]*--k2: 1;/
    end

    test "the overview and the menu show the first frame, or the frame of the thumbnail option" do
      first = race() |> List.wrap() |> deck() |> document() |> style()
      assert first =~ ~r/:is\(\.menu-thumb, [^)]*\) \[data-el="s1-e1"\] \{[^}]*--k1: 1;/

      last = race(thumbnail: :last) |> List.wrap() |> deck() |> document() |> style()
      assert last =~ ~r/:is\(\.menu-thumb, [^)]*\) \[data-el="s1-e1"\] \{[^}]*--k3: 1;/
    end

    test "each mark reads its channel with the value of the first frame as its fallback" do
      [figure] =
        race() |> List.wrap() |> deck() |> document() |> Floki.find(".screen figure.chart")

      [north | _] = Floki.find(figure, "svg > g.chart-series path.chart-bar")
      [style] = Floki.attribute(north, "style")

      assert style =~
               ~r/--chart-v: calc\([\d.]+ \+ \(var\(--b1-0, [\d.]+\) - [\d.]+\) \* var\(--chart-shown, 1\)\);/

      labels = figure |> Floki.find("svg > text.chart-frame") |> Enum.map(&Floki.text/1)
      assert labels == ["2023", "2024", "2025"]
    end

    test "paper and the handout view get a small chart of each frame with its label" do
      [figure] =
        race() |> List.wrap() |> deck() |> document() |> Floki.find(".screen figure.chart")

      copies = Floki.find(figure, ".chart-frames figure.chart-copy")

      assert Enum.map(copies, &(&1 |> Floki.find("figcaption") |> Floki.text())) ==
               ~w(2023 2024 2025)

      assert copies |> hd() |> Floki.find("path.chart-bar") |> length() == 2
      assert copies |> hd() |> Floki.find(".chart-mark") == []
    end

    test "the table has a column for each frame" do
      [figure] =
        race() |> List.wrap() |> deck() |> document() |> Floki.find(".screen figure.chart")

      heads = figure |> Floki.find("table.chart-table thead th") |> Enum.map(&Floki.text/1)
      assert heads == ["", "2023", "2024", "2025"]
    end

    test "with count, a number is one copy that the script counts, with its decimals" do
      chart =
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North"],
          count: true,
          timeline: [
            frame("2023", [Builder.series("Orders", [10])]),
            frame("2024", [Builder.series("Orders", [12.5])])
          ]
        )

      [figure] =
        chart |> List.wrap() |> deck() |> document() |> Floki.find(".screen figure.chart")

      [count] = Floki.find(figure, "svg tspan.chart-count")

      assert Floki.text(count) == "10"
      assert Floki.attribute(count, "data-decimals") == ["1"]
      assert figure |> Floki.find("svg .chart-value.chart-fade") == []
    end

    test "with sort, the categories move to the order of their totals" do
      html = race(sort: true) |> List.wrap() |> deck() |> document()
      css = style(html)

      # South leads in 2023 and in 2025, and North leads in 2024.
      [x0_2024] =
        Regex.run(~r/data-step="2"\] \[data-el="s1-e1"\] \{[^}]*--x0: ([\d.]+);/, css,
          capture: :all_but_first
        )

      [x0_2025] =
        Regex.run(~r/data-step="3"\] \[data-el="s1-e1"\] \{[^}]*--x0: ([\d.]+);/, css,
          capture: :all_but_first
        )

      assert Float.parse(x0_2024) < Float.parse(x0_2025)
    end

    test "a pie and a line chart with frames draw arcs and segments" do
      pie =
        Builder.chart(:pie,
          title: "Share",
          categories: ["North", "South"],
          timeline: [
            frame("2023", [Builder.series("S", [1, 3])]),
            frame("2024", [Builder.series("S", [3, 1])])
          ]
        )

      line =
        Builder.chart(:line,
          title: "Trend",
          categories: ["Q1", "Q2", "Q3"],
          timeline: [
            frame("2023", [Builder.series("S", [1, 3, 2])]),
            frame("2024", [Builder.series("S", [3, 1, 2])])
          ]
        )

      html = document(deck([pie, line]))
      [pie, line] = Floki.find(html, ".screen figure.chart")

      assert pie |> Floki.find("svg circle.chart-arc") |> length() == 2
      assert pie |> Floki.find("svg line.chart-gap") |> length() == 2
      assert line |> Floki.find("svg line.chart-segment") |> length() == 2
      assert line |> Floki.find("figure.chart > svg circle.chart-dot") |> length() == 3
    end

    test "the effect grow draws the marks that move, and a chart without it keeps its paths" do
      grown =
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North"],
          effect: :grow,
          at: 2,
          elements: [Builder.series("Orders", [10])]
        )

      plain =
        Builder.chart(:bar,
          title: "Orders",
          categories: ["North"],
          elements: [Builder.series("Orders", [10])]
        )

      [grown, plain] = Floki.find(document(deck([grown, plain])), ".screen figure.chart")

      assert Floki.attribute(grown, "data-effect") == ["grow"]
      assert grown |> Floki.find("path.chart-bar.chart-mark") |> length() == 1
      assert plain |> Floki.find(".chart-mark") == []
      assert Floki.attribute(plain, "data-el") == []
    end
  end
end
