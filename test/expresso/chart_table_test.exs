defmodule Expresso.ChartTableTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder
  alias Expresso.Element.Chart
  alias Expresso.Element.Chart.{Layers, ParallelSets, Sankey, Table}

  doctest Table
  doctest Layers

  defp html(assigns), do: assigns |> Table.render() |> Phoenix.HTML.safe_to_string()

  describe "the rows of each kind are data" do
    test "a sankey has a row for each link, with its source, its target and its value" do
      chart =
        Builder.chart(:sankey,
          title: "Energy",
          flows: [
            Builder.flow("Coal", "Electricity", 180),
            Builder.flow("Electricity", "Homes", 120)
          ]
        )

      assert Sankey.table(Chart.get_assigns(chart)) == %{
               headers: ["From", "To", "Value"],
               rows: [["Coal", "Electricity", "180"], ["Electricity", "Homes", "120"]]
             }
    end

    test "a parallel sets chart has a row for each path, with a column for each frame" do
      chart =
        Builder.chart(:parallel_sets,
          title: "Votes",
          categories: [["Red", "Red"], ["Red", "Blue"]],
          timeline: [
            Builder.frame("2020", elements: [Builder.series("People", [4, 1])]),
            Builder.frame("2024", elements: [Builder.series("People", [2, 0])])
          ]
        )

      assert %{headers: ["Column 1", "Column 2", "2020", "2024"], rows: rows} =
               ParallelSets.table(Chart.get_assigns(chart))

      assert ["Red", "Red", "4", "2"] in rows
      assert ["Red", "Blue", "1", "0"] in rows
    end
  end

  describe "render/1" do
    test "writes the caption, a header for each column and a header for each row" do
      document =
        %{caption: "Orders (units)", headers: ["Year", "Orders"], rows: [["2024", "180"]]}
        |> html()
        |> Floki.parse_fragment!()

      assert document |> Floki.find("table.chart-table caption") |> Floki.text() ==
               "Orders (units)"

      assert document |> Floki.find("thead th[scope=col]") |> Enum.map(&Floki.text/1) ==
               ["Year", "Orders"]

      assert document |> Floki.find("tbody th[scope=row]") |> Floki.text() == "2024"
      assert document |> Floki.find("tbody td") |> Floki.text() == "180"
    end

    test "writes a corner without a name as a cell, and not as a header" do
      document =
        %{caption: "Orders", headers: [nil, "Orders"], rows: [["2024", "180"]]}
        |> html()
        |> Floki.parse_fragment!()

      assert [{"tr", [], [{"td", [], []}, {"th", [{"scope", "col"}], ["Orders"]}]}] =
               Floki.find(document, "thead tr")
    end
  end
end
