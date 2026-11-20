defmodule Expresso.PathTransformer do
  @moduledoc """
  Joins the paths of a deck to its root, as a Spark transformer

  It runs one time for each deck module at compile time.
  When the deck has the `root` option, it joins each relative path of the deck
  to that directory:

  - the `src` of an image, a diagram, a code element, a chart, a tree, a
    local embed, a video and a sound
  - the `font` of a diagram
  - the `fallback` of an embed
  - the `poster` and the `captions` of a video
  - the `image` of a node in a tree
  - the image in the `background` option of a slide and of the deck
  - the picture of the `card` option
  - the icon of the `favicon` option
  - the `css` option, when it is a path

  An absolute path and the address of an embed stay as they are. The `root`
  option itself becomes an absolute path, so the renderer can resolve a
  `url()` of an inline style sheet.

  Then it builds each code element with `src`: it reads the file, and it
  makes the groups of lines with `Expresso.Element.Code.build/1`. It builds
  a chart and a tree with `src` from their files in the same way. The entity
  of a code element cannot read the file, because the `root` option of the
  deck is not known when the entity is made. An error of the build becomes a
  `Spark.Error.DslError` with the path of the slide.

  `docs/reference/root-option.md` gives the rules.
  """

  use Spark.Dsl.Transformer

  alias Expresso.Element.{Audio, Chart, Code, Diagram, Embed, Hierarchy, Image, Node, Tree, Video}
  alias Expresso.Dsl
  alias Spark.Dsl.Transformer

  @doc """
  Run this transformer before the overlay transformer, which needs the groups of lines
  """
  @impl Transformer
  @spec before?(module()) :: boolean()
  def before?(Expresso.Overlay.Transformer), do: true
  def before?(_transformer), do: false

  @doc """
  Join each relative path of the deck to the root, and build each code element with `src`
  """
  @impl Transformer
  @spec transform(map()) :: {:ok, map()} | {:error, Spark.Error.DslError.t()}
  def transform(dsl_state) do
    root = dsl_state |> Transformer.get_option([:deck], :root) |> expand()
    dsl_state = put_root(dsl_state, root)

    with {:ok, slides} <- Dsl.map_slides(dsl_state, &slide(&1, root)),
         do: {:ok, Dsl.put_slides(dsl_state, slides)}
  end

  defp expand(nil), do: nil
  defp expand(root), do: Path.expand(root)

  defp put_root(dsl_state, nil), do: dsl_state

  defp put_root(dsl_state, root) do
    css = Transformer.get_option(dsl_state, [:deck], :css)
    background = Transformer.get_option(dsl_state, [:deck], :background)

    dsl_state
    |> Transformer.set_option([:deck], :root, root)
    |> then(fn state ->
      if background == nil,
        do: state,
        else:
          Transformer.set_option(
            state,
            [:deck],
            :background,
            Expresso.Background.put_root(background, root)
          )
    end)
    |> put_file(:card, root)
    |> put_file(:favicon, root)
    |> then(fn state ->
      if css == nil or Expresso.Css.inline?(css),
        do: state,
        else: Transformer.set_option(state, [:deck], :css, path(css, root))
    end)
  end

  # The picture of the card and the icon of the tab are files of the deck.
  # `Expresso.LinkPreview.put_root/2` keeps a deck with no such option as it
  # is.
  defp put_file(dsl_state, option, root) do
    case Transformer.get_option(dsl_state, [:deck], option) do
      nil ->
        dsl_state

      value ->
        Transformer.set_option(
          dsl_state,
          [:deck],
          option,
          Expresso.LinkPreview.put_root(value, root)
        )
    end
  end

  defp slide(%{elements: elements} = slide, root) do
    with {:ok, elements} <- Tree.map_ok(elements, &own(&1, root)) do
      background = Expresso.Background.put_root(Map.get(slide, :background), root)
      {:ok, %{slide | elements: elements} |> Map.replace(:background, background)}
    end
  end

  defp slide(entity, _root), do: {:ok, entity}

  defp own(%Code{text: nil, src: src} = code, root) when is_binary(src),
    do: Code.build(%Code{code | src: path(src, root)})

  defp own(%Chart{src: src} = chart, root) when is_binary(src),
    do: Chart.build(%Chart{chart | src: path(src, root)})

  defp own(%Hierarchy{src: src} = tree, root) when is_binary(src) do
    with {:ok, tree} <- Hierarchy.build(%Hierarchy{tree | src: path(src, root)}),
         do: Hierarchy.map_frames(tree, &own(&1, root))
  end

  defp own(%Hierarchy{} = tree, root), do: Hierarchy.map_frames(tree, &own(&1, root))

  defp own(%Image{src: src} = image, root), do: {:ok, %Image{image | src: path(src, root)}}

  defp own(%Diagram{src: src, font: font} = diagram, root),
    do: {:ok, %Diagram{diagram | src: path(src, root), font: path(font, root)}}

  defp own(%Embed{src: src, fallback: fallback} = embed, root) do
    src = if Embed.address?(src), do: src, else: path(src, root)
    {:ok, %Embed{embed | src: src, fallback: path(fallback, root)}}
  end

  defp own(%Video{src: src, poster: poster, captions: captions} = video, root),
    do:
      {:ok,
       %Video{
         video
         | src: path(src, root),
           poster: path(poster, root),
           captions: path(captions, root)
       }}

  defp own(%Audio{src: src} = audio, root), do: {:ok, %Audio{audio | src: path(src, root)}}

  defp own(%Node{image: image} = node, root) when is_binary(image),
    do: {:ok, %Node{node | image: path(image, root)}}

  defp own(element, _root), do: {:ok, element}

  defp path(nil, _root), do: nil
  defp path(path, nil), do: path
  defp path(path, root), do: Path.expand(path, root)
end
