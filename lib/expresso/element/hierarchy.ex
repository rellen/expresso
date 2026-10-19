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
  alias Expresso.Element.Hierarchy.Steps
  alias Expresso.Element.Hierarchy.Values
  alias Expresso.Element.Chart
  alias Expresso.Element.Focus
  alias Expresso.Overlay
  alias Expresso.Element.Chart.Csv
  alias Expresso.Element.Hierarchy.Data
  alias Expresso.Element.Node

  @typedoc "The struct of a tree"
  @type t :: %__MODULE__{}

  defstruct [
              :title,
              :width,
              :box,
              :color,
              :limit,
              :depth,
              :stack_from,
              :src,
              :delimiter,
              :fields,
              :class,
              sum: true,
              value_format: :number,
              sort: :none,
              bar: false,
              layout: :top_down,
              reveal: nil,
              dim: false,
              reflow: false,
              highlight: nil,
              whole_first: false,
              focus: [],
              separator: "/",
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

  @delimiter_error "the delimiter option is one character, and not a quote or a line break"

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
  Return the item of the `highlight` option for a node and each node under it

  `use Expresso` imports this function, so a deck can write
  `highlight ["Ben", branch("Ben")]`.

      iex> Expresso.Element.Hierarchy.branch("Ben")
      {:branch, "Ben"}
  """
  @spec branch(String.t()) :: {:branch, String.t()}
  def branch(name) when is_binary(name), do: {:branch, name}

  @highlight_error "a highlight option takes a list of groups, such as [\"Ben\", branch(\"Ben\"), [\"Cy\", \"Di\"]]. A group is the name of a node, branch(name), or a list of those"

  @doc """
  Make sure that a `highlight` option is a list of groups

  This function is the custom type of the option. A group is the name of a
  node, `{:branch, name}`, or a list of those. The function returns each
  group as a list.

      iex> Expresso.Element.Hierarchy.highlight(["Ben", {:branch, "Eve"}, ["Cy", "Di"]])
      {:ok, [["Ben"], [{:branch, "Eve"}], ["Cy", "Di"]]}

      iex> {:error, _message} = Expresso.Element.Hierarchy.highlight([[]])
  """
  @spec highlight(term()) :: {:ok, [[String.t() | {:branch, String.t()}]]} | {:error, String.t()}
  def highlight([_ | _] = groups) do
    groups = Enum.map(groups, &group/1)

    if Enum.all?(groups, &(&1 != [] and Enum.all?(&1, fn item -> item?(item) end))),
      do: {:ok, groups},
      else: {:error, @highlight_error}
  end

  def highlight(_groups), do: {:error, @highlight_error}

  defp group(items) when is_list(items), do: items
  defp group(item), do: [item]

  defp item?(name) when is_binary(name), do: true
  defp item?({:branch, name}) when is_binary(name), do: true
  defp item?(_item), do: false

  @doc """
  Make sure that a `stack_from` option is a level under the root

  This function is the custom type of the option. The root is level 1, and
  it has no node above it to stack under, so the first level is 2.

      iex> Expresso.Element.Hierarchy.stack_from(3)
      {:ok, 3}

      iex> {:error, _message} = Expresso.Element.Hierarchy.stack_from(1)
  """
  @spec stack_from(term()) :: {:ok, pos_integer()} | {:error, String.t()}
  def stack_from(level) when is_integer(level) and level >= 2, do: {:ok, level}

  def stack_from(level),
    do:
      {:error,
       "a stack_from option takes a level of 2 or more, because the root is level 1, " <>
         "and #{inspect(level)} is not"}

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
  DSL and `Expresso.Builder` give the same errors. A tree with `src` has no
  nodes yet, so the function checks only its options, and `build/1` checks
  the tree after it reads the file. Nodes with the `parent` option become a
  nested tree first.
  """
  @spec check(t()) :: {:ok, t()} | {:error, String.t()}
  def check(%__MODULE__{src: src, elements: []} = tree) when is_binary(src) do
    cond do
      tree.separator == "" -> {:error, "the separator option needs at least one character"}
      not delimiter?(tree.delimiter) -> {:error, @delimiter_error}
      true -> {:ok, tree}
    end
  end

  def check(%__MODULE__{src: src}) when is_binary(src),
    do:
      {:error,
       "a tree takes its nodes from the src file or from node entities, and this tree has both"}

  def check(%__MODULE__{delimiter: delimiter}) when is_binary(delimiter),
    do:
      {:error,
       "the delimiter option gives the character between two cells, so it needs the src option"}

  def check(%__MODULE__{fields: [_ | _]}),
    do:
      {:error,
       "the fields option names columns of the src file, so it needs the src option. " <>
         "Give the fields option to a node in place of it"}

  def check(%__MODULE__{} = tree) do
    with {:ok, tree} <- parents(tree), do: nodes_check(tree)
  end

  @doc """
  Read the CSV file of a tree with `src`, and make its nodes

  `Expresso.PathTransformer` calls this function after it joins the path to
  the root of the deck. `Expresso.Element.Hierarchy.Data` tells the two
  forms of a file. The function reads the file through `Expresso.DeckFile`,
  so the watch mode renders the deck again after a change to the file.
  """
  @spec build(t()) :: {:ok, t()} | {:error, String.t()}
  def build(%__MODULE__{src: src} = tree) when is_binary(src) do
    delimiter =
      tree.delimiter || if(String.downcase(Path.extname(src)) == ".tsv", do: "\t", else: ",")

    with {:ok, text} <- read(src),
         {:ok, rows} <- Csv.rows(text, src, delimiter: delimiter),
         {:ok, roots} <- Data.rows(rows, src, fields: tree.fields, separator: tree.separator) do
      nodes_check(%__MODULE__{tree | elements: roots})
    end
  end

  defp read(src) do
    case Expresso.DeckFile.read_text(src) do
      {:ok, text} -> {:ok, text}
      {:error, reason} -> {:error, Expresso.DeckFile.read_error(src, "tree file", reason)}
    end
  end

  defp delimiter?(nil), do: true

  defp delimiter?(delimiter),
    do: String.length(delimiter) == 1 and delimiter not in ["\"", "\n", "\r"]

  # Nodes with the parent option go under the node that they name. Only a
  # node at the top of the tree takes the option.
  defp parents(%__MODULE__{elements: elements} = tree) do
    nested = elements |> Enum.flat_map(&(&1.elements || [])) |> Enum.flat_map(&nodes/1)

    cond do
      nested_parent = Enum.find(nested, & &1.parent) ->
        {:error,
         "the node entity \"#{nested_parent.name}\" is inside a node and gives the parent option. " <>
           "Give the parent option only to a node at the top of the tree"}

      Enum.any?(elements, & &1.parent) ->
        elements
        |> Enum.map(&{&1, &1.parent, "the node entity \"#{&1.name}\""})
        |> Data.assemble()
        |> case do
          {:ok, roots} -> {:ok, %__MODULE__{tree | elements: roots}}
          error -> error
        end

      true ->
        {:ok, tree}
    end
  end

  defp nodes_check(%__MODULE__{elements: [%Node{} = root]} = tree) do
    nodes = nodes(root)

    with :ok <- chart_options(nodes),
         :ok <- morph(nodes),
         :ok <- color_field(tree, nodes),
         :ok <- root_value(tree),
         :ok <- names(nodes),
         do: focus(tree, nodes)
  end

  defp nodes_check(%__MODULE__{elements: []}),
    do: {:error, "a tree holds one node entity, the root, and this tree holds none"}

  defp nodes_check(%__MODULE__{elements: elements}),
    do:
      {:error,
       "a tree holds one node entity, the root, and this tree holds #{length(elements)}. " <>
         "Put the nodes under one root node"}

  defp positive?(%__MODULE__{elements: [%Node{value: value}]}),
    do: is_number(value) and value > 0

  @doc """
  Return the tree after the options of the values

  `Expresso.Element.Hierarchy.Values.prepare/2` applies `depth`, `sum`,
  `sort` and `limit` to the root. The layout, the colors and the HTML read
  this tree, so each one shows the same nodes.
  """
  @spec prepared(t()) :: t()
  def prepared(%__MODULE__{elements: [root]} = tree) do
    options = [depth: tree.depth, sum: tree.sum, sort: tree.sort, limit: tree.limit]
    %__MODULE__{tree | elements: [Values.prepare(root, options)]}
  end

  defp chart_options(nodes) do
    case Enum.find(nodes, &(Node.chart_options(&1) != [])) do
      nil ->
        :ok

      chart ->
        {:error,
         "the node \"#{chart.name}\" gives the #{hd(Node.chart_options(chart))} option, " <>
           "and only a node of a chart of flows takes it"}
    end
  end

  # The groups of the highlight option. Each group takes one step from the
  # counter of the slide, as the groups of a chart do.
  defp focus(%__MODULE__{highlight: nil, whole_first: true}, _nodes),
    do: {:error, "the whole_first option of a tree needs the highlight option"}

  defp focus(%__MODULE__{highlight: nil} = tree, _nodes), do: {:ok, tree}

  defp focus(%__MODULE__{} = tree, nodes) do
    names = MapSet.new(nodes, & &1.name)

    unknown =
      tree.highlight
      |> List.flatten()
      |> Enum.map(fn
        {:branch, name} -> name
        name -> name
      end)
      |> Enum.find(&(not MapSet.member?(names, &1)))

    cond do
      tree.reveal != nil ->
        {:error, "a tree takes the reveal option or the highlight option, and not both"}

      tree.dim ->
        {:error,
         "the highlight option dims the other nodes itself, so the tree takes no dim option"}

      unknown != nil ->
        {:error,
         "the highlight option names the node \"#{unknown}\", and the tree has no node with that name"}

      true ->
        {:ok, next} = Overlay.new(:next)
        groups = for group <- tree.highlight, do: %Focus{keys: group, at: next}
        {:ok, %__MODULE__{tree | focus: groups}}
    end
  end

  defp morph(nodes) do
    case Enum.find(nodes, & &1.morph) do
      nil ->
        :ok

      node ->
        {:error,
         "the node \"#{node.name}\" gives the morph option, and a node of a tree takes none. " <>
           "Give the morph option to the tree"}
    end
  end

  defp color_field(%__MODULE__{color: {:field, name}}, nodes) do
    if Enum.any?(nodes, &field(&1, name)),
      do: :ok,
      else:
        {:error,
         "the color option of the tree names the field \"#{name}\", " <>
           "and no node of the tree has that field. Give the field in the fields option of a node, " <>
           "or name its column in the fields option of the tree"}
  end

  defp color_field(_tree, _nodes), do: :ok

  defp root_value(%__MODULE__{bar: bar, value_format: format} = tree)
       when bar or format == :percent do
    if positive?(prepared(tree)),
      do: :ok,
      else:
        {:error,
         "the #{if bar, do: "bar option", else: "value_format :percent"} of a tree " <>
           "needs the value of the root, and the root has no value above 0. " <>
           "Give a value to the nodes, or keep the sum option true"}
  end

  defp root_value(_tree), do: :ok

  defp names(nodes) do
    names = Enum.map(nodes, & &1.name)

    case names -- Enum.uniq(names) do
      [] ->
        :ok

      [name | _rest] ->
        {:error,
         "the tree has two nodes with the name \"#{name}\". " <>
           "A name is the identity of a node, so give one node a different name and a label, " <>
           "such as node \"#{name}-2\", label: \"#{name}\""}
    end
  end

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
  def get_assigns(%__MODULE__{} = tree) do
    %__MODULE__{elements: [root]} = tree = prepared(tree)
    layout = Layout.layout(root, sizes(tree), layout_options(tree))
    {colors, legend} = colors(tree)
    steps = Steps.effective(root)
    index = layout.boxes |> Enum.with_index() |> Map.new(fn {box, i} -> {box.node.name, i} end)
    nodes = Map.new(layout.boxes, &{&1.node.name, &1.node})

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
      boxes:
        Enum.map(layout.boxes, &{&1, node_attributes(&1.node, steps, numbered?(tree), index)}),
      lines: tree |> lines(root, layout, steps, nodes) |> number_lines(numbered?(tree), index),
      colors: Map.new(colors, fn {name, color} -> {name, css(color)} end),
      legend: legend,
      values: %{format: tree.value_format, total: root.value, bar: tree.bar},
      view_box: "0 0 #{layout.width} #{height}",
      overlay: Expresso.Overlay.Render.attributes(tree) ++ width
    }
  end

  defp sizes(tree), do: tree.box || @box
  defp layout_options(tree), do: [layout: tree.layout, stack_from: tree.stack_from]

  # A tree with `reflow` or with the `highlight` option gives each box and
  # each line the place of its node in the full layout, which the rules of
  # the moves and of the groups name.
  defp numbered?(%__MODULE__{reflow: reflow, focus: focus}), do: reflow or focus != []

  # The overlay attributes of the box of a node, with the steps of its box.
  defp node_attributes(%Node{} = node, steps, numbered?, index) do
    attributes = Expresso.Overlay.Render.attributes(%Node{node | steps: steps[node.name]})
    if numbered?, do: attributes ++ [number(node.name, index)], else: attributes
  end

  defp number_lines(lines, false, _index),
    do: Enum.map(lines, fn {path, _to, attributes} -> {path, attributes} end)

  defp number_lines(lines, true, index),
    do:
      Enum.map(lines, fn {path, to, attributes} -> {path, attributes ++ [number(to, index)]} end)

  defp number(name, index), do: {"data-node", Integer.to_string(index[name])}

  # The path of each line and its attributes. A line takes the steps of the
  # node at its end. With `reflow`, each run of steps with the same boxes has
  # its own copy of the lines, at the steps of the run.
  defp lines(%__MODULE__{reflow: true} = tree, root, layout, steps, nodes) do
    case Steps.layouts(root, sizes(tree), layout_options(tree), layout) do
      [] ->
        lines(%__MODULE__{tree | reflow: false}, root, layout, steps, nodes)

      layouts ->
        for {run, run_layout} <- runs(layouts),
            {path, to} <- Enum.zip(run_layout.lines, run_layout.targets),
            shown = Enum.filter(run, &(steps[to] == nil or &1 in steps[to])),
            shown != [] do
          node = %{nodes[to] | steps: shown}
          {path, to, Expresso.Overlay.Render.attributes(node)}
        end
    end
  end

  defp lines(_tree, _root, layout, steps, nodes) do
    for {path, to} <- Enum.zip(layout.lines, layout.targets) do
      {path, to, Expresso.Overlay.Render.attributes(%{nodes[to] | steps: steps[to]})}
    end
  end

  # The steps in a row that show the same boxes, with the layout of the first.
  defp runs(layouts) do
    layouts
    |> Enum.chunk_by(fn {_step, layout} -> Enum.map(layout.boxes, & &1.node.name) end)
    |> Enum.map(fn [{_step, layout} | _rest] = run -> {Enum.map(run, &elem(&1, 0)), layout} end)
  end

  @doc """
  Return the rules of the moves and of the groups of a tree

  With `reflow`, at each step, a box that is not in its place of the full
  layout gets the custom properties `--tree-dx` and `--tree-dy`, and the style
  sheet moves it with a transition.

  A group of the `highlight` option gives one rule at its step. The rule sets
  `--dimmed: 1` on each box and each line whose node is not in the group, so
  the line to a box in focus keeps its color. A branch holds the node and
  each node under it in the tree after the options of the values, also the
  node of the rest of a `limit`. A node that `depth` or `limit` removes has
  no box, so the rule leaves it out.

  `Expresso.Overlay.Render.style/1` adds the rules to the style block of the
  deck. A tree without `reflow` and without `highlight` has no rules.
  """
  @spec rules(t()) :: [String.t()]
  def rules(%__MODULE__{el: el, elements: [_root]} = tree) when is_binary(el) do
    %__MODULE__{elements: [root]} = tree = prepared(tree)
    full = Layout.layout(root, sizes(tree), layout_options(tree))
    index = full.boxes |> Enum.with_index() |> Map.new(fn {box, i} -> {box.node.name, i} end)
    move_rules(tree, root, full, index) ++ focus_rules(tree, root, index)
  end

  def rules(_tree), do: []

  defp move_rules(%__MODULE__{reflow: true, el: el} = tree, root, full, index) do
    root
    |> Steps.layouts(sizes(tree), layout_options(tree), full)
    |> Steps.offsets(full)
    |> Enum.sort()
    |> Enum.map(fn {step, name, dx, dy} ->
      "section[data-step=\"#{step}\"] [data-el=\"#{el}\"] [data-node=\"#{index[name]}\"] " <>
        "{ --tree-dx: #{dx}px; --tree-dy: #{dy}px; }"
    end)
  end

  defp move_rules(_tree, _root, _full, _index), do: []

  defp focus_rules(%__MODULE__{focus: focus, el: el}, root, index) do
    for %Focus{keys: keys, steps: steps} <- focus, step <- steps || [] do
      others =
        keys
        |> Enum.flat_map(&focused(&1, root))
        |> Enum.filter(&Map.has_key?(index, &1))
        |> Enum.map_join(&":not([data-node=\"#{index[&1]}\"])")

      "section[data-step=\"#{step}\"] [data-el=\"#{el}\"] [data-node]#{others} " <>
        "{ --dimmed: 1; }"
    end
  end

  # The names of the nodes of an item of a group.
  defp focused({:branch, name}, root),
    do: root |> find(name) |> List.wrap() |> Enum.flat_map(&nodes/1) |> Enum.map(& &1.name)

  defp focused(name, _root), do: [name]

  defp find(%Node{name: name} = node, name), do: node

  defp find(%Node{elements: children}, name),
    do: Enum.find_value(children || [], &find(&1, name))

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
            for {line, attributes} <- @lines do
              path class: "tree-line", d: line, pathLength: "1", rest!: attributes
            end
          end

          for {box, attributes} <- @boxes do
            foreignObject class: "tree-node",
                          x: box.x,
                          y: box.y,
                          width: box.width,
                          height: box.height,
                          rest!: attributes do
              c(&card/1, node: box.node, color: @colors[box.node.name], values: @values)
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
          c(&item/1, node: @root, values: @values)
        end
      end
    end
  end

  # The HTML of one box: the image or the icon, then the label, the detail
  # and the fields.
  defp card(assigns) do
    assigns =
      assigns
      |> Map.merge(card_attributes(assigns.node, assigns.color))
      |> Map.merge(value_attributes(assigns.node, assigns.values))

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

          if @value do
            p class: "tree-value" do
              @value
            end
          end
        end

        if @bar do
          span class: "tree-bar" do
            span class: "tree-bar-fill", style: "width: #{@bar}%"
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

  # The text of the value of a node, and the length of its bar in percent.
  defp value_attributes(%Node{value: nil}, _values), do: %{value: nil, bar: nil}

  defp value_attributes(%Node{value: value}, %{format: format, total: total, bar: bar}) do
    %{
      value: Values.text(value, format, total),
      bar: if(bar, do: Layout.number(Float.round(min(value / total, 1.0) * 100, 2)))
    }
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

  # The label, the detail, the fields and the value of a node, for a screen
  # reader.
  defp spoken(%Node{} = node, values) do
    fields = Enum.map(node.fields || [], fn {name, value} -> "#{name}: #{value}" end)
    %{value: value} = value_attributes(node, values)

    Enum.join(
      Enum.reject([node.label || node.name, node.detail], &is_nil/1) ++ fields ++ List.wrap(value),
      ", "
    )
  end

  # One node and the nodes under it, for a screen reader.
  defp item(assigns) do
    temple do
      li do
        spoken(@node, @values)

        if (@node.elements || []) != [] do
          ul do
            for child <- @node.elements do
              c(&item/1, node: child, values: @values)
            end
          end
        end
      end
    end
  end
end
