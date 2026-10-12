defmodule Expresso.ChartLabelsTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Chart.Csv

  doctest Csv, only: [heading: 4]

  defp figure(chart) do
    [Builder.slide("s", elements: [chart])]
    |> Builder.deck(name: "charts")
    |> Expresso.Deck.render()
    |> Floki.parse_document!()
    |> Floki.find(".screen figure.chart")
  end

  defp bars(opts) do
    Builder.chart(
      :bar,
      [
        title: "Orders",
        categories: ["2024", "2025"],
        elements: [Builder.series("Orders", [1, 2])]
      ] ++
        opts
    )
  end

  defp titles(figure), do: figure |> Floki.find(".chart-axis-title") |> Enum.map(&Floki.text/1)

  test "category_label goes under the axis and into the corner of the table" do
    figure = figure(bars(category_label: "Year"))

    assert titles(figure) == ["Year"]

    assert figure |> Floki.find(".chart-table thead th") |> Enum.map(&Floki.text/1) == [
             "Year",
             "Orders"
           ]

    assert figure |> Floki.find(".chart-table thead td") == []
  end

  test "value_label goes beside the axis and into the caption of the table" do
    figure = figure(bars(value_label: "Widgets an hour"))

    [title] = Floki.find(figure, ".chart-axis-title")
    assert Floki.text(title) == "Widgets an hour"
    assert [transform] = Floki.attribute(title, "transform")
    assert transform =~ "rotate(-90)"

    assert figure |> Floki.find(".chart-table caption") |> Floki.text() ==
             "Orders (Widgets an hour)"
  end

  test "without the options, the chart has no axis title and an empty corner cell" do
    figure = figure(bars([]))

    assert titles(figure) == []
    assert figure |> Floki.find(".chart-table thead td") |> length() == 1
  end

  test "a chart from a CSV file takes the first heading of the file" do
    figure =
      figure(Builder.chart(:line, title: "Visitors", src: "examples/animations/visitors.csv"))

    assert titles(figure) == ["Month"]
    assert figure |> Floki.find(".chart-table thead th") |> hd() |> Floki.text() == "Month"
  end

  test "category_label wins over the heading of the file" do
    chart =
      Builder.chart(:line,
        title: "Visitors",
        src: "examples/animations/visitors.csv",
        category_label: "Month of 2025"
      )

    assert chart |> figure() |> titles() == ["Month of 2025"]
  end

  test "a pie has no axis, and its table still takes the name of the categories" do
    figure =
      figure(
        Builder.chart(:pie,
          title: "Share",
          categories: ["A", "B"],
          category_label: "Team",
          elements: [Builder.series("Hours", [1, 2])]
        )
      )

    assert titles(figure) == []
    assert figure |> Floki.find(".chart-table thead th") |> hd() |> Floki.text() == "Team"
  end
end
