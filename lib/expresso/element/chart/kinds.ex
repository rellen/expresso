defmodule Expresso.Element.Chart.Kinds do
  @moduledoc """
  The table of the kinds of a chart, and a guard for each group of kinds

  Each kind has a family. The family decides which code draws the kind:

  | Family | Kinds | The chart shows |
  | --- | --- | --- |
  | `:axis` | `:bar`, `:line` | The series on an axis, as bars or as lines |
  | `:pie` | `:pie` | One series as the slices of a circle |
  | `:parts` | `:treemap`, `:sunburst`, `:voronoi` | One series as the parts of a whole, in groups |
  | `:flows` | `:sankey`, `:alluvial`, `:parallel_sets`, `:chord` | The flows between nodes |

  A kind can also have these properties:

  - `round`: the chart is a circle, so the label of a frame goes to the right
    edge of the SVG.
  - `titles`: the `levels` option gives a title to each column.

  `Expresso.Element.Chart`, `Expresso.Element.Chart.Motion` and
  `Expresso.Element.Chart.Sankey` use the guards of this module in place of
  lists of kinds. A function that branches on the kind has no catch-all
  clause, so a new kind without a clause raises `FunctionClauseError` in its
  first render test.

  The module depends on no other module of Expresso, so each chart module can
  use its guards at compile time with no cycle.
  """

  @table [
    bar: [family: :axis],
    line: [family: :axis],
    pie: [family: :pie, round: true],
    treemap: [family: :parts],
    sunburst: [family: :parts, round: true],
    voronoi: [family: :parts],
    sankey: [family: :flows],
    alluvial: [family: :flows, titles: true],
    parallel_sets: [family: :flows, titles: true],
    chord: [family: :flows]
  ]

  @all Keyword.keys(@table)
  @axis for {kind, properties} <- @table, properties[:family] == :axis, do: kind
  @parts for {kind, properties} <- @table, properties[:family] == :parts, do: kind
  @flows for {kind, properties} <- @table, properties[:family] == :flows, do: kind
  @single for {kind, properties} <- @table, properties[:family] in [:pie, :parts], do: kind
  @round for {kind, properties} <- @table, properties[:round], do: kind
  @titled for {kind, properties} <- @table, properties[:titles], do: kind

  @doc """
  Return each kind of a chart, in the order of the table

      iex> Expresso.Element.Chart.Kinds.all()
      [:bar, :line, :pie, :treemap, :sunburst, :voronoi, :sankey, :alluvial, :parallel_sets, :chord]
  """
  @spec all() :: [atom()]
  def all, do: @all

  @doc """
  Return the family of a kind

      iex> Expresso.Element.Chart.Kinds.family(:chord)
      :flows
  """
  @spec family(atom()) :: :axis | :pie | :parts | :flows
  def family(kind) when kind in @all, do: @table[kind][:family]

  @doc "Return true for a kind with an axis: a bar chart or a line chart"
  defguard is_axis(kind) when kind in @axis

  @doc """
  Return true for a kind that shows the parts of a whole in groups: a treemap, a sunburst
  or a Voronoi treemap
  """
  defguard is_part(kind) when kind in @parts

  @doc "Return true for a kind that shows the flows between nodes, such as a sankey"
  defguard is_flow(kind) when kind in @flows

  @doc "Return true for a kind with one series: a pie, or a kind of the family `:parts`"
  defguard is_single(kind) when kind in @single

  @doc """
  Return true for a kind with a list of names in a category: a kind of the families
  `:parts` and `:flows`
  """
  defguard is_path(kind) when is_part(kind) or is_flow(kind)

  @doc "Return true for a kind that is a circle: a pie or a sunburst"
  defguard is_round(kind) when kind in @round

  @doc """
  Return true for a kind with a title over each column from the `levels` option: an
  alluvial chart or a parallel sets chart
  """
  defguard is_titled(kind) when kind in @titled
end
