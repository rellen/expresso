defmodule Expresso.LinkPreview do
  @moduledoc """
  The tags of the document for the address of a deck and for a link preview

  A chat program or a social network makes a card for a link from the Open
  Graph tags of the page. Four options of the deck give the values, and each
  one is optional:

    * `url` is the address of the deck on its host. The document then has
      `link rel="canonical"`, the Open Graph tags and `twitter:card`.
    * `card` is the picture of the card. The render keeps a copy of the file
      next to the document, as `Expresso.MediaFiles` does for an `image` with
      `external true`, and `og:image` holds the absolute address of the copy.
      It needs the `url` option.
    * `favicon` is the icon of the tab. It goes into the document as a data
      URI, so it needs no address.
    * `robots` is the content of `meta name="robots"`, such as `"noindex"`.

  Expresso itself writes no address of a network into the document. An
  address comes only from the `url` option, which the user gives.
  `docs/document-tags.md` gives the design.
  """

  alias Expresso.Deck

  @typedoc "The picture of a card: the path of the file, and its text for a screen reader"
  @type card :: %{image: Path.t(), alt: String.t() | nil}

  @typedoc "One element of the head: its tag and its attributes"
  @type tag :: {:meta | :link, keyword()}

  # The media type of each extension of a picture of a card. Each program
  # that makes a card reads a PNG file and a JPEG file.
  @card_types %{".png" => "image/png", ".jpg" => "image/jpeg", ".jpeg" => "image/jpeg"}

  # The media type of each extension of an icon.
  @icon_types %{".svg" => "image/svg+xml", ".png" => "image/png", ".ico" => "image/x-icon"}

  @doc """
  Validate the `url` option: the absolute address of the deck on its host

      iex> Expresso.LinkPreview.url("https://example.com/talk/")
      {:ok, "https://example.com/talk/"}
      iex> Expresso.LinkPreview.url("example.com/talk")
      {:error, "the url option must be an address that starts with https:// or http://, such as \\"https://example.com/talk/\\", and not \\"example.com/talk\\""}
  """
  @spec url(term()) :: {:ok, String.t()} | {:error, String.t()}
  def url(value) when is_binary(value) do
    case URI.new(value) do
      {:ok, %URI{scheme: scheme, host: host}}
      when scheme in ["https", "http"] and is_binary(host) and host != "" ->
        {:ok, value}

      _other ->
        {:error, url_error(value)}
    end
  end

  def url(value), do: {:error, url_error(value)}

  defp url_error(value),
    do:
      "the url option must be an address that starts with https:// or http://, such as " <>
        "\"https://example.com/talk/\", and not #{inspect(value)}"

  @doc """
  Validate the `card` option: the path of a PNG or a JPEG file, or a keyword
  list with `image` and `alt`

      iex> Expresso.LinkPreview.card("card.png")
      {:ok, %{image: "card.png", alt: nil}}
      iex> Expresso.LinkPreview.card(image: "card.jpg", alt: "The title slide")
      {:ok, %{image: "card.jpg", alt: "The title slide"}}
      iex> {:error, message} = Expresso.LinkPreview.card("card.svg")
      iex> message =~ "a .png, .jpg or .jpeg file"
      true
  """
  @spec card(term()) :: {:ok, card()} | {:error, String.t()}
  def card(path) when is_binary(path), do: card(image: path)

  def card(%{image: image} = card) when is_binary(image), do: card(Map.to_list(card))

  def card(options) when is_list(options) do
    with true <- Keyword.keyword?(options),
         [] <- Keyword.keys(options) -- [:image, :alt],
         image when is_binary(image) <- options[:image],
         true <- Map.has_key?(@card_types, extension(image)),
         alt when is_binary(alt) or is_nil(alt) <- options[:alt] do
      {:ok, %{image: image, alt: alt}}
    else
      _other -> {:error, card_error(options)}
    end
  end

  def card(value), do: {:error, card_error(value)}

  defp card_error(value),
    do:
      "the card option must be the path of a .png, .jpg or .jpeg file, such as \"card.png\", " <>
        "or a list such as [image: \"card.png\", alt: \"The title slide\"], and not " <>
        inspect(value)

  @doc """
  Validate the `favicon` option: the path of an SVG, a PNG or an ICO file

      iex> Expresso.LinkPreview.favicon("icon.svg")
      {:ok, "icon.svg"}
      iex> Expresso.LinkPreview.favicon("icon.gif")
      {:error, "the favicon option must be the path of a .svg, .png or .ico file, and not \\"icon.gif\\""}
  """
  @spec favicon(term()) :: {:ok, Path.t()} | {:error, String.t()}
  def favicon(path) when is_binary(path) do
    if Map.has_key?(@icon_types, extension(path)),
      do: {:ok, path},
      else: {:error, favicon_error(path)}
  end

  def favicon(value), do: {:error, favicon_error(value)}

  defp favicon_error(value),
    do:
      "the favicon option must be the path of a .svg, .png or .ico file, and not #{inspect(value)}"

  @doc """
  Validate the `robots` option: the directives for a search engine

      iex> Expresso.LinkPreview.robots("noindex, nofollow")
      {:ok, "noindex, nofollow"}
      iex> Expresso.LinkPreview.robots("")
      {:error, "the robots option must be a text with a directive, such as \\"noindex\\", and not \\"\\""}
  """
  @spec robots(term()) :: {:ok, String.t()} | {:error, String.t()}
  def robots(value) when is_binary(value) do
    if String.trim(value) == "",
      do: {:error, robots_error(value)},
      else: {:ok, String.trim(value)}
  end

  def robots(value), do: {:error, robots_error(value)}

  defp robots_error(value),
    do:
      "the robots option must be a text with a directive, such as \"noindex\", and not #{inspect(value)}"

  @doc """
  Return the message for a deck with the `card` option and no `url` option

      iex> Expresso.LinkPreview.card_needs_url()
      "the card option needs the url option, because og:image holds an absolute address. " <>
        "Give the address of the deck, such as url \\"https://example.com/talk/\\", or remove the card option."
  """
  @spec card_needs_url() :: String.t()
  def card_needs_url,
    do:
      "the card option needs the url option, because og:image holds an absolute address. " <>
        "Give the address of the deck, such as url \"https://example.com/talk/\", or remove the card option."

  @doc """
  Join the relative path of a card or of an icon to the root of the deck

  `Expresso.PathTransformer` calls this function for the two options. `nil`
  stays as it is.
  """
  @spec put_root(card() | Path.t() | nil, Path.t()) :: card() | Path.t() | nil
  def put_root(nil, _root), do: nil
  def put_root(%{image: image} = card, root), do: %{card | image: Path.expand(image, root)}
  def put_root(path, root) when is_binary(path), do: Path.expand(path, root)

  @doc """
  Return the elements of the head for the options of a deck, in order

  `title` is the title of the document. A deck with none of the four options
  gets an empty list. The function reads the file of the card and of the icon
  through `Expresso.DeckFile`, and it raises for a file that it cannot read.
  It also raises for a card with no `url` option, and for a card in a render
  with no directory for the copy.
  """
  @spec tags(Deck.t(), String.t()) :: [tag()]
  def tags(%Deck{metadata: metadata}, title) do
    metadata = metadata || %{}
    url = metadata[:url]

    if metadata[:card] != nil and url == nil, do: raise(ArgumentError, card_needs_url())

    directives(metadata) ++ icon(metadata) ++ preview(metadata, url, title)
  end

  defp directives(%{robots: content}) when is_binary(content),
    do: [{:meta, name: "robots", content: content}]

  defp directives(_metadata), do: []

  defp icon(%{favicon: path}) when is_binary(path) do
    type = Map.fetch!(@icon_types, extension(path))
    bytes = Expresso.DeckFile.read!(path, "favicon")
    [{:link, rel: "icon", type: type, href: "data:#{type};base64," <> Base.encode64(bytes)}]
  end

  defp icon(_metadata), do: []

  defp preview(_metadata, nil, _title), do: []

  defp preview(metadata, url, title) do
    description =
      case one_line(metadata[:description]) do
        "" -> []
        text -> [property("og:description", text)]
      end

    [
      {:link, rel: "canonical", href: url},
      property("og:type", "website"),
      property("og:url", url),
      property("og:title", title)
    ] ++
      description ++
      locale(metadata[:lang]) ++
      picture(metadata[:card], url) ++
      [{:meta, name: "twitter:card", content: kind(metadata[:card])}]
  end

  defp property(name, content), do: {:meta, property: name, content: content}

  defp kind(nil), do: "summary"
  defp kind(_card), do: "summary_large_image"

  # Open Graph writes a locale as a language and a territory, such as
  # `pt_BR`. A language with no region gives no tag, because a program then
  # uses its default.
  defp locale(lang) when is_binary(lang) do
    case String.split(lang, "-") do
      [language, region] when byte_size(region) == 2 ->
        [property("og:locale", String.downcase(language) <> "_" <> String.upcase(region))]

      _other ->
        []
    end
  end

  defp locale(_lang), do: []

  defp picture(nil, _url), do: []

  defp picture(%{image: path, alt: alt}, url) do
    bytes = Expresso.DeckFile.read!(path, "card image")
    address = Expresso.MediaFiles.put(path, bytes, "card image", :card)

    size =
      case dimensions(bytes) do
        {width, height} ->
          [property("og:image:width", width), property("og:image:height", height)]

        nil ->
          []
      end

    [
      property("og:image", url |> URI.merge(address) |> URI.to_string()),
      property("og:image:type", Map.fetch!(@card_types, extension(path)))
    ] ++ size ++ if(alt in [nil, ""], do: [], else: [property("og:image:alt", alt)])
  end

  @doc """
  Return the width and the height of a PNG or a JPEG file in pixels, or `nil`

  The function reads the header of the file. It returns `nil` for bytes with
  no such header.

      iex> png = <<137, "PNG", 13, 10, 26, 10, 13::32, "IHDR", 1200::32, 630::32, 8, 2, 0, 0, 0>>
      iex> Expresso.LinkPreview.dimensions(png)
      {1200, 630}
      iex> Expresso.LinkPreview.dimensions("text")
      nil
  """
  @spec dimensions(binary()) :: {pos_integer(), pos_integer()} | nil
  def dimensions(
        <<137, "PNG", 13, 10, 26, 10, _length::32, "IHDR", width::32, height::32, _::binary>>
      ),
      do: {width, height}

  def dimensions(<<0xFF, 0xD8, rest::binary>>), do: jpeg(rest)
  def dimensions(_bytes), do: nil

  # A JPEG file is a sequence of segments. A segment of the kind "start of
  # frame" holds the height and the width. The markers C4, C8 and CC have a
  # number in that range, and they are not a start of frame.
  defp jpeg(<<0xFF, marker, _length::16, _precision, height::16, width::16, _::binary>>)
       when marker in 0xC0..0xCF and marker not in [0xC4, 0xC8, 0xCC],
       do: {width, height}

  defp jpeg(<<0xFF, 0xFF, rest::binary>>), do: jpeg(<<0xFF, rest::binary>>)

  defp jpeg(<<0xFF, _marker, length::16, rest::binary>>) when length >= 2 do
    case rest do
      <<_segment::binary-size(^length - 2), next::binary>> -> jpeg(next)
      _short -> nil
    end
  end

  defp jpeg(_bytes), do: nil

  defp one_line(nil), do: ""
  defp one_line(text), do: text |> String.split() |> Enum.join(" ")

  defp extension(path), do: path |> Path.extname() |> String.downcase()
end
