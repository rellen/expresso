defmodule Expresso.ChartKindsTest do
  use ExUnit.Case, async: true

  import Expresso.Element.Chart.Kinds

  alias Expresso.Builder
  alias Expresso.Element.Chart
  alias Expresso.Element.Chart.Kinds

  doctest Kinds

  defp bars do
    Builder.chart(:bar,
      title: "Orders",
      categories: ["2023", "2024"],
      elements: [Builder.series("Orders", [120, 180])]
    )
  end

  test "each kind has one of the four families" do
    for kind <- Kinds.all() do
      assert Kinds.family(kind) in [:axis, :pie, :parts, :flows], inspect(kind)
    end
  end

  test "the guards agree with the families" do
    for kind <- Kinds.all() do
      family = Kinds.family(kind)

      assert is_axis(kind) == (family == :axis), inspect(kind)
      assert is_part(kind) == (family == :parts), inspect(kind)
      assert is_flow(kind) == (family == :flows), inspect(kind)
      assert is_single(kind) == family in [:pie, :parts], inspect(kind)
      assert is_path(kind) == family in [:parts, :flows], inspect(kind)
    end

    assert Enum.filter(Kinds.all(), &is_round/1) == [:pie, :sunburst]
    assert Enum.filter(Kinds.all(), &is_titled/1) == [:alluvial, :parallel_sets]
    refute is_axis(:funnel) or is_part(:funnel) or is_flow(:funnel) or is_single(:funnel)
  end

  test "the DSL takes each kind of the table, and no other kind" do
    [section] = Expresso.Extension.sections()
    [%Spark.Dsl.Entity{} = slide] = section.entities
    [chart] = for entity <- slide.entities[:elements], entity.name == :chart, do: entity

    assert chart.schema[:kind][:type] == {:in, Kinds.all()}

    assert_raise ArgumentError, ~r/:kind option/, fn ->
      Builder.chart(:funnel, title: "Orders", categories: ["a"])
    end
  end

  test "a kind without a clause raises, and the chart does not draw it as an axis chart" do
    assigns = bars() |> Chart.get_assigns() |> Map.put(:kind, :funnel)

    assert_raise FunctionClauseError, fn -> Chart.render(assigns) end
  end
end
