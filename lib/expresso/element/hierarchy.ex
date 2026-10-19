defmodule Expresso.Element.Hierarchy do
  @moduledoc """
  A tree: a hierarchy of nodes as boxes and lines, such as an org chart or the
  use of a disk

  The `tree` entity holds one `node` entity, the root, and each node holds the
  nodes under it. The name of a node is its identity, and the default text of
  its box. The `detail` option of a node gives a second line, such as a role.
  A box can also show an image or an icon, and a line for each field.

  The color of a box comes from the `color` option of the node or of the
  nearest node above it, then from the `color` option of the tree, which takes
  the colors of the palette for each branch or for each value of a field.
  `colors/1` returns the color of each node.

  `Expresso.Element.Hierarchy.Layout` places each box, and the drawing is one
  SVG with the `viewBox` of the layout, so it scales to the box of the element.
  The lines are paths in the SVG. Each box is a `foreignObject` that holds the
  HTML of the box, so its text ends with an ellipsis as HTML does. The SVG is
  hidden from a screen reader. A nested list with the same tree holds the text
  for a screen reader, and the eye does not see it.

  The element module is `Hierarchy`, because `Expresso.Element.Tree` holds the
  functions that walk the elements of a slide. `docs/tree.md` gives the plan,
  and `docs/reference/tree-element.md` gives the rules for the author.
  """

  use Expresso.Element

  alias Expresso.Element.Hierarchy.Layout
  alias Expresso.Element.Chart
  alias Expresso.Element.Node

  @typedoc "The struct of a tree"
  @type t :: %__MODULE__{}

  defstruct [
              :title,
              :width,
              :box,
              :color,
              :class,
              elements: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  # The size of each box when the tree has no `box` option.
  @box [%{width: 220, height: 96}]

  @box_error "a box option takes the width and the height of each level, such as [[width: 280, height: 120], [width: 220, height: 96]], or one size, such as [width: 220, height: 96], with positive integers"

  @doc """
  Make sure that a `box` option gives the size of each level

  This function is the custom type of the option. The value is a list of
  sizes, one for each level from the root down, or one size for each level.
  A size is a keyword list with a positive integer for `width` and for
  `height`.

      iex> Expresso.Element.Hierarchy.box(width: 200, height: 80)
      {:ok, [%{width: 200, height: 80}]}

      iex> Expresso.Element.Hierarchy.box([[width: 280, height: 120], [width: 220, height: 96]])
      {:ok, [%{width: 280, height: 120}, %{width: 220, height: 96}]}

      iex> {:error, _message} = Expresso.Element.Hierarchy.box(width: 0, height: 80)
  """
  @spec box(term()) :: {:ok, [Layout.size()]} | {:error, String.t()}
  def box([{key, _value} | _rest] = size) when is_atom(key), do: box([size])

  def box([_ | _] = sizes) do
    sizes
    |> Enum.map(&size/1)
    |> Enum.reduce_while({:ok, []}, fn
      {:ok, size}, {:ok, sizes} -> {:cont, {:ok, [size | sizes]}}
      :error, _sizes -> {:halt, {:error, @box_error}}
    end)
    |> case do
      {:ok, sizes} -> {:ok, Enum.reverse(sizes)}
      error -> error
    end
  end

  def box(_value), do: {:error, @box_error}

  defp size(size) do
    with true <- Keyword.keyword?(size),
         [] <- Keyword.keys(size) -- [:width, :height],
         width when is_integer(width) and width > 0 <- size[:width],
         height when is_integer(height) and height > 0 <- size[:height] do
      {:ok, %{width: width, height: height}}
    else
      _invalid -> :error
    end
  end

  # The height of the legend under the tree, and the gap above it, in the
  # units of the drawing.
  @legend 40
  @legend_gap 24

  @color_error "a color option of a tree takes :branch or {:field, \"name\"}"

  @doc """
  Make sure that a `color` option of a tree is `:branch` or a field

  This function is the custom type of the option. The name of a field can be
  an atom or a string, and the function returns it as a string.

      iex> Expresso.Element.Hierarchy.color(:branch)
      {:ok, :branch}

      iex> Expresso.Element.Hierarchy.color({:field, :team})
      {:ok, {:field, "team"}}

      iex> {:error, _message} = Expresso.Element.Hierarchy.color(:leaf)
  """
  @spec color(term()) :: {:ok, :branch | {:field, String.t()}} | {:error, String.t()}
  def color(:branch), do: {:ok, :branch}
  def color({:field, name}) when is_binary(name) and name != "", do: {:ok, {:field, name}}

  def color({:field, name}) when is_atom(name) and name not in [nil, true, false],
    do: {:ok, {:field, Atom.to_string(name)}}

  def color(_value), do: {:error, @color_error}

  @doc """
  Return the color of each node, by its name, and the values of the legend

  A color is `{:role, role}` for the `color` option of a node or of a node
  above it, `{:palette, n}` for a color of the palette from 1 to 8, or `nil`.
  The legend holds each value of the field of `color {:field, name}` and its
  color of the palette, in the order of the first node with the value.

      iex> alias Expresso.Element.{Hierarchy, Node}
      iex> root = %Node{name: "A", elements: [%Node{name: "B", elements: [%Node{name: "C"}]}, %Node{name: "D", color: :danger}]}
      iex> Hierarchy.colors(%Hierarchy{color: :branch, elements: [root]})
      {%{"A" => nil, "B" => {:palette, 1}, "C" => {:palette, 1}, "D" => {:role, :danger}}, []}
  """
  @spec colors(t()) :: {%{String.t() => color}, [{String.t(), pos_integer()}]}
        when color: {:role, atom()} | {:palette, pos_integer()} | nil
  def colors(%__MODULE__{elements: [root], color: color}) do
    legend = legend(root, color)
    {paint(root, {color, Map.new(legend)}, {nil, nil, 0}, %{}), legend}
  end

  # Put the color of a node and of each node under it into `colors`. The
  # context holds the role of the nearest node above with the option, the
  # branch and the depth. A role comes before a color of the palette.
  defp paint(%Node{} = node, {color, palette} = scheme, {role, branch, depth}, colors) do
    role = if node.color, do: {:role, node.color}, else: role
    colors = Map.put(colors, node.name, role || palette(node, color, branch, palette))

    (node.elements || [])
    |> Enum.with_index()
    |> Enum.reduce(colors, fn {child, index}, colors ->
      branch = if depth == 0, do: {:palette, Chart.Layers.color(index)}, else: branch
      paint(child, scheme, {role, branch, depth + 1}, colors)
    end)
  end

  defp palette(_node, :branch, branch, _palette), do: branch

  defp palette(node, {:field, name}, _branch, palette) do
    case field(node, name) do
      nil -> nil
      value -> {:palette, Map.fetch!(palette, value)}
    end
  end

  defp palette(_node, nil, _branch, _palette), do: nil

  defp legend(root, {:field, name}) do
    root
    |> nodes()
    |> Enum.map(&field(&1, name))
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq()
    |> Enum.with_index(fn value, index -> {value, Chart.Layers.color(index)} end)
  end

  defp legend(_root, _color), do: []

  defp field(%Node{fields: fields}, name) do
    Enum.find_value(fields || [], fn {key, value} -> if key == name, do: value end)
  end

  @doc """
  Make sure that a tree has one root, and that each node is a node of a tree

  `Expresso.Extension` calls this function when it builds the entity, so the
  DSL and `Expresso.Builder` give the same errors.
  """
  @spec check(t()) :: {:ok, t()} | {:error, String.t()}
  def check(%__MODULE__{elements: [%Node{} = root]} = tree) do
    nodes = nodes(root)
    names = Enum.map(nodes, & &1.name)
    twice = names -- Enum.uniq(names)

    cond do
      chart = Enum.find(nodes, &(Node.chart_options(&1) != [])) ->
        {:error,
         "the node \"#{chart.name}\" gives the #{hd(Node.chart_options(chart))} option, " <>
           "and only a node of a chart of flows takes it"}

      match?({:field, _name}, tree.color) and
          not Enum.any?(nodes, &field(&1, elem(tree.color, 1))) ->
        {:error,
         "the color option of the tree names the field \"#{elem(tree.color, 1)}\", " <>
           "and no node of the tree has that field. Give the field in the fields option of a node"}

      twice != [] ->
        {:error,
         "the tree has two nodes with the name \"#{hd(twice)}\". " <>
           "A name is the identity of a node, so give one node a different name and a label, " <>
           "such as node \"#{hd(twice)}-2\", label: \"#{hd(twice)}\""}

      true ->
        {:ok, tree}
    end
  end

  def check(%__MODULE__{elements: []}),
    do: {:error, "a tree holds one node entity, the root, and this tree holds none"}

  def check(%__MODULE__{elements: elements}),
    do:
      {:error,
       "a tree holds one node entity, the root, and this tree holds #{length(elements)}. " <>
         "Put the nodes under one root node"}

  # Each node of a subtree, in the order of the tree.
  defp nodes(%Node{elements: children} = node),
    do: [node | Enum.flat_map(children || [], &nodes/1)]

  @doc """
  Make the assigns of the render function from the struct

  The key `layout` holds the boxes and the lines of
  `Expresso.Element.Hierarchy.Layout`, and the key `root` holds the root node
  for the list of a screen reader. The key `colors` holds the CSS color of
  each node by its name, and the key `legend` holds the place of the legend
  and each value with its color.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(%__MODULE__{elements: [root]} = tree) do
    layout = Layout.top_down(root, tree.box || @box)
    {colors, legend} = colors(tree)

    legend =
      if legend == [],
        do: nil,
        else: %{
          y: layout.height + @legend_gap,
          width: layout.width,
          height: @legend,
          values: Enum.map(legend, fn {value, n} -> {value, css({:palette, n})} end)
        }

    height = if legend, do: legend.y + legend.height, else: layout.height

    width =
      if tree.width,
        do: [{"style", "--tree-width: #{Expresso.Element.viewport_unit(tree.width)}"}],
        else: []

    %{
      title: tree.title,
      root: root,
      layout: layout,
      colors: Map.new(colors, fn {name, color} -> {name, css(color)} end),
      legend: legend,
      view_box: "0 0 #{layout.width} #{height}",
      overlay: Expresso.Overlay.Render.attributes(tree) ++ width
    }
  end

  # The CSS value of a color.
  defp css(nil), do: nil
  defp css({:role, role}), do: "var(--#{role})"
  defp css({:palette, n}), do: "var(--chart-#{n})"

  @doc """
  Make the HTML of a tree

  The `figure` holds the SVG of the drawing, which a screen reader does not
  read, and a nested list of the nodes, which the eye does not see. The
  legend is in the SVG under the tree, and each field of a node is in the
  list, so a screen reader reads the value that gives a color.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      figure class: Expresso.Element.classes("tree", assigns[:class]), rest!: @overlay do
        svg viewBox: @view_box, aria_hidden: "true" do
          g class: "tree-lines" do
            for line <- @layout.lines do
              path class: "tree-line", d: line
            end
          end

          for box <- @layout.boxes do
            foreignObject x: box.x, y: box.y, width: box.width, height: box.height do
              c(&card/1, node: box.node, color: @colors[box.node.name])
            end
          end

          if @legend do
            foreignObject x: 0, y: @legend.y, width: @legend.width, height: @legend.height do
              ul class: "tree-legend", xmlns: "http://www.w3.org/1999/xhtml" do
                for {value, color} <- @legend.values do
                  li style: "--tree-color: #{color}" do
                    span class: "tree-swatch"
                    value
                  end
                end
              end
            end
          end
        end

        ul class: "tree-list", aria_label: @title do
          c(&item/1, node: @root)
        end
      end
    end
  end

  # The HTML of one box: the image or the icon, then the label, the detail
  # and the fields.
  defp card(assigns) do
    assigns = Map.merge(assigns, card_attributes(assigns.node, assigns.color))

    temple do
      div class: @classes, style: @style, xmlns: "http://www.w3.org/1999/xhtml" do
        c(&media/1, node: @node)

        div class: "tree-text" do
          p class: "tree-label" do
            @node.label || @node.name
          end

          if @node.detail do
            p class: "tree-detail" do
              @node.detail
            end
          end

          for {name, value} <- @node.fields || [] do
            p class: "tree-field" do
              span class: "tree-field-name" do
                name
              end

              " " <> value
            end
          end
        end
      end
    end
  end

  # The classes and the style of a box.
  defp card_attributes(%Node{} = node, color) do
    classes =
      ["tree-box"] ++
        if(color, do: ["tree-colored"], else: []) ++
        if(node.image || node.svg, do: ["tree-media"], else: []) ++
        List.wrap(node.class)

    %{classes: Enum.join(classes, " "), style: color && "--tree-color: #{color}"}
  end

  # The image or the icon of a box, or nothing.
  defp media(%{node: %Node{image: image}} = assigns) when is_binary(image) do
    assigns = Map.put(assigns, :src, Expresso.Image.data_uri!(image))

    temple do
      img class: "tree-image", src: @src, alt: ""
    end
  end

  defp media(%{node: %Node{svg: svg}} = assigns) when is_binary(svg) do
    assigns = Map.put(assigns, :svg, Expresso.SvgCopy.copy(svg))

    temple do
      span class: "tree-icon" do
        Phoenix.HTML.raw(@svg)
      end
    end
  end

  defp media(_assigns), do: ""

  # The label, the detail and the fields of a node, for a screen reader.
  defp spoken(%Node{} = node) do
    fields = Enum.map(node.fields || [], fn {name, value} -> "#{name}: #{value}" end)
    Enum.join(Enum.reject([node.label || node.name, node.detail], &is_nil/1) ++ fields, ", ")
  end

  # One node and the nodes under it, for a screen reader.
  defp item(assigns) do
    temple do
      li do
        spoken(@node)

        if (@node.elements || []) != [] do
          ul do
            for child <- @node.elements do
              c(&item/1, node: child)
            end
          end
        end
      end
    end
  end
end
