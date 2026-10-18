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
      run of white space.
    * `:source` - the `src` option of an image or of an embed.
    * `:file` - the file of a video or of a sound.
    * `:drawing` - the SVG of the element before the render gives it the
      ids of its copy, or the SVG of the rendered element.
    * `:language` - the language of a code element.
    * `:label` - the label of a stat.

  A kind without a content gets no signature. An element with the `morph`
  option gets no signature either, because its key gives its partner.
  """

  alias Expresso.Element.Tree

  # The kind and the content of each element module that the morph uses.
  @kinds for {module, _class, kind, content} <- Expresso.Element.kinds(),
             module != nil and content != nil,
             into: %{},
             do: {module, {kind, content}}

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
    %{element | signature: signature(kind, content(element, content))}
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

  defp content(element, :text), do: element |> html() |> Floki.text() |> words()

  # An icon gets its signature from the SVG before the render, because the
  # render gives each copy its own ids.
  defp content(element, :drawing) do
    svg =
      if is_binary(Map.get(element, :svg)),
        do: Floki.parse_fragment!(element.svg),
        else: html(element)

    case Floki.find(svg, "svg") do
      [{"svg", _attributes, children} | _others] -> Floki.raw_html(children)
      [] -> ""
    end
  end

  defp content(element, :source), do: element.src
  defp content(element, :file), do: element.src
  defp content(element, :language), do: element.lang || ""
  defp content(element, :label), do: words(element.label || "")

  defp html(%module{} = element) do
    element
    |> Expresso.Element.assigns()
    |> module.render()
    |> Phoenix.HTML.safe_to_string()
    |> Floki.parse_fragment!()
  end

  defp words(text), do: text |> String.split() |> Enum.join(" ")
end
