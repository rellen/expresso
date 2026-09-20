defmodule Expresso.Element.Diagram do
  @moduledoc """
  An element that shows an SVG file as a diagram

  The `src` option gives the path of the SVG file, and the path is relative to
  the working directory of the command, as for an image. The render function
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

  defstruct [:src, :width, :at, :steps, :el, on: [], elements: [], __spark_metadata__: nil]

  @doc """
  Make a diagram with a path, with parts and with a width
  """
  @spec new(Path.t(), [Expresso.Element.Part.t()], String.t() | nil) :: t()
  def new(src, parts \\ [], width \\ nil) do
    %__MODULE__{src: src, elements: parts, width: width}
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

      attributes = Expresso.Overlay.Render.attributes(part)
      Floki.find_and_update(tree, "##{id}", fn {tag, attrs} -> {tag, attributes ++ attrs} end)
    end)
    |> Floki.raw_html()
    |> number_ids(tree)
  end

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

  # The path comes from the deck, and `Code.eval_file/1` runs the deck.
  # sobelow_skip ["Traversal.FileModule"]
  defp read(src) do
    case File.read(src) do
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
      div class: "diagram", rest!: @overlay do
        Phoenix.HTML.raw(@svg)
      end
    end
  end
end
