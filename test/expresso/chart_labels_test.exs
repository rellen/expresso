defmodule Expresso.ChartLabelsTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart.Csv

  doctest Csv, only: [heading: 4]

  defp figure(chart) do
    [Builder.slide("s", elements: [chart])]
    |> Builder.deck(name: "charts")
    |> Expresso.Deck.render()
    |> LazyHTML.from_document()
    |> LazyHTML.query(".screen figure.chart")
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

  defp titles(figure), do: texts(figure, ".chart-axis-title")

  test "category_label goes under the axis and into the corner of the table" do
    figure = figure(bars(category_label: "Year"))

    assert titles(figure) == ["Year"]

    assert texts(figure, ".chart-table thead th") == [
             "Year",
             "Orders"
           ]

    assert figure |> LazyHTML.filter(":not(:has(.chart-table thead td))") |> Enum.count() == 1
  end

  test "value_label goes beside the axis and into the caption of the table" do
    figure = figure(bars(value_label: "Widgets an hour"))

    [title] = LazyHTML.query(figure, ".chart-axis-title") |> Enum.to_list()
    assert LazyHTML.text(title) == "Widgets an hour"
    assert [transform] = LazyHTML.attribute(title, "transform")
    assert transform =~ "rotate(-90)"

    assert texts(figure, ".chart-table caption") == ["Orders (Widgets an hour)"]
  end

  test "without the options, the chart has no axis title and an empty corner cell" do
    figure = figure(bars([]))

    assert figure |> LazyHTML.filter(":not(:has(.chart-axis-title))") |> Enum.count() == 1
    assert count(figure, ".chart-table thead td") == 1
  end

  test "a chart from a CSV file takes the first heading of the file" do
    figure =
      figure(Builder.chart(:line, title: "Visitors", src: "examples/animations/visitors.csv"))

    assert titles(figure) == ["Month"]
    assert texts(figure, ".chart-table thead th") |> hd() == "Month"
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

    assert figure |> LazyHTML.filter(":not(:has(.chart-axis-title))") |> Enum.count() == 1
    assert texts(figure, ".chart-table thead th") |> hd() == "Team"
  end
end
