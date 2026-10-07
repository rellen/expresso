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
  holds one copy of the file for the present view and one for each page of
  the handout view, and a browser resolves a reference such as `url(#fill)`
  to the first element of the document with that `id`. That element can be in
  a view that the browser does not show, and a gradient or a filter in a
  hidden view does not paint. Therefore the render function gives each copy
  its own ids: it puts a number after each `id` of the file, and it puts the
  same number into each `url(#id)` and each `href="#id"` of the copy.

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
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    on: [],
    elements: [],
    __spark_metadata__: nil
  ]

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
  def place(%Expresso.Deck{slides: slides} = deck) do
    %Expresso.Deck{
      deck
      | slides: Enum.map(slides, &%{&1 | elements: place_all(&1.elements || [])})
    }
  end

  defp place_all(elements) do
    Enum.map(elements, fn
      %__MODULE__{elements: parts} = diagram ->
        if Enum.any?(parts, &moves?/1), do: place_parts(diagram), else: diagram

      %{elements: children} = element when is_list(children) ->
        %{element | elements: place_all(children)}

      element ->
        element
    end)
  end

  defp moves?(%Expresso.Element.Part{on: on}), do: Enum.any?(on, &(&1.move_to != nil))

  defp place_parts(%__MODULE__{src: src, elements: parts} = diagram) do
    tree = src |> read() |> Floki.parse_fragment!()
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
  `Expresso.Overlay.Render.attributes/1`. The key `svg` holds the SVG with
  the attributes of each part on its element. The function raises for a file
  that it cannot read, and for an `id` that the file does not hold.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(diagram) do
    %__MODULE__{src: src, elements: parts, width: width} = diagram

    %{
      svg: svg(src, parts),
      overlay: Expresso.Overlay.Render.attributes(diagram) ++ width(width)
    }
  end

  defp width(nil), do: []

  defp width(width) do
    [{"style", "--diagram-width: #{Expresso.Element.Image.viewport_unit(width)}"}]
  end

  defp svg(src, parts) do
    tree = src |> read() |> Floki.parse_fragment!()

    parts
    |> Enum.reduce(tree, fn %Expresso.Element.Part{id: id} = part, tree ->
      if Floki.find(tree, "##{id}") == [] do
        raise ArgumentError, "the diagram \"#{src}\" has no element with the id \"#{id}\""
      end

      mark(tree, id, part_attributes(part), nil)
    end)
    |> Floki.raw_html()
    |> number_ids(tree)
  end

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
        {tag, overlay ++ attrs, children}

      _other ->
        {tag, attrs, children}
    end
  end

  defp mark(node, _id, _attributes, _parent), do: node

  # Each copy of the file gets its own ids. The number is unique in the VM,
  # and the ids of each `part` stay in place, because the parts come before.
  defp number_ids(html, tree) do
    number = System.unique_integer([:positive, :monotonic])

    tree
    |> Floki.find("[id]")
    |> Floki.attribute("id")
    |> Enum.reduce(html, fn id, html ->
      html
      |> String.replace(~s(id="#{id}"), ~s(id="#{id}-#{number}"))
      |> String.replace("url(##{id})", "url(##{id}-#{number})")
      |> String.replace(~s(href="##{id}"), ~s(href="##{id}-#{number}"))
    end)
  end

  defp read(src) do
    case Expresso.DeckFile.read(src) do
      {:ok, bytes} -> bytes
      {:error, reason} -> raise ArgumentError, "cannot read the diagram \"#{src}\": #{reason}"
    end
  end

  @doc """
  Make the HTML of a diagram
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  # The SVG comes from a file that the deck names, as the text of a text area
  # comes from the deck.
  # sobelow_skip ["XSS.Raw"]
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes("diagram", assigns[:class]), rest!: @overlay do
        Phoenix.HTML.raw(@svg)
      end
    end
  end
end
