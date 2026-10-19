defmodule Expresso.Element.Hierarchy do
  @moduledoc """
  A tree: a hierarchy of nodes as boxes and lines, such as an org chart or the
  use of a disk

  The `tree` entity holds one `node` entity, the root, and each node holds the
  nodes under it. The name of a node is its identity, and the default text of
  its box. The `detail` option of a node gives a second line, such as a role.

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
  alias Expresso.Element.Node

  @typedoc "The struct of a tree"
  @type t :: %__MODULE__{}

  defstruct [
              :title,
              :width,
              :box,
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
  for the list of a screen reader.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(%__MODULE__{elements: [root]} = tree) do
    layout = Layout.top_down(root, tree.box || @box)

    width =
      if tree.width,
        do: [{"style", "--tree-width: #{Expresso.Element.viewport_unit(tree.width)}"}],
        else: []

    %{
      title: tree.title,
      root: root,
      layout: layout,
      view_box: "0 0 #{layout.width} #{layout.height}",
      overlay: Expresso.Overlay.Render.attributes(tree) ++ width
    }
  end

  @doc """
  Make the HTML of a tree

  The `figure` holds the SVG of the drawing, which a screen reader does not
  read, and a nested list of the nodes, which the eye does not see.
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
              div class: Expresso.Element.classes("tree-box", box.node.class),
                  xmlns: "http://www.w3.org/1999/xhtml" do
                p class: "tree-label" do
                  box.node.label || box.node.name
                end

                if box.node.detail do
                  p class: "tree-detail" do
                    box.node.detail
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

  # The label and the detail of a node, for a screen reader.
  defp spoken(%Node{} = node),
    do: Enum.join(Enum.reject([node.label || node.name, node.detail], &is_nil/1), ", ")

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
