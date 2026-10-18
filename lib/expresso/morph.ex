defmodule Expresso.Morph do
  @moduledoc """
  Gives each element that the auto morph uses a signature of its kind and its
  content

  The auto morph pairs an element of one slide with an element of the next
  slide when the two have the same kind and the same content.
  `Expresso.Renderer` calls `sign/1` before the render, and
  `Expresso.Overlay.Render.attributes/1` writes the signature of an element
  as `data-morph-signature`. The script in `assets/src/morph.ts` compares the
  signatures, so it does not read the content from the page.

  `Expresso.Element.kinds/0` gives the content of each kind:

    * `:text` - the text of the rendered element, with one space for each
      run of white space. The text of a `<style>` in an inline icon is not
      part of it, because the render gives each copy its own style rules.
    * `:source` - the `src` option of an image or of an embed.
    * `:file` - the file of a video or of a sound.
    * `:drawing` - the SVG of the element before the render gives it the
      ids of its copy, or the SVG of the rendered element.
    * `:svg` - the SVG of the file of a diagram, before the render gives it
      the ids of its copy. Two files with the same SVG have the same content.
    * `:shape` - the kind of a shape and its text.
    * `:language` - the language of a code element.
    * `:label` - the label of a stat.

  A kind without a content gets no signature. An element with an empty
  `:text`, `:drawing` or `:svg` content, such as a text area without a text
  or a diagram with an empty `svg` element, gets no signature, because two
  such elements are not the same element. A code without a language and a
  stat without a label still get a signature. An element with the `morph` option gets no signature either,
  because its key gives its partner.
  """

  alias Expresso.Element.Tree

  # The kind and the content of each element module that the morph uses.
  @kinds for {module, _class, kind, content} <- Expresso.Element.kinds(),
             module != nil and content != nil,
             into: %{},
             do: {module, {kind, content}}

  # The contents that are empty for an element with no text or no drawing.
  # An empty language or an empty label is a content: two codes without a
  # language pair, as two stats without a label do.
  @needs_content [:text, :drawing, :svg]

  # The number of the different signatures. Two different contents get the
  # same signature by chance only, with a probability of 1 in 2^32.
  @range 4_294_967_296

  @doc """
  Write the signature of each element of a deck that the auto morph uses
  """
  @spec sign(Expresso.Deck.t()) :: Expresso.Deck.t()
  def sign(deck), do: Tree.map_deck(deck, &sign_one/1)

  defp sign_one(%module{morph: nil} = element) when is_map_key(@kinds, module) do
    {kind, content} = Map.fetch!(@kinds, module)

    case content(element, content) do
      "" when content in @needs_content -> element
      content -> %{element | signature: signature(kind, content)}
    end
  end

  defp sign_one(element), do: element

  @doc """
  Return the signature of a kind of element and its content

  The slide template uses this function for the heading of a slide, with the
  kind `"heading"` and the text of the heading.

      iex> Expresso.Morph.signature("heading", "Coffee") ==
      ...>   Expresso.Morph.signature("heading", "Coffee")
      true
      iex> Expresso.Morph.signature("heading", "Coffee") ==
      ...>   Expresso.Morph.signature("stat", "Coffee")
      false
  """
  @spec signature(String.t(), String.t()) :: String.t()
  def signature(kind, content),
    do: {kind, content} |> :erlang.phash2(@range) |> Integer.to_string(36)

  defp content(element, :text),
    do: element |> html() |> Floki.text(style: false) |> words()

  # An icon gets its signature from the SVG before the render, because the
  # render gives each copy its own ids.
  defp content(element, :drawing) do
    svg =
      if is_binary(Map.get(element, :svg)),
        do: Floki.parse_fragment!(element.svg),
        else: html(element)

    children(svg)
  end

  # A diagram reads its file again, because the render gives each copy its
  # own ids and the attributes of its parts.
  defp content(element, :svg),
    do: element.src |> Expresso.DeckFile.read!("diagram") |> Floki.parse_fragment!() |> children()

  # A line and an arrow have no text, so their kind is their content.
  defp content(element, :shape), do: String.trim("#{element.kind} #{words(element.text || "")}")

  defp content(element, :source), do: element.src
  defp content(element, :file), do: element.src
  defp content(element, :language), do: element.lang || ""
  defp content(element, :label), do: words(element.label || "")

  defp children(svg) do
    case Floki.find(svg, "svg") do
      [{"svg", _attributes, children} | _others] -> children |> Floki.raw_html() |> String.trim()
      [] -> ""
    end
  end

  defp html(%module{} = element) do
    element
    |> Expresso.Element.assigns()
    |> module.render()
    |> Phoenix.HTML.safe_to_string()
    |> Floki.parse_fragment!()
  end

  defp words(text), do: text |> String.split() |> Enum.join(" ")
end
