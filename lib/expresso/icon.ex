defmodule Expresso.Icon do
  @moduledoc """
  The icons of a deck: the Lucide icons, and the SVG files that a deck names

  `priv/icons/lucide.json` holds the Lucide icons (ISC license, see
  `priv/icons/LICENSE` and `priv/icons/SOURCE`). This module reads the file at
  compile time, so the document gets the SVG of each icon that a deck uses,
  and needs no network.

  The `icons` option of a deck gives names of its own, such as
  `icons logo: "assets/logo.svg"`. A name of the deck wins over a Lucide name.
  `svg_file/1` replaces each color of the fill and of the stroke of such a file
  with `currentColor`, so the icon takes the color of its text, as a Lucide
  icon does.

  `Expresso.IconTransformer` puts the SVG into each `icon` element, and it
  replaces each `:icon:name:` in the text of a text area and of an item.
  """

  @path Path.join([__DIR__, "..", "..", "priv", "icons", "lucide.json"])
  @external_resource @path

  # The inner markup of each Lucide icon, in a box of 24 units.
  @lucide @path
          |> File.read!()
          |> JSON.decode!()
          |> Map.new(fn {name, nodes} ->
            {name,
             Enum.map_join(nodes, fn [tag, attributes] ->
               attributes =
                 Enum.map_join(attributes, fn {key, value} -> ~s( #{key}="#{value}") end)

               "<#{tag}#{attributes}/>"
             end)}
          end)

  @names @lucide |> Map.keys() |> Enum.sort()

  # A name in the text of a text area or an item, such as `:icon:rocket:`.
  @inline ~r/:icon:([a-z0-9_-]+):/

  @doc """
  Return the name of each Lucide icon, in order

      iex> "rocket" in Expresso.Icon.names()
      true
  """
  @spec names() :: [String.t()]
  def names, do: @names

  @doc """
  Return the SVG of an icon with a class, or an error

  `own` maps the names of the deck to the SVG of their files, from
  `svg_file/1`. A name of the deck wins over a Lucide name.

      iex> {:ok, svg} = Expresso.Icon.svg("rocket", "icon-svg", %{})
      iex> svg =~ ~s(<svg class="icon-svg" viewBox="0 0 24 24")
      true
      iex> Expresso.Icon.svg("rokcet", "icon-svg", %{})
      {:error, "no icon has the name \\"rokcet\\". Names that are near: rocket, brackets, rose"}
  """
  @spec svg(String.t(), String.t(), %{String.t() => String.t()}) ::
          {:ok, String.t()} | {:error, String.t()}
  def svg(name, class, own) do
    case {Map.fetch(own, name), Map.fetch(@lucide, name)} do
      {{:ok, svg}, _lucide} -> {:ok, put_class(svg, class)}
      {:error, {:ok, inner}} -> {:ok, lucide(inner, class)}
      {:error, :error} -> {:error, unknown(name, own)}
    end
  end

  defp lucide(inner, class) do
    ~s(<svg class="#{class}" viewBox="0 0 24 24" fill="none" stroke="currentColor" ) <>
      ~s(stroke-width="2" stroke-linecap="round" stroke-linejoin="round" ) <>
      ~s(aria-hidden="true" focusable="false">#{inner}</svg>)
  end

  defp put_class(svg, class),
    do:
      String.replace(svg, "<svg", ~s(<svg class="#{class}" aria-hidden="true" focusable="false"),
        global: false
      )

  defp unknown(name, own) do
    near =
      (@names ++ Map.keys(own))
      |> Enum.uniq()
      |> Enum.sort_by(&String.jaro_distance(&1, name), :desc)
      |> Enum.take(3)
      |> Enum.join(", ")

    "no icon has the name #{inspect(name)}. Names that are near: #{near}"
  end

  @doc """
  Make the SVG of a file of a deck for an icon

  The function keeps the `svg` element and its content. It removes the XML
  declaration, a doctype, the comments, and the `width`, the `height` and the
  `class` of the `svg` element, so the style sheet gives the size. It replaces
  each color of a `fill` or a `stroke`, in an attribute or in a `style`, with
  `currentColor`. The values `none` and `currentColor` stay.

      iex> Expresso.Icon.svg_file(~s(<?xml version="1.0"?><svg width="10" viewBox="0 0 10 10"><path fill="#f00" stroke="none" d="M0 0h10"/></svg>))
      {:ok, ~s(<svg viewBox="0 0 10 10"><path fill="currentColor" stroke="none" d="M0 0h10"/></svg>)}
  """
  @spec svg_file(String.t()) :: {:ok, String.t()} | {:error, String.t()}
  def svg_file(text) do
    case Regex.run(~r/<svg\b.*<\/svg>/s, text) do
      [svg] ->
        svg =
          svg
          |> String.replace(~r/<!--.*?-->/s, "")
          |> remove_root_attributes()
          |> String.replace(
            ~r/\b(fill|stroke)="(?!none"|currentColor")[^"]*"/,
            ~s(\\1="currentColor")
          )
          |> String.replace(
            ~r/\b(fill|stroke)\s*:\s*(?!none\b|currentColor\b)[^;"]+/,
            "\\1: currentColor"
          )

        {:ok, svg}

      nil ->
        {:error, "has no svg element"}
    end
  end

  defp remove_root_attributes(svg) do
    [open | rest] = String.split(svg, ">", parts: 2)
    open = String.replace(open, ~r/\s(width|height|class)="[^"]*"/, "")
    Enum.join([open | rest], ">")
  end

  @doc """
  Replace each `:icon:name:` in a text with the SVG of the icon

  The icon gets the class `icon-inline`, so it has the size of the text. The
  function returns an error for the first name that no icon has.

      iex> {:ok, text} = Expresso.Icon.inline("Go :icon:rocket: now", %{})
      iex> text =~ ~s(Go <svg class="icon-inline")
      true
  """
  @spec inline(String.t(), %{String.t() => String.t()}) ::
          {:ok, String.t()} | {:error, String.t()}
  def inline(text, own) do
    @inline
    |> Regex.scan(text, capture: :all_but_first)
    |> List.flatten()
    |> Enum.uniq()
    |> Enum.reduce_while({:ok, text}, fn name, {:ok, text} ->
      case svg(name, "icon-inline", own) do
        {:ok, svg} -> {:cont, {:ok, String.replace(text, ":icon:#{name}:", svg)}}
        error -> {:halt, error}
      end
    end)
  end
end
