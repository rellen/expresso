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

  alias Expresso.Dsl
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
         {:ok, slides} <- Dsl.map_slides(dsl_state, &slide(&1, own)) do
      {:ok, Dsl.put_slides(dsl_state, slides)}
    end
  end

  defp slide(slide, own) do
    with {:ok, elements} <- Tree.map_ok(slide.elements, &element(&1, own)),
         do: {:ok, %{slide | elements: elements}}
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

          {:halt, {:error, Dsl.error(module, [:deck, :icons], message)}}
      end
    end)
  end

  defp read(path) do
    case Expresso.DeckFile.read_text(path) do
      {:ok, text} -> {:ok, text}
      {:error, :not_utf8} -> {:error, "is not UTF-8 text. Save the file with the UTF-8 encoding"}
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
end
