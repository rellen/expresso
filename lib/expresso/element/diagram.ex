defmodule Expresso.Element.Diagram do
  @moduledoc """
  An element that shows an SVG file as a diagram

  The `src` option gives the path of the SVG file, and the path is relative to
  the working directory of the command or to the `root` option of the deck, as
  for an image. The render function
  puts the SVG into the document as an element, and not as a data URI as
  `Expresso.Element.Image` does. Therefore the rules of the theme reach the
  parts of the diagram, and a part can show at a step.

  A `part` entity names an element of the file by its `id`, and the `at`
  option and the `on` entities of the part give the steps. The parts are the
  children of the diagram, so the transformer gives each part its steps, and
  the verifier checks each part against the diagram. The render function
  writes the overlay attributes of a part on the element of the file that has
  its `id`. A file without that `id` stops the render with a message that
  names the id and the path.

  A part with an `on` entity, or with an effect that moves or grows it, goes
  into a wrapper, a `g` element with the class `diagram-part`, and the wrapper
  gets the overlay attributes. The theme moves,
  turns and outlines the wrapper, so the part keeps its own `transform`
  attribute, and a turn goes around the center of the part. A `g` element is
  valid only in an `svg`, a `g` or an `a` element. A part in a different
  parent, such as a `tspan`, gets the attributes itself, and it can then only
  fade, dim and change its color.

  The `width` option gives the width of the diagram, as the option of an image
  does, and a percentage is a part of the width of the slide. A diagram
  without the option takes the width that the file gives.

  The file goes into the document as it is, with one change. The document
  holds one copy of the file for the present view, one for each page of the
  handout view and one in the menu. A browser resolves a reference such as
  `url(#fill)` to the first element of the document with that `id`, and a
  `<style>` element applies to the whole document. Therefore
  `Expresso.SvgCopy.number/2` gives each copy its own ids, its own references
  and its own style rules. `Expresso.Copies` gives the number.

  A part with a `class` in a `text` element keeps its class next to the
  class `diagram-part`. The render function finds a part by its `id`
  attribute, so an id such as `step.1` or `a:b` works.

  A `.dot` or a `.gv` file is the source of a graph in the language of
  Graphviz, and a `.d2` file is the source of a graph in the language of D2.
  `draw/1` runs the tool before the render, and it keeps the SVG and the
  names of the graph in the struct. `Expresso.Element.Diagram.Graphviz` and
  `Expresso.Element.Diagram.D2` give each element of the graph a name from the
  source, so a part names it in the words of the source. The `layout` option
  gives the layout engine of the tool. With the `edges` option `:follow`, the
  default, `draw/1` gives each edge without its own part the steps where both
  of its ends show. `docs/graph-diagrams.md` gives the plan.

  `Expresso.Deck.render/1` writes the document with Floki, which writes each
  name of the SVG in lowercase. A browser reads `viewbox` as `viewBox` and
  `lineargradient` as `linearGradient` inside an `svg` element, so the
  diagram keeps its meaning.
  """

  use Expresso.Element

  @typedoc "The struct of a diagram"
  @type t :: %__MODULE__{}

  defstruct [
              :class,
              :src,
              :width,
              :alt,
              :layout,
              :edges,
              :colors,
              :font,
              # The SVG and the names of a graph, from `draw/1`.
              :svg,
              :names,
              elements: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Replace each `move_to` of the parts of a deck with a move

  An `on` entity of a part can take `move_to`, the id of an element of the
  SVG file. This function reads the file of each diagram with such an entity,
  and `Expresso.Element.Diagram.Geometry.distance/3` gives the distance from
  the center of the part to the center of that element. The function puts the
  distance into `set` as `x` and `y`, in the units of the file, and the render
  writes it as for each other `set`. A change of the file then changes the
  move at the next render.

  `Expresso.Renderer` calls this function before the render. It raises for
  an id that the file does not have, and for an element with no shape.
  """
  @spec place(Expresso.Deck.t()) :: Expresso.Deck.t()
  def place(%Expresso.Deck{} = deck), do: Expresso.Element.Tree.map_deck(deck, &place_one/1)

  defp place_one(%__MODULE__{elements: parts} = diagram) do
    if Enum.any?(parts, &moves?/1), do: place_parts(diagram), else: diagram
  end

  defp place_one(element), do: element

  defp moves?(%Expresso.Element.Part{on: on}), do: Enum.any?(on, &(&1.move_to != nil))

  defp place_parts(%__MODULE__{src: src, elements: parts} = diagram) do
    tree = parse(diagram)
    %__MODULE__{diagram | elements: Enum.map(parts, &place_part(&1, tree, src))}
  end

  defp place_part(%Expresso.Element.Part{id: id, on: on} = part, tree, src) do
    on =
      Enum.map(on, fn
        %Expresso.Element.On{move_to: nil} = entity ->
          entity

        %Expresso.Element.On{move_to: target, set: set} = entity ->
          case Expresso.Element.Diagram.Geometry.distance(tree, id, target) do
            {:ok, {x, y}} ->
              %Expresso.Element.On{entity | set: [x: pixels(x), y: pixels(y)] ++ (set || [])}

            {:error, message} ->
              raise ArgumentError, "the diagram \"#{src}\" #{message}"
          end
      end)

    %Expresso.Element.Part{part | on: on}
  end

  # A length of CSS in the units of the file. The theme moves a part in the
  # coordinates of its parent, and a pixel of CSS is one unit there.
  defp pixels(value) do
    rounded = Float.round(value, 2)
    if rounded == Float.round(rounded), do: "#{trunc(rounded)}px", else: "#{rounded}px"
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`, and, with the `alt` option, the
  role `img` and the name of the diagram. The key `svg` holds the SVG with
  the attributes of each part on its element. The function raises for a file
  that it cannot read, and for an `id` that the file does not hold.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(diagram) do
    %__MODULE__{src: src, width: width, alt: alt, colors: colors} = diagram

    %{
      svg: svg(diagram),
      kind: kind(tool(src), colors),
      overlay: Expresso.Overlay.Render.attributes(diagram) ++ width(width) ++ alt(alt)
    }
  end

  # The classes of the diagram. A graph with the colors of the theme has the
  # class `diagram-graph` and a class for its tool, so the style sheet gives
  # it the colors of the theme.
  defp kind(nil, _colors), do: "diagram"
  defp kind(_tool, :tool), do: "diagram"

  defp kind(Expresso.Element.Diagram.Graphviz, _colors),
    do: "diagram diagram-graph diagram-graphviz"

  defp kind(Expresso.Element.Diagram.D2, _colors), do: "diagram diagram-graph diagram-d2"

  # A diagram with a text is one image for a screen reader, and the text of
  # the SVG is then not read. Without a text, a screen reader reads the text
  # of the SVG.
  defp alt(nil), do: []
  defp alt(alt), do: [{"role", "img"}, {"aria-label", alt}]

  defp width(nil), do: []

  defp width(width) do
    [{"style", "--diagram-width: #{Expresso.Element.viewport_unit(width)}"}]
  end

  defp svg(%__MODULE__{src: src, elements: parts} = diagram) do
    diagram = draw_one(diagram)
    tree = parse(diagram)

    parts
    |> Enum.reduce(tree, fn %Expresso.Element.Part{id: id} = part, tree ->
      if not has_id?(tree, id) do
        raise ArgumentError,
              "the diagram \"#{src}\" has no element with the id \"#{id}\"" <> names(diagram)
      end

      mark(tree, id, part_attributes(part), nil)
    end)
    |> Floki.raw_html()
    |> Expresso.SvgCopy.number(Expresso.Copies.next())
  end

  # An SVG file from Graphviz, Inkscape or Illustrator starts with an XML
  # declaration and a DOCTYPE. Neither one is valid in an HTML document, so
  # the parse removes them.
  defp parse(diagram),
    do: diagram |> text() |> Floki.parse_fragment!() |> Enum.reject(&prolog?/1)

  # The author cannot read the names of a graph in its SVG, so the message
  # lists them.
  defp names(%__MODULE__{names: [_ | _] = names}),
    do: ". The graph has these names: " <> Enum.map_join(names, ", ", &~s("#{&1}"))

  defp names(_diagram), do: ""

  defp prolog?({:pi, "xml", _attrs}), do: true
  defp prolog?({:doctype, _name, _public, _system}), do: true
  defp prolog?(_node), do: false

  # Compare the attribute `id` exactly. A CSS selector such as `#step.1`
  # reads the id `step` and the class `1`.
  defp has_id?(nodes, id) when is_list(nodes), do: Enum.any?(nodes, &has_id?(&1, id))

  # Only an element has attributes. A processing instruction, such as the
  # `xpacket` of Illustrator in its metadata, is also a tuple of 3.
  defp has_id?({tag, attrs, children}, id) when is_binary(tag),
    do: List.keyfind(attrs, "id", 0) == {"id", id} or has_id?(children, id)

  defp has_id?(_node, _id), do: false

  # The overlay attributes of a part. A part with an `on` entity, or with an
  # effect that moves or grows it, goes into a wrapper with the class
  # `diagram-part`, so the theme can move it. The class has a prefix, so it
  # does not match a class of the file.
  defp part_attributes(%Expresso.Element.Part{el: nil, effect: effect} = part)
       when effect in [nil, :fade, :wipe, :blur] do
    {:attributes, Expresso.Overlay.Render.attributes(part)}
  end

  defp part_attributes(part) do
    {:wrapper, [{"class", "diagram-part"} | Expresso.Overlay.Render.attributes(part)]}
  end

  # Put the attributes of a part on the element with its id. The wrapper is a
  # `g` element, and a `g` element is valid only in a container. Therefore an
  # element in a different parent, such as a `tspan` in a `text` element, gets
  # the attributes itself. It then can fade and dim, and it cannot move.
  defp mark(nodes, id, attributes, parent) when is_list(nodes) do
    Enum.map(nodes, &mark(&1, id, attributes, parent))
  end

  defp mark({tag, attrs, children}, id, attributes, parent) when is_binary(tag) do
    children = mark(children, id, attributes, tag)

    case {List.keyfind(attrs, "id", 0), attributes} do
      {{"id", ^id}, {:wrapper, wrapper}} when parent in ["svg", "g", "a"] ->
        {"g", wrapper, [{tag, attrs, children}]}

      {{"id", ^id}, {_kind, overlay}} ->
        {tag, merge(overlay, attrs), children}

      _other ->
        {tag, attrs, children}
    end
  end

  defp mark(node, _id, _attributes, _parent), do: node

  # Put the overlay attributes on an element. An HTML parser keeps the first
  # of two attributes with the same name, so a `class` and a `style` of the
  # element join the attribute of the overlay.
  defp merge(overlay, attrs) do
    {overlay, attrs} =
      Enum.map_reduce(overlay, attrs, fn {name, value}, attrs ->
        case List.keytake(attrs, name, 0) do
          {{"class", own}, attrs} -> {{"class", "#{value} #{own}"}, attrs}
          {{"style", own}, attrs} -> {{"style", "#{own}; #{value}"}, attrs}
          {_own, attrs} -> {{name, value}, attrs}
          nil -> {{name, value}, attrs}
        end
      end)

    overlay ++ attrs
  end

  @doc """
  Return the SVG of a diagram

  The SVG of a graph comes from `draw/1`, and the SVG of a file comes from the
  file. `Expresso.Morph` reads the SVG with this function too.
  """
  @spec text(t()) :: String.t()
  def text(%__MODULE__{svg: svg}) when is_binary(svg), do: svg

  def text(%__MODULE__{src: src} = diagram),
    do: if(tool(src), do: draw_one(diagram).svg, else: read(src))

  defp read(src), do: Expresso.DeckFile.read_text!(src, "diagram")

  @doc """
  Run the tool of each graph of a deck, and keep the SVG and the names

  `Expresso.Renderer` calls this function before `place/1`, so a render runs
  each tool one time. A diagram of an SVG file does not change.
  """
  @spec draw(Expresso.Deck.t()) :: Expresso.Deck.t()
  def draw(%Expresso.Deck{} = deck),
    do: Expresso.Element.Tree.map_deck(deck, &(&1 |> draw_one() |> follow()))

  # With `edges :follow`, an edge without its own part shows from the step
  # where both of its ends show. Each tool writes the ends of an edge into the
  # attributes `data-graph-from` and `data-graph-to`. An end without a part, or
  # with a part without steps, shows at each step. An edge with two such ends
  # shows at each step, so it needs no part.
  defp follow(%__MODULE__{svg: svg, edges: edges, elements: parts} = diagram)
       when is_binary(svg) and edges in [nil, :follow] do
    steps = Map.new(parts, &{&1.id, &1.steps})

    added =
      for {"g", attrs, _children} <-
            svg |> Floki.parse_fragment!() |> Floki.find("g[data-graph-from]"),
          attrs = Map.new(attrs),
          not Map.has_key?(steps, attrs["id"]),
          shown = both(steps[attrs["data-graph-from"]], steps[attrs["data-graph-to"]]),
          shown != nil,
          do: %Expresso.Element.Part{id: attrs["id"], steps: shown}

    %__MODULE__{diagram | elements: parts ++ added}
  end

  defp follow(element), do: element

  defp both(nil, steps), do: steps
  defp both(steps, nil), do: steps
  defp both(from, to), do: Enum.filter(from, &(&1 in to))

  defp draw_one(%__MODULE__{svg: nil, src: src, layout: layout} = diagram) do
    case tool(src) do
      nil ->
        diagram

      tool ->
        # The read records the source for the watch mode, and it stops the
        # render for a file that it cannot read.
        read(src)
        {svg, names} = tool.draw!(src, layout || hd(tool.layouts()), font(diagram.font))
        svg = if diagram.colors == :tool, do: svg, else: tool.theme(svg)
        %__MODULE__{diagram | svg: svg, names: names}
    end
  end

  defp draw_one(element), do: element

  defp font(nil), do: Expresso.Element.Diagram.Font.builtin()
  defp font(dir), do: Expresso.Element.Diagram.Font.read!(dir)

  # The tool of a source, from the extension of its file. An SVG file has no
  # tool.
  defp tool(src) do
    case src |> Path.extname() |> String.downcase() do
      ext when ext in [".dot", ".gv"] -> Expresso.Element.Diagram.Graphviz
      ".d2" -> Expresso.Element.Diagram.D2
      _other -> nil
    end
  end

  @doc """
  Refuse the options of a graph for an SVG file, and a layout of a different tool

  The entity of the DSL and `Expresso.Builder` call this function.
  """
  @spec check(t()) :: {:ok, t()} | {:error, String.t()}
  def check(%__MODULE__{src: src, layout: layout} = diagram) do
    tool = tool(src)
    given = Enum.find([:layout, :edges, :colors, :font], &(Map.fetch!(diagram, &1) != nil))

    cond do
      tool == nil and given != nil ->
        {:error, graph_option(given, src)}

      tool != nil and layout != nil and layout not in tool.layouts() ->
        {:error,
         "the layout of the diagram \"#{src}\" is one of " <>
           Enum.map_join(tool.layouts(), ", ", &inspect/1) <> ", and not #{inspect(layout)}"}

      true ->
        {:ok, diagram}
    end
  end

  defp graph_option(option, src),
    do:
      "the #{option} option applies to the source of a graph, such as a .dot or a .d2 file, " <>
        "so the diagram \"#{src}\" takes no #{option} option"

  @doc """
  Make the HTML of a diagram
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  # The SVG comes from a file that the deck names, as the text of a text area
  # comes from the deck.
  # sobelow_skip ["XSS.Raw"]
  @impl Expresso.Element
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes(@kind, assigns[:class]), rest!: @overlay do
        Phoenix.HTML.raw(@svg)
      end
    end
  end
end
