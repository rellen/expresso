defmodule Expresso.Element.Embed do
  @moduledoc """
  An element that shows a web page in a slide

  The `embed` entity takes the source of the page as its first argument:

    * An address that starts with `https://` or `http://`. The browser loads
      the page from the network.
    * The path of a local HTML file, relative to the working directory of the
      command or to the `root` option of the deck. `sources/1` reads the file, and the document holds its text.
      The deck then stays one file, and the page works with no network.

  The `title` option names the page for a screen reader, and it is required.
  The `fallback` option gives the path of an image, which shows on paper, in
  the handout view, in the overview and while the page loads.

  The document holds a copy of each slide for the present view and one for
  each page of the handout view. A page in each copy would load the page many
  times, so no copy holds the source. The `iframe` element holds only
  `data-embed`, the number of the element in the deck, and the renderer
  writes the sources one time into the element `expresso-embeds`. The
  presenter loads a page when its slide shows in the present view, and the
  page then stays loaded.

  By default the page does not take a click or the focus, so the keys and the
  clicks of the presenter still work on the slide. With `interactive true`,
  the page takes the clicks, and a key goes to the page after a click on it.
  `docs/reference/embed-element.md` gives the rules.
  """

  use Expresso.Element

  @typedoc "The struct of an embed element"
  @type t :: %__MODULE__{}

  defstruct [
    :class,
    :src,
    :title,
    :width,
    :aspect,
    :fallback,
    :index,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    interactive: false,
    on: [],
    __spark_metadata__: nil
  ]

  @source_error "an embed takes an address that starts with https:// or http://, or the path of a local .html file"

  @doc """
  Make sure that the source of an embed is an address or the path of an HTML file

  This function is the custom type of the first argument. An address starts
  with `https://` or `http://`, and it has no space and no quotation mark. A
  path ends with `.html` or `.htm`. The function does not read the file, so a
  missing file gives an error at render time, as for an image.

      iex> Expresso.Element.Embed.source("https://example.com/page")
      {:ok, "https://example.com/page"}

      iex> Expresso.Element.Embed.source("pages/demo.html")
      {:ok, "pages/demo.html"}

      iex> {:error, _message} = Expresso.Element.Embed.source("javascript:alert(1)")
  """
  @spec source(term()) :: {:ok, String.t()} | {:error, String.t()}
  def source(value) when is_binary(value) do
    cond do
      address?(value) ->
        {:ok, value}

      Path.extname(value) in [".html", ".htm"] and not String.contains?(value, ":") ->
        {:ok, value}

      true ->
        {:error, @source_error}
    end
  end

  def source(_value), do: {:error, @source_error}

  @doc """
  Tell whether a source is an address on the network
  """
  @spec address?(String.t()) :: boolean()
  def address?(value), do: Regex.match?(~r{\Ahttps?://[^\s"'<>]+\z}, value)

  @doc """
  Make sure that an `aspect` option is a ratio, such as `"16/9"`

  The value is two positive numbers with a slash between them.
  """
  @spec aspect(term()) :: {:ok, String.t()} | {:error, String.t()}
  def aspect(value) when is_binary(value) do
    case Regex.run(~r{\A\s*(\d+(?:\.\d+)?)\s*/\s*(\d+(?:\.\d+)?)\s*\z}, value) do
      [_all, width, height] when width not in ["0", "0.0"] and height not in ["0", "0.0"] ->
        {:ok, "#{width}/#{height}"}

      _other ->
        {:error, "an aspect option takes two numbers with a slash, such as \"16/9\""}
    end
  end

  def aspect(_value),
    do: {:error, "an aspect option takes two numbers with a slash, such as \"16/9\""}

  @doc """
  Give each embed of a deck its number

  The number is the position of the element in the deck, in document order,
  from 0. `sources/1` writes the source of each embed at that position, and
  the render function writes the number into `data-embed`.
  `Expresso.Renderer` calls this function before the render.
  """
  @spec number(Expresso.Deck.t()) :: Expresso.Deck.t()
  def number(%Expresso.Deck{slides: slides} = deck) do
    {slides, _count} =
      Enum.map_reduce(slides, 0, fn slide, count ->
        {elements, count} = number_all(slide.elements || [], count)
        {%{slide | elements: elements}, count}
      end)

    %Expresso.Deck{deck | slides: slides}
  end

  defp number_all(elements, count) do
    Enum.map_reduce(elements, count, fn
      %__MODULE__{} = embed, count ->
        {%__MODULE__{embed | index: count}, count + 1}

      %{elements: children} = element, count when is_list(children) ->
        {children, count} = number_all(children, count)
        {%{element | elements: children}, count}

      element, count ->
        {element, count}
    end)
  end

  @doc """
  Return the source of each embed of a deck, in the order of their numbers

  An address gives `%{kind: "src", value: address}`. A local file gives
  `%{kind: "srcdoc", value: text}`, and the function reads the file through
  `Expresso.DeckFile`, so the watch mode renders the deck again after a
  change to the file. The function raises for a file that it cannot read.
  """
  @spec sources(Expresso.Deck.t()) :: [%{kind: String.t(), value: String.t()}]
  def sources(%Expresso.Deck{slides: slides}) do
    slides
    |> Enum.flat_map(&embeds(&1.elements || []))
    |> Enum.sort_by(& &1.index)
    |> Enum.map(&source_of/1)
  end

  defp embeds(elements) do
    Enum.flat_map(elements, fn
      %__MODULE__{} = embed -> [embed]
      %{elements: children} when is_list(children) -> embeds(children)
      _element -> []
    end)
  end

  defp source_of(%__MODULE__{src: src}) do
    if address?(src) do
      %{kind: "src", value: src}
    else
      case Expresso.DeckFile.read(src) do
        {:ok, text} -> %{kind: "srcdoc", value: text}
        {:error, reason} -> raise ArgumentError, "cannot read the page \"#{src}\": #{reason}"
      end
    end
  end

  @doc """
  Write the sources of the embeds of a deck as JSON, or return `nil`

  The value is a list with one object for each embed, in the order of their
  numbers, such as `[{"kind":"src","value":"https://example.com/"}]`. The
  renderer writes it into a `script` element, so the function escapes each
  `<`. A deck with no embed gets `nil`, and the document then holds no such
  element.
  """
  @spec json(Expresso.Deck.t()) :: String.t() | nil
  def json(deck) do
    case sources(deck) do
      [] ->
        nil

      sources ->
        sources
        |> Enum.map(&%{"kind" => &1.kind, "value" => &1.value})
        |> JSON.encode!()
        |> String.replace("<", "\\u003c")
    end
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, and the
  `style` attribute of the `width` and `aspect` options. The key `fallback`
  holds the data URI of the fallback image, or `nil`. The key `sandbox`
  holds the `sandbox` attribute of the frame.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(embed) do
    %__MODULE__{src: src, title: title, width: width, aspect: aspect} = embed

    style =
      [
        width && "--embed-width: #{Expresso.Element.Image.viewport_unit(width)}",
        aspect && "--embed-aspect: #{aspect}"
      ]
      |> Enum.reject(&is_nil/1)

    %{
      title: title,
      address: if(address?(src), do: src),
      index: embed.index,
      interactive: embed.interactive,
      sandbox: sandbox(src),
      fallback: embed.fallback && Expresso.Image.data_uri!(embed.fallback),
      overlay:
        Expresso.Overlay.Render.attributes(embed) ++
          if(style == [], do: [], else: [{"style", Enum.join(style, "; ")}])
    }
  end

  # A page from the network keeps its own origin, so it can keep its storage.
  # A local file has no origin of its own, and with `allow-same-origin` it
  # would get the origin of the deck. It then could read the deck, so it gets
  # scripts only.
  defp sandbox(src) do
    if address?(src), do: "allow-scripts allow-same-origin", else: "allow-scripts"
  end

  @doc """
  Make the HTML of an embed

  The root tag holds the fallback image or a placeholder with the title, and
  the frame on it. The frame has no source, and the presenter gives it one.
  A frame that is not interactive gets `tabindex="-1"`, so the key Tab does not
  go into it.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes("embed", assigns[:class]), rest!: @overlay do
        div class: "embed-box" do
          if @fallback do
            img class: "embed-fallback", src: @fallback, alt: @title
          else
            div class: "embed-fallback embed-placeholder" do
              p do: @title

              if @address do
                p class: "embed-address", do: @address
              end
            end
          end

          iframe class: "embed-frame",
                 title: @title,
                 data_embed: @index,
                 data_interactive: @interactive,
                 sandbox: @sandbox,
                 referrerpolicy: "no-referrer",
                 tabindex: if(@interactive, do: nil, else: "-1") do
          end
        end
      end
    end
  end
end
