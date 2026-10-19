defmodule Expresso.PathTransformer do
  @moduledoc """
  The Spark transformer of the paths of a deck

  It runs one time for each deck module at compile time, and before
  `Expresso.Overlay.Transformer`. When the deck has the `root` option, it
  joins each relative path of the deck to that directory: the `src` of an
  image, a diagram, a code element, a local embed, a video and a sound, the
  `fallback` of an embed, the `poster` of a video, the `image` of a node of a
  tree, and the `css` option when it is a path. An absolute path and the address of an embed stay as they
  are. The option itself becomes an absolute
  path, so the renderer can resolve a `url()` of an inline style sheet.

  Then it builds each code element with `src`: it reads the file, and it
  makes the groups of lines with `Expresso.Element.Code.build/1`. The entity
  of a code element cannot read the file, because the `root` option of the
  deck is not known when the entity is made. An error of the build becomes a
  `Spark.Error.DslError` with the path of the slide.

  `docs/reference/root-option.md` gives the rules.
  """

  use Spark.Dsl.Transformer

  alias Expresso.Element.{Audio, Chart, Code, Diagram, Embed, Image, Node, Tree, Video}
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

    dsl_state
    |> Transformer.set_option([:deck], :root, root)
    |> then(fn state ->
      if css == nil or Expresso.Css.inline?(css),
        do: state,
        else: Transformer.set_option(state, [:deck], :css, path(css, root))
    end)
  end

  defp slide(%{elements: elements} = slide, root) do
    with {:ok, elements} <- Tree.map_ok(elements, &own(&1, root)),
         do: {:ok, %{slide | elements: elements}}
  end

  defp slide(entity, _root), do: {:ok, entity}

  defp own(%Code{text: nil, src: src} = code, root) when is_binary(src),
    do: Code.build(%Code{code | src: path(src, root)})

  defp own(%Chart{src: src} = chart, root) when is_binary(src),
    do: Chart.build(%Chart{chart | src: path(src, root)})

  defp own(%Image{src: src} = image, root), do: {:ok, %Image{image | src: path(src, root)}}

  defp own(%Diagram{src: src} = diagram, root),
    do: {:ok, %Diagram{diagram | src: path(src, root)}}

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
