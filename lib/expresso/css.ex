defmodule Expresso.Css do
  @moduledoc """
  The CSS of a deck, and the names in a style sheet

  The `css` option of a deck holds a style sheet, or the path of a file that
  holds one. `resolve/1` gives the style sheet. The renderer puts it into the
  document after the theme and after the generated rules, so a rule of the
  deck can replace each rule of the theme.

  The document is one file, so `render/2` also puts each local file of a
  `url()`, such as a font or an image, into the style sheet as a data URI. A
  `url()` resolves as in a browser: in a file, from the directory of the file,
  and in a style sheet of the option itself, from the `root` option of the
  deck or from the working directory.

  `scan/1` gives the names of a style sheet that the compiler checks: the
  custom properties that it uses, declares and registers, and the effects
  that it gives a rule. `Expresso.Theme` scans the theme in the same way, and
  the verifiers join the two results.
  """

  alias Shoddy.Result

  @typedoc "The names of a style sheet"
  @type names :: %{
          used: MapSet.t(String.t()),
          declared: MapSet.t(String.t()),
          registered: %{String.t() => String.t()},
          effects: MapSet.t(String.t())
        }

  @doc """
  Give the style sheet of a `css` option

  A value with a brace or a line break is a style sheet. A different value is
  the path of a file, relative to the working directory of the command, as the
  path of an image is. `Expresso.PathTransformer` joins the path to the `root`
  option of the deck. `nil` gives an empty style sheet.
  """
  @spec resolve(String.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def resolve(nil), do: {:ok, ""}

  def resolve(css) when is_binary(css) do
    if inline?(css), do: {:ok, css}, else: read(css)
  end

  # The media types of the files that a `url()` can name: the images of
  # `Expresso.Image`, and the fonts.
  @fonts %{
    ".otf" => "font/otf",
    ".ttf" => "font/ttf",
    ".woff" => "font/woff",
    ".woff2" => "font/woff2"
  }

  @extensions @fonts
              |> Map.keys()
              |> Enum.concat(Expresso.Image.extensions())
              |> Enum.sort()
              |> Enum.join(", ")

  # A `url()` with a quoted or an unquoted value.
  @url ~r/url\(\s*(?:"([^"]*)"|'([^']*)'|([^)"'\s]+))\s*\)/

  @doc """
  Give the style sheet of a `css` option, with each local file of a `url()` as a data URI

  `root` is the `root` option of the deck, or `nil`. A `url()` of a file
  resolves from the directory of the file. A `url()` of a style sheet in the
  option resolves from `root`, or from the working directory without it. An
  address, such as `https://example.com/font.woff2`, a `data:` URI and a
  fragment, such as `#shadow`, stay as they are.
  """
  @spec render(String.t() | nil, Path.t() | nil) :: {:ok, String.t()} | {:error, String.t()}
  def render(css, root) do
    with {:ok, text} <- resolve(css), do: embed(text, base(css, root))
  end

  defp base(css, root) do
    cond do
      css != nil and not inline?(css) -> Path.dirname(css)
      root != nil -> root
      true -> "."
    end
  end

  @doc """
  Put each local file of a `url()` into a style sheet as a data URI

  `base` is the directory that a relative path starts from. A query or a
  fragment of the path, such as `font.woff2?v=2`, is not part of the file
  name. The function gives an error tuple for a file that it cannot read, and
  for a file of a type that it does not know.

      iex> Expresso.Css.embed("a { background: url(#shadow); }", ".")
      {:ok, "a { background: url(#shadow); }"}
  """
  @spec embed(String.t(), Path.t()) :: {:ok, String.t()} | {:error, String.t()}
  def embed(css, base) do
    @url
    |> Regex.split(css, include_captures: true)
    |> Enum.map(&part(&1, base))
    |> Result.collect()
    |> Result.map_ok(&IO.iodata_to_binary/1)
  end

  # A part of the split is a `url()` or the text between two of them.
  defp part(text, base) do
    case Regex.run(@url, text, capture: :all_but_first) do
      nil ->
        {:ok, text}

      groups ->
        case url(Enum.find(groups, "", &(&1 != "")), base) do
          {:ok, nil} -> {:ok, text}
          {:ok, uri} -> {:ok, "url(\"" <> uri <> "\")"}
          {:error, message} -> {:error, message}
        end
    end
  end

  # The data URI of a local file, or `nil` for a value that names no local file.
  defp url(value, base) do
    if Regex.match?(~r/\A(?:[a-zA-Z][a-zA-Z0-9+.-]*:|\/\/|#)/, value) or value == "" do
      {:ok, nil}
    else
      [name | _rest] = String.split(value, ["?", "#"], parts: 2)
      fragment = fragment(value)
      path = Path.expand(name, base)

      with {:ok, media_type} <- media_type(path),
           {:ok, bytes} <- read_url(path) do
        {:ok, "data:#{media_type};base64,#{Base.encode64(bytes)}#{fragment}"}
      end
    end
  end

  # A fragment, such as `#icon` of `icons.svg#icon`, names a part of the file.
  defp fragment(value) do
    case String.split(value, "#", parts: 2) do
      [_name, fragment] -> "#" <> fragment
      [_name] -> ""
    end
  end

  defp media_type(path) do
    case Map.fetch(@fonts, path |> Path.extname() |> String.downcase()) do
      {:ok, media_type} ->
        {:ok, media_type}

      :error ->
        case Expresso.Image.media_type(path) do
          {:ok, media_type} ->
            {:ok, media_type}

          {:error, _message} ->
            {:error,
             "the url() #{inspect(path)} of the CSS is not a font or an image of a type that " <>
               "Expresso knows: expected one of #{@extensions}"}
        end
    end
  end

  defp read_url(path) do
    case Expresso.DeckFile.read(path) do
      {:ok, bytes} ->
        {:ok, bytes}

      {:error, reason} ->
        {:error, "cannot read the file \"#{path}\" of a url() of the CSS: #{reason}"}
    end
  end

  @doc """
  Tell whether a `css` option is a style sheet, and not a path
  """
  @spec inline?(String.t()) :: boolean()
  def inline?(css), do: String.contains?(css, ["{", "\n"])

  defp read(path) do
    case Expresso.DeckFile.read(path) do
      {:ok, css} -> {:ok, css}
      {:error, reason} -> {:error, "cannot read the CSS file \"#{path}\": #{reason}"}
    end
  end

  @doc """
  Make a style sheet safe for a `style` element

  The text `</` can close the `style` element. The function writes `<\\/`,
  which CSS reads as the same two characters in a string, a comment or a URL.
  """
  @spec escape(String.t()) :: String.t()
  def escape(css), do: String.replace(css, "</", "<\\/")

  @doc """
  Give the names of a style sheet

  - `used` holds each name after two hyphens. CSS reads a custom property
    with `var()` only, and it writes one in a declaration or in an
    `@property` rule. Each of the three forms holds the name after two
    hyphens.
  - `declared` holds each custom property that the style sheet gives a value
    that is not a number, such as `--dur: 300ms`.
  - `registered` gives the `syntax` descriptor of each `@property` rule.
  - `effects` holds each effect with a rule for `[data-effect="..."]`, with
    underscores, as the deck writes the atom. The names stay strings, because
    a style sheet of a deck must not make atoms.
  """
  @spec scan(String.t()) :: names()
  def scan(css) do
    %{
      used: used(css),
      declared: non_number_declarations(css),
      registered: property_syntaxes(css),
      effects: effects(css)
    }
  end

  @doc """
  Join the names of two style sheets
  """
  @spec merge(names(), names()) :: names()
  def merge(a, b) do
    %{
      used: MapSet.union(a.used, b.used),
      declared: MapSet.union(a.declared, b.declared),
      registered: Map.merge(a.registered, b.registered),
      effects: MapSet.union(a.effects, b.effects)
    }
  end

  defp used(css) do
    ~r/--([\w-]+)/ |> Regex.scan(css, capture: :all_but_first) |> List.flatten() |> MapSet.new()
  end

  defp non_number_declarations(css) do
    for [name, value] <-
          Regex.scan(~r/--([\w-]+)\s*:\s*([^;}]*)/, css, capture: :all_but_first),
        not Regex.match?(~r/^-?\d+(\.\d+)?$/, String.trim(value)),
        into: MapSet.new(),
        do: name
  end

  defp property_syntaxes(css) do
    for [name, body] <-
          Regex.scan(~r/@property\s+--([\w-]+)\s*\{([^}]*)\}/, css, capture: :all_but_first),
        descriptor = Regex.run(~r/syntax:\s*"([^"]*)"/, body, capture: :all_but_first),
        into: %{},
        do: {name, hd(descriptor)}
  end

  defp effects(css) do
    for [name] <- Regex.scan(~r/\[data-effect="([\w-]+)"\]/, css, capture: :all_but_first),
        into: MapSet.new(),
        do: String.replace(name, "-", "_")
  end
end
