defmodule Expresso.IconTransformer do
  @moduledoc """
  The Spark transformer of the icons of a deck

  It runs one time for each deck module at compile time, after
  `Expresso.PathTransformer`, which makes the `root` option an absolute path.
  It reads each SVG file of the `icons` option of the deck through
  `Expresso.DeckFile`, so the watch mode renders the deck again after a change
  to a file. Then it puts the SVG into each `icon` element, and it replaces
  each `:icon:name:` in the text of a text area and of an item with the SVG.

  A file that it cannot read, a file without an `svg` element and a name that
  no icon has are errors, which become a `Spark.Error.DslError`.
  """

  use Spark.Dsl.Transformer

  alias Expresso.Element.{Icon, Item, TextArea, Tree}
  alias Spark.Dsl.Transformer

  @doc """
  Run this transformer after the path transformer, which makes the root absolute
  """
  @impl Transformer
  @spec after?(module()) :: boolean()
  def after?(Expresso.PathTransformer), do: true
  def after?(_transformer), do: false

  @doc """
  Put the SVG of each icon into the elements of the deck
  """
  @impl Transformer
  @spec transform(map()) :: {:ok, map()} | {:error, Spark.Error.DslError.t()}
  def transform(dsl_state) do
    module = Transformer.get_persisted(dsl_state, :module)
    root = Transformer.get_option(dsl_state, [:deck], :root)
    icons = Transformer.get_option(dsl_state, [:deck], :icons) || []

    with {:ok, own} <- own(icons, root, module),
         {:ok, slides} <- slides(Transformer.get_entities(dsl_state, [:deck]), own, module) do
      {:ok, Map.replace_lazy(dsl_state, [:deck], &Map.put(&1, :entities, slides))}
    end
  end

  defp slides(slides, own, module) do
    slides
    |> Enum.reduce_while({:ok, []}, fn slide, {:ok, done} ->
      case Tree.map_ok(slide.elements, &element(&1, own)) do
        {:ok, elements} -> {:cont, {:ok, [%{slide | elements: elements} | done]}}
        {:error, message} -> {:halt, {:error, error(module, message, slide)}}
      end
    end)
    |> case do
      {:ok, done} -> {:ok, Enum.reverse(done)}
      error -> error
    end
  end

  # The SVG of each name of the icons option.
  defp own(icons, root, module) do
    Enum.reduce_while(icons, {:ok, %{}}, fn {name, path}, {:ok, own} ->
      path = Path.expand(path, root || File.cwd!())

      with {:ok, text} <- read(path),
           {:ok, svg} <- Expresso.Icon.svg_file(text) do
        {:cont, {:ok, Map.put(own, Atom.to_string(name), svg)}}
      else
        {:error, problem} ->
          message =
            "the icon #{inspect(Atom.to_string(name))} of the icons option: #{path} #{problem}"

          {:halt, {:error, error(module, message, nil)}}
      end
    end)
  end

  defp read(path) do
    case Expresso.DeckFile.read(path) do
      {:ok, text} -> {:ok, text}
      {:error, reason} -> {:error, "cannot be read: #{:file.format_error(reason)}"}
    end
  end

  defp element(%Icon{name: name} = icon, own) do
    with {:ok, svg} <- Expresso.Icon.svg(name, "icon-svg", own), do: {:ok, %{icon | svg: svg}}
  end

  defp element(%TextArea{text: text} = text_area, own) when is_binary(text) do
    with {:ok, text} <- Expresso.Icon.inline(text, own), do: {:ok, %{text_area | text: text}}
  end

  defp element(%Item{text: text} = item, own) when is_binary(text) do
    with {:ok, text} <- Expresso.Icon.inline(text, own), do: {:ok, %{item | text: text}}
  end

  defp element(element, _own), do: {:ok, element}

  defp error(module, message, slide) do
    path = if slide, do: [:deck, :slide] ++ List.wrap(slide.name), else: [:deck, :icons]
    Spark.Error.DslError.exception(module: module, message: message, path: path)
  end
end
