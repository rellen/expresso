defmodule Expresso.Element.Chart.Layers do
  @moduledoc """
  The parts that the charts of flows share: the layers of the frames, the
  numbers of the series and the colors of the nodes

  `Expresso.Element.Chart.Sankey`, `Expresso.Element.Chart.ParallelSets` and
  `Expresso.Element.Chart.Chord` each make one layout for each frame. Then
  `render/3` writes the label of the frame, the titles of the columns, and
  the drawing of each layout. A chart with one frame has one drawing. A chart
  with frames has one layer for each frame, and the channel `--k<n>` of
  `Expresso.Element.Chart.Motion` sets the opacity of layer `n`, so the
  layers change from one frame to the next.
  """

  import Temple
  import Expresso.Component

  alias Expresso.Element.Chart.{Motion, Sankey}

  # The colors of a palette for the nodes, as for the series of a chart.
  @colors 8

  @doc """
  Write the label of the frame, the titles of the columns and one drawing
  for each layout

  `drawing` takes the assigns of one layout: the keys of the layout, the key
  `numbered` from `numbered/2`, the key `values`, and the key `node_keys`
  from `node_keys/1` for a chart with a group of nodes. A chart with one
  layout writes its drawing with no layer around it.
  """
  @spec render(map(), [map()], (map() -> Phoenix.HTML.safe())) :: Phoenix.HTML.safe()
  def render(assigns, layouts, drawing) do
    keys = if assigns[:keys], do: node_keys(assigns.categories)

    layers =
      for {layout, k} <- Enum.with_index(layouts, 1),
          do:
            {k,
             Map.merge(layout, %{
               numbered: numbered(assigns, k),
               values: assigns.values,
               node_keys: keys
             })}

    assigns =
      Map.merge(assigns, %{
        layers: layers,
        drawing: drawing,
        xs: Map.get(hd(layouts), :xs)
      })

    temple do
      Motion.frame_label(assigns)
      Sankey.titles(assigns)

      if length(@layers) == 1 do
        c(@drawing, rest!: @layers |> hd() |> elem(1))
      else
        for {k, layer} <- @layers do
          g class: "chart-layer chart-fade",
            style: "opacity: var(--k#{k}, #{if k == 1, do: 1, else: 0});" do
            c(@drawing, rest!: layer)
          end
        end
      end
    end
  end

  @doc """
  Return each series with its number from 1, for the layer `k`

  A layer after the first has no morph key, so the morph between two slides
  finds one copy of each mark.
  """
  @spec numbered(map(), pos_integer()) :: [{map(), pos_integer()}]
  def numbered(assigns, 1), do: Enum.with_index(assigns.series, 1)

  def numbered(assigns, _layer) do
    for {series, number} <- Enum.with_index(assigns.series, 1),
        do: {%{series | overlay: no_morph(series.overlay)}, number}
  end

  @doc """
  Remove the morph key from a list of overlay attributes

      iex> Expresso.Element.Chart.Layers.no_morph([{"data-el", "s1-e1"}, {"data-morph-key", "a"}])
      [{"data-el", "s1-e1"}]
  """
  @spec no_morph([{String.t(), String.t()}]) :: [{String.t(), String.t()}]
  def no_morph(overlay), do: Enum.reject(overlay, &(elem(&1, 0) == "data-morph-key"))

  @doc """
  Return the link of each category in the series that holds its value

  A category is a pair of nodes. `values` holds the values of each series,
  and a value of 0 gives no link.

      iex> Expresso.Element.Chart.Layers.links([["A", "B"], ["B", "C"]], [[2, 0], [0, 3]])
      [%{from: "A", to: "B", value: 2, series: 1}, %{from: "B", to: "C", value: 3, series: 2}]
  """
  @spec links([[term()]], [[number()]]) :: [map()]
  def links(categories, values) do
    for {[from, to], index} <- Enum.with_index(categories),
        {series, number} <- Enum.with_index(values, 1),
        value = Enum.at(series, index),
        value > 0,
        do: %{from: from, to: to, value: value, series: number}
  end

  @doc """
  Return the name of each node, in the order of the categories

  A category is a pair of nodes or the path of a parallel sets chart. A
  node of an alluvial chart or of a parallel sets chart is the tuple of its
  column and its name, and the nodes with the same name in different
  columns give one name.

      iex> Expresso.Element.Chart.Layers.node_names([[{0, "A"}, {1, "B"}], [{0, "B"}, {1, "C"}]])
      ["A", "B", "C"]
  """
  @spec node_names([[Sankey.key()]]) :: [String.t()]
  def node_names(categories),
    do: categories |> List.flatten() |> Enum.map(&Sankey.name/1) |> Enum.uniq()

  @doc """
  Return the key of each node, as a map from its name

  The `highlight` option of a chart of flows names nodes. Each mark of a
  node, and each link that touches the node, holds the key of the node in
  its `data-keys` attribute.

      iex> Expresso.Element.Chart.Layers.node_keys([["A", "B"], ["B", "C"]])
      %{"A" => "n1", "B" => "n2", "C" => "n3"}
  """
  @spec node_keys([[Sankey.key()]]) :: %{String.t() => String.t()}
  def node_keys(categories) do
    categories
    |> node_names()
    |> Enum.with_index(1)
    |> Map.new(fn {name, index} -> {name, "n#{index}"} end)
  end

  @doc """
  Return the `data-keys` attribute of a mark that touches the nodes

  A node takes its own key. A link takes the keys of its two nodes, and a
  ribbon of a parallel sets chart takes the keys of each node of its path.
  A chart without a group of nodes gives no attribute.

      iex> keys = %{"A" => "n1", "B" => "n2"}
      iex> Expresso.Element.Chart.Layers.key(%{node_keys: keys}, [{0, "A"}, {1, "B"}, {2, "A"}])
      "n1 n2"
      iex> Expresso.Element.Chart.Layers.key(%{node_keys: nil}, ["A"])
      nil
  """
  @spec key(map(), [Sankey.key()]) :: String.t() | nil
  def key(%{node_keys: nil}, _nodes), do: nil

  def key(%{node_keys: keys}, nodes),
    do: nodes |> Enum.map(&keys[Sankey.name(&1)]) |> Enum.uniq() |> Enum.join(" ")

  @doc """
  Return the color of the node at a position from 0, from 1 to 8

      iex> Enum.map([0, 7, 8], &Expresso.Element.Chart.Layers.color/1)
      [1, 8, 1]
  """
  @spec color(non_neg_integer()) :: pos_integer()
  def color(index), do: rem(index, @colors) + 1
end
