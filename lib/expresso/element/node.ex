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
  `Expresso.Element.Hierarchy` reads it. The `image`, `icon`, `fields`,
  `color` and `value` options add to the box, and the `layout` option sets
  how the nodes under it go. `Expresso.PathTransformer` joins the path of
  the image to the root of the deck, and `Expresso.IconTransformer` puts the
  SVG of the icon into `svg`.

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
          image: String.t() | nil,
          icon: String.t() | nil,
          svg: String.t() | nil,
          fields: [{String.t(), String.t()}] | nil,
          color: atom() | nil,
          value: number() | nil,
          layout: :top_down | :left_right | :stacked | nil,
          parent: String.t() | nil,
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
              :image,
              :icon,
              :svg,
              :fields,
              :color,
              :value,
              :layout,
              :parent,
              :class,
              elements: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @fields_error "a fields option takes a name and a text for each field, such as [team: \"42 people\", floor: 3]. A name is an atom or a string, and a text is a string or a number"

  @doc """
  Return the options of a node that only a chart of flows takes and that the
  node gives

      iex> Expresso.Element.Node.chart_options(%Expresso.Element.Node{name: "a", column: 2})
      [:column]
  """
  @spec chart_options(t()) :: [atom()]
  def chart_options(%__MODULE__{} = node),
    do: for(key <- [:column, :order], Map.fetch!(node, key) != nil, do: key)

  @tree_options [:detail, :image, :icon, :fields, :color, :value, :layout, :parent]

  @doc """
  Make sure that a `fields` option is a list of names and texts

  This function is the custom type of the option. A name is an atom or a
  string, and a text is a string or a number. The function returns each name
  and each text as a string, in the order of the option.

      iex> Expresso.Element.Node.fields(team: "42 people", floor: 3)
      {:ok, [{"team", "42 people"}, {"floor", "3"}]}

      iex> Expresso.Element.Node.fields([{"Cost center", "4100"}])
      {:ok, [{"Cost center", "4100"}]}

      iex> {:error, _message} = Expresso.Element.Node.fields(team: nil)
  """
  @spec fields(term()) :: {:ok, [{String.t(), String.t()}]} | {:error, String.t()}
  def fields(fields) when is_list(fields) do
    if Enum.all?(fields, &field?/1),
      do: {:ok, Enum.map(fields, fn {name, text} -> {to_string(name), to_string(text)} end)},
      else: {:error, @fields_error}
  end

  def fields(_fields), do: {:error, @fields_error}

  defp field?({name, text}),
    do: (is_atom(name) or is_binary(name)) and (is_binary(text) or is_number(text))

  defp field?(_field), do: false

  @doc """
  Make sure that a `value` option is a number that is not negative

      iex> Expresso.Element.Node.value(412.5)
      {:ok, 412.5}

      iex> {:error, _message} = Expresso.Element.Node.value(-1)
  """
  @spec value(term()) :: {:ok, number()} | {:error, String.t()}
  def value(value) when is_number(value) and value >= 0, do: {:ok, value}

  def value(value),
    do:
      {:error, "a value of a node is a number that is not negative, and #{inspect(value)} is not"}

  @doc """
  Return the options of a node that only a tree takes and that the node
  gives, with `:node` for a nested node

      iex> Expresso.Element.Node.tree_options(%Expresso.Element.Node{name: "a", detail: "Role"})
      [:detail]
  """
  @spec tree_options(t()) :: [atom()]
  def tree_options(%__MODULE__{} = node) do
    given = for key <- @tree_options, Map.fetch!(node, key) != nil, do: key
    if (node.elements || []) == [], do: given, else: given ++ [:node]
  end
end
