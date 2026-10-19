defmodule Expresso.Element.Node do
  @moduledoc """
  A node of a chart of flows, or a node of a tree

  The `node` entity takes the name of the node as its argument, such as
  `node "Losses", column: 3`.

  In a chart of flows, the name is the name in the flows, and the options
  change only how the chart shows the node. `Expresso.Element.Chart.Sankey`
  and `Expresso.Element.Chart.Chord` read them. Only a sankey takes the
  `column` option.

  In a tree, the name is the identity of the node, and the default text of
  its box. The node holds the nodes under it in `elements`.
  `Expresso.Element.Hierarchy` reads it.

  The two parents share one entity, so `Expresso.Builder` has one function
  `node/2`. Each parent refuses the options of the other parent:
  `chart_options/1` and `tree_options/1` return the options that a node gives.
  """

  @typedoc "The struct of a node"
  @type t :: %__MODULE__{
          name: String.t(),
          label: String.t() | nil,
          column: pos_integer() | nil,
          order: integer() | nil,
          detail: String.t() | nil,
          class: String.t() | nil,
          elements: [t()] | nil
        }

  # The overlay fields let the walks of the overlay transformer pass through
  # the nodes of a tree, as they pass through the items of a list.
  defstruct [
              :name,
              :label,
              :column,
              :order,
              :detail,
              :class,
              elements: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Return the options of a node that only a chart of flows takes and that the
  node gives

      iex> Expresso.Element.Node.chart_options(%Expresso.Element.Node{name: "a", column: 2})
      [:column]
  """
  @spec chart_options(t()) :: [atom()]
  def chart_options(%__MODULE__{} = node),
    do: for(key <- [:column, :order], Map.fetch!(node, key) != nil, do: key)

  @doc """
  Return the options of a node that only a tree takes and that the node
  gives, with `:node` for a nested node

      iex> Expresso.Element.Node.tree_options(%Expresso.Element.Node{name: "a", detail: "Role"})
      [:detail]
  """
  @spec tree_options(t()) :: [atom()]
  def tree_options(%__MODULE__{} = node) do
    given = for key <- [:detail], Map.fetch!(node, key) != nil, do: key
    if (node.elements || []) == [], do: given, else: given ++ [:node]
  end
end
