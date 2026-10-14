defmodule Expresso.Element.Chart.ParallelSets do
  @moduledoc """
  Draws a parallel sets chart: each group of records as one ribbon through
  the columns

  A category of a parallel sets chart is a path with one name for each
  column, as in an alluvial chart. Its value is the number of records in the
  group. The nodes have the layout of an alluvial chart, which
  `Expresso.Element.Chart.Sankey.layout_frames/3` returns. Each category is
  one ribbon from the first column to the last, so the user can see one
  group in each column. A sankey adds the flows of each link, so it does not
  show a group after the first node. Here, a ribbon is a chain of link
  shapes.

  The layout has these rules:

  1. Each ribbon has the color of its first node. Only the nodes of the
     first column have colors, in the order of the data, and the nodes of
     the other columns are gray.
  2. At each node, the ribbons have one stack, with the same place on the
     two sides of the node, so a ribbon does not break at a node.
  3. The stack of a node has the order of the nodes of each path, from the
     first column, so the ribbons of one first node stay together.

  `render/1` draws each series as a group with its ribbons. The nodes and
  their labels show with the chart. Thus `reveal true` adds the ribbons of
  one first node at each step. `table/1` writes a row for
  each path for a screen reader.
  """

  import Temple
  use Temple.Component

  alias Expresso.Element.Chart.{Motion, Plot, Sankey}

  @doc """
  Return the paths of the categories and the total value for each path

  Two categories with the same path add their values. The paths keep the
  order of their first category, and each node is the tuple of its column
  and its name.

      iex> Expresso.Element.Chart.ParallelSets.paths([["A", "B"], "A/B", "B/B"], [2, 3, 4], "/")
      {[[{0, "A"}, {1, "B"}], [{0, "B"}, {1, "B"}]], [5, 4]}
  """
  @spec paths([String.t() | [String.t()]], [number()], String.t()) ::
          {[[Sankey.key()]], [number()]}
  def paths(categories, values, separator) do
    categories
    |> Enum.map(&nodes(&1, separator))
    |> Enum.zip(values)
    |> Enum.reduce({[], %{}}, fn {path, value}, {order, sums} ->
      order = if Map.has_key?(sums, path), do: order, else: [path | order]
      {order, Map.update(sums, path, value, &(&1 + value))}
    end)
    |> then(fn {order, sums} ->
      paths = Enum.reverse(order)
      {paths, Enum.map(paths, &sums[&1])}
    end)
  end

  # The nodes of a category. A category after the check holds its nodes.
  defp nodes(category, separator) do
    case Sankey.path(category, separator) do
      [{_column, _name} | _] = nodes -> nodes
      names -> Enum.with_index(names, fn name, column -> {column, name} end)
    end
  end

  @doc """
  Make sure that each path has the same number of columns

      iex> Expresso.Element.Chart.ParallelSets.check([["A", "B"], ["B", "C"]], "/")
      :ok
      iex> Expresso.Element.Chart.ParallelSets.check([["A", "B"], ["B", "C", "D"]], "/")
      {:error, "each category of a parallel sets chart names one node for each column, and \\"B/C/D\\" names 3 nodes, but the first category names 2"}
  """
  @spec check([String.t() | [String.t()]], String.t()) :: :ok | {:error, String.t()}
  def check(categories, separator) do
    [first | _] = paths = Enum.map(categories, &Sankey.path(&1, separator))

    case Enum.find(paths, &(length(&1) != length(first))) do
      nil ->
        :ok

      other ->
        {:error,
         "each category of a parallel sets chart names one node for each column, " <>
           "and #{inspect(Enum.join(other, separator))} names #{length(other)} nodes, " <>
           "but the first category names #{length(first)}"}
    end
  end

  @doc """
  Place the nodes and the ribbons of each frame of a parallel sets chart

  `frames` holds the values of each frame, as one list of values for each
  series. `paths` holds the path of each category. The nodes have the
  layout of an alluvial chart. Each ribbon of a frame is a map with its
  path, its color, its series and the `d` attribute of its shape.
  """
  @spec layout([[Sankey.key()]], [[[number()]]], number(), map()) :: [
          %{nodes: [map()], ribbons: [map()], node_width: pos_integer(), xs: [number()]}
        ]
  def layout(paths, frames, top, settings) do
    groups = Enum.map(frames, &groups(paths, &1))

    colors =
      paths
      |> Enum.map(&hd/1)
      |> Enum.uniq()
      |> Enum.with_index(fn first, index -> {first, rem(index, 8) + 1} end)
      |> Map.new()

    links =
      for frame <- groups do
        for group <- frame,
            [from, to] <- Enum.chunk_every(group.path, 2, 1, :discard),
            do: %{from: from, to: to, value: group.value, series: group.series}
      end

    for {layout, frame} <- Enum.zip(Sankey.layout_frames(links, top, settings), groups) do
      scale = scale(layout.nodes)
      nodes = Enum.map(layout.nodes, &Map.put(&1, :color, colors[&1.name]))
      boxes = Map.new(nodes, &{&1.name, &1})

      %{
        nodes: nodes,
        ribbons: ribbons(frame, boxes, colors, scale),
        node_width: layout.node_width,
        xs: layout.xs
      }
    end
  end

  # The group of each path with a value in a series: its path, its value and
  # the number of its series.
  defp groups(paths, values) do
    for {series, number} <- Enum.with_index(values, 1),
        {path, value} <- Enum.zip(paths, series),
        value > 0,
        do: %{path: path, value: value, series: number}
  end

  # The height of one unit of value. The height of each node is its value
  # times the scale.
  defp scale([node | _]), do: node.height / node.value

  defp ribbons(groups, boxes, colors, scale) do
    sorted = Enum.sort_by(groups, fn group -> Enum.map(group.path, &boxes[&1].y) end)

    offsets =
      sorted
      |> Enum.flat_map(fn group -> Enum.map(group.path, &{&1, group}) end)
      |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
      |> Map.new(fn {node, through} ->
        {node,
         through
         |> Enum.map_reduce(0, fn group, y -> {{group, y}, y + group.value * scale} end)
         |> elem(0)
         |> Map.new()}
      end)

    for group <- groups do
      [first | _] = group.path
      height = group.value * scale

      d =
        group.path
        |> Enum.chunk_every(2, 1, :discard)
        |> Enum.map_join(" ", fn [from, to] ->
          source = boxes[from]
          target = boxes[to]

          Sankey.ribbon(
            source.x + Sankey.node_width(),
            source.y + offsets[from][group],
            target.x,
            target.y + offsets[to][group],
            height
          )
        end)

      Map.merge(group, %{color: colors[first], d: d})
    end
  end

  @doc """
  Draw the ribbons, the nodes and the labels of a parallel sets chart in its
  SVG

  The assigns are the assigns of `Expresso.Element.Chart`. A chart with
  frames has one layer for each frame, as a sankey has.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(%{frames: frames} = assigns) do
    layouts =
      layout(
        assigns.categories,
        Enum.map(frames, & &1.values),
        assigns.box.top,
        assigns.node_settings
      )

    layers =
      for {layout, k} <- Enum.with_index(layouts, 1),
          do: {k, Map.merge(layout, %{numbered: numbered(assigns, k), values: assigns.values})}

    assigns = Map.merge(assigns, %{layers: layers, xs: hd(layouts).xs})

    temple do
      Motion.frame_label(assigns)
      Sankey.titles(assigns)

      if length(@layers) == 1 do
        c(&drawing/1, rest!: @layers |> hd() |> elem(1))
      else
        for {k, layer} <- @layers do
          g class: "chart-layer chart-fade",
            style: "opacity: var(--k#{k}, #{if k == 1, do: 1, else: 0});" do
            c(&drawing/1, rest!: layer)
          end
        end
      end
    end
  end

  # Each series with its number from 1. A layer after the first has no morph
  # key, so the morph between two slides finds one copy of each mark.
  defp numbered(assigns, 1), do: Enum.with_index(assigns.series, 1)

  defp numbered(assigns, _layer) do
    for {series, number} <- Enum.with_index(assigns.series, 1),
        do: {%{series | overlay: no_morph(series.overlay)}, number}
  end

  defp no_morph(overlay), do: Enum.reject(overlay, &(elem(&1, 0) == "data-morph-key"))

  defp drawing(assigns) do
    temple do
      for {series, number} <- @numbered do
        g class: Expresso.Element.classes("chart-series", series.class), rest!: series.overlay do
          for ribbon <- @ribbons, ribbon.series == number do
            path class: "chart-link chart-c#{ribbon.color}", d: ribbon.d
          end
        end
      end

      g class: "chart-nodes" do
        for node <- @nodes do
          rect class: Expresso.Element.classes(node_class(node), node.class),
               x: Plot.f(node.x),
               y: Plot.f(node.y),
               width: @node_width,
               height: Plot.f(max(node.height, 1))
        end

        for node <- @nodes, node.labeled do
          text [class: "chart-node-label"] ++ Sankey.label_place(node) do
            Sankey.label_text(node, @values)
          end
        end
      end
    end
  end

  defp node_class(%{color: nil}), do: "chart-node chart-node-plain"
  defp node_class(%{color: color}), do: "chart-node chart-c#{color}"

  @doc """
  Write the table of a parallel sets chart: one row for each path, with the
  name of its node in each column and its value
  """
  @spec table(map()) :: Phoenix.HTML.safe()
  def table(assigns) do
    rows =
      for {path, index} <- Enum.with_index(assigns.categories) do
        values =
          for frame <- assigns.frames,
              do: frame.values |> Enum.map(&Enum.at(&1, index)) |> Enum.sum()

        {Enum.map(path, &Sankey.cell(assigns, Sankey.name(&1))), values}
      end

    assigns = Map.merge(assigns, %{rows: rows, headers: headers(assigns)})

    temple do
      table class: "chart-table" do
        caption do
          if @value_label, do: "#{@title} (#{@value_label})", else: @title
        end

        thead do
          tr do
            for words <- @headers do
              th scope: "col" do
                words
              end
            end
          end
        end

        tbody do
          for row <- @rows do
            c(&row/1, row: row)
          end
        end
      end
    end
  end

  # A title for each node column, then one column for each frame.
  defp headers(assigns) do
    count = length(hd(assigns.categories))

    titles =
      if Sankey.titles?(assigns),
        do: assigns.levels,
        else: Enum.map(1..count, &"Column #{&1}")

    columns =
      case assigns.frames do
        [_one] -> [assigns.value_label || "Value"]
        frames -> Enum.map(frames, & &1.label)
      end

    titles ++ columns
  end

  defp row(%{row: {[first | names], values}} = assigns) do
    assigns = Map.merge(assigns, %{first: first, names: names, values: values})

    temple do
      tr do
        th scope: "row" do
          @first
        end

        for name <- @names do
          td do
            name
          end
        end

        for value <- @values do
          td do
            Plot.label(value)
          end
        end
      end
    end
  end
end
