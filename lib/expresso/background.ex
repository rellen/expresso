defmodule Expresso.Background do
  @moduledoc """
  The background of a slide: an image, a color or a gradient behind its content

  The `background` option of a slide and of a deck takes one of these values:

  | Value | Background |
  | --- | --- |
  | `"photo.jpg"` | The image of the file, which covers the slide |
  | `[image: "photo.jpg", fit: :contain, position: "center top", dim: 0.4]` | The image, with its fit, its position and a dim layer |
  | `[color: :accent]` or `[color: "#102030"]` | One color: a role of the theme or a hex color |
  | `[gradient: [:accent, :background], angle: 135]` | A gradient of two or more colors |
  | `:none` | No background. A slide gives it to turn off the background of the deck. |

  `option/1` makes a struct of this module from the value. The option of the
  deck gives the background of each slide that has no option of its own, and
  `of/2` returns the background of one slide.

  The renderer writes the background as the first element of the slide, with
  the class `slide-background`. An image is an `img` element with a data URI,
  as for `Expresso.Element.Image`, so `Expresso.Assets.dedupe/1` keeps one
  copy of the file for the copies of the slide. `docs/slide-backgrounds.md`
  gives the design.
  """

  alias Expresso.Palette

  @typedoc "A color of a background: a role of the theme, or a hex color"
  @type color :: atom() | String.t()

  @typedoc """
  The background of a slide

  `kind` tells which of `image`, `color` and `gradient` holds the value.
  `dim` is the opacity of the dim layer, from 0 to 1, and 0 gives no layer.
  """
  @type t :: %__MODULE__{
          kind: :image | :color | :gradient,
          image: Path.t() | nil,
          fit: :cover | :contain,
          position: String.t(),
          color: color() | nil,
          gradient: [color()] | nil,
          angle: number(),
          dim: number()
        }

  @enforce_keys [:kind]
  defstruct [
    :kind,
    :image,
    :color,
    :gradient,
    fit: :cover,
    position: "center",
    angle: 180,
    dim: 0
  ]

  @kinds [:image, :color, :gradient]
  @keys @kinds ++ [:fit, :position, :dim, :angle]

  # A position of CSS: one or two of the keywords and the percentages.
  @place "(left|center|right|top|bottom|\\d+(\\.\\d+)?%)"
  @position Regex.compile!("\\A#{@place}( #{@place})?\\z")

  @hex ~r/\A#([0-9a-fA-F]{3}|[0-9a-fA-F]{6})\z/

  @doc """
  Validate the value of the `background` option, and make its struct

  The function returns `:none` for `:none`.

      iex> Expresso.Background.option("photo.jpg")
      {:ok, %Expresso.Background{kind: :image, image: "photo.jpg"}}

      iex> Expresso.Background.option(color: :accent, dim: 0.2)
      {:ok, %Expresso.Background{kind: :color, color: :accent, dim: 0.2}}

      iex> Expresso.Background.option(gradient: [:accent, "#102030"], angle: 135)
      {:ok, %Expresso.Background{kind: :gradient, gradient: [:accent, "#102030"], angle: 135}}

      iex> Expresso.Background.option(:none)
      {:ok, :none}

      iex> Expresso.Background.option(color: :pink)
      {:error, "the color :pink of the background option is not a role of the theme or a hex color, such as :accent or \\"#102030\\""}
  """
  @spec option(term()) :: {:ok, t() | :none} | {:error, String.t()}
  def option(:none), do: {:ok, :none}
  def option(%__MODULE__{} = background), do: {:ok, background}
  def option(path) when is_binary(path) and path != "", do: option(image: path)

  def option(value) when is_list(value) and value != [] do
    with true <- Keyword.keyword?(value) || :not_keyword,
         :ok <- known(value),
         {:ok, kind} <- kind(value),
         :ok <- allowed(kind, value),
         :ok <- valid(value) do
      {:ok, struct!(__MODULE__, [kind: kind] ++ value)}
    else
      :not_keyword -> {:error, form(value)}
      {:error, message} -> {:error, message}
    end
  end

  def option(value), do: {:error, form(value)}

  defp form(value) do
    "the background option must be the path of an image, :none, or a keyword list with " <>
      "image, color or gradient, such as [image: \"photo.jpg\", dim: 0.4], and not " <>
      inspect(value)
  end

  defp known(value) do
    case Keyword.keys(value) -- @keys do
      [] ->
        :ok

      [key | _rest] ->
        {:error,
         "the background option does not know the key #{inspect(key)}. The keys are " <>
           "image, color, gradient, fit, position, dim and angle"}
    end
  end

  defp kind(value) do
    case Enum.filter(@kinds, &Keyword.has_key?(value, &1)) do
      [kind] ->
        {:ok, kind}

      _none_or_many ->
        {:error,
         "the background option needs exactly one of image, color and gradient, and not " <>
           inspect(value)}
    end
  end

  # `fit` and `position` are for an image, and `angle` is for a gradient.
  defp allowed(kind, value) do
    wrong =
      Enum.find([fit: :image, position: :image, angle: :gradient], fn {key, owner} ->
        Keyword.has_key?(value, key) and kind != owner
      end)

    case wrong do
      nil ->
        :ok

      {key, owner} ->
        {:error,
         "the key #{key} of the background option is for a background with #{owner}, " <>
           "and this background has #{kind}"}
    end
  end

  defp valid(value) do
    Enum.reduce_while(value, :ok, fn pair, :ok ->
      case check(pair) do
        :ok -> {:cont, :ok}
        {:error, message} -> {:halt, {:error, message}}
      end
    end)
  end

  defp check({:image, path}) when is_binary(path) and path != "", do: :ok

  defp check({:image, path}),
    do: {:error, "the image of the background option must be a path, and not #{inspect(path)}"}

  defp check({:color, color}), do: color(color)

  defp check({:gradient, [_, _ | _] = colors}) when is_list(colors) do
    Enum.find_value(colors, :ok, fn color ->
      case color(color) do
        :ok -> nil
        error -> error
      end
    end)
  end

  defp check({:gradient, colors}) do
    {:error,
     "the gradient of the background option must be a list of two colors or more, such " <>
       "as [:accent, :background], and not #{inspect(colors)}"}
  end

  defp check({:fit, fit}) when fit in [:cover, :contain], do: :ok

  defp check({:fit, fit}),
    do:
      {:error,
       "the fit of the background option must be :cover or :contain, and not #{inspect(fit)}"}

  defp check({:position, position}) do
    if is_binary(position) and position =~ @position do
      :ok
    else
      {:error,
       "the position of the background option must be one or two of left, center, right, " <>
         "top, bottom and a percentage, such as \"center top\", and not #{inspect(position)}"}
    end
  end

  defp check({:dim, dim}) when is_number(dim) and dim >= 0 and dim <= 1, do: :ok

  defp check({:dim, dim}),
    do:
      {:error,
       "the dim of the background option must be a number from 0 to 1, such as 0.4, and not #{inspect(dim)}"}

  defp check({:angle, angle}) when is_number(angle), do: :ok

  defp check({:angle, angle}),
    do:
      {:error,
       "the angle of the background option must be a number of degrees, such as 135, and not #{inspect(angle)}"}

  defp color(color) do
    if role?(color) or (is_binary(color) and color =~ @hex) do
      :ok
    else
      {:error,
       "the color #{inspect(color)} of the background option is not a role of the theme or " <>
         "a hex color, such as :accent or \"#102030\""}
    end
  end

  defp role?(color), do: is_atom(color) and Keyword.has_key?(Palette.roles(), color)

  @doc """
  Return the background of a slide, or `nil`

  The option of the slide comes first, then the option of the deck. A slide
  with `:none` has no background.
  """
  @spec of(Expresso.Deck.t(), Expresso.Slide.t()) :: t() | nil
  def of(deck, slide) do
    case (slide.metadata || %{})[:background] || (deck.metadata || %{})[:background] do
      %__MODULE__{} = background -> background
      _none -> nil
    end
  end

  @doc """
  Join a relative path of the image of a background to the root of the deck

  `Expresso.PathTransformer` calls this function for the option of the deck
  and of each slide. A background with no image, `:none` and `nil` stay as
  they are.
  """
  @spec put_root(t() | :none | nil, Path.t() | nil) :: t() | :none | nil
  def put_root(%__MODULE__{kind: :image, image: image} = background, root) when is_binary(root),
    do: %{background | image: Path.expand(image, root)}

  def put_root(background, _root), do: background

  @doc """
  Return the declarations of the layer of a color or of a gradient

      iex> {:ok, background} = Expresso.Background.option(color: :code_background)
      iex> Expresso.Background.fill(background)
      "background-color: var(--code-background);"

      iex> {:ok, background} = Expresso.Background.option(gradient: [:accent, "#102030"], angle: 135)
      iex> Expresso.Background.fill(background)
      "background-image: linear-gradient(135deg, var(--accent), #102030);"
  """
  @spec fill(t()) :: String.t()
  def fill(%__MODULE__{kind: :color, color: color}), do: "background-color: #{css(color)};"

  def fill(%__MODULE__{kind: :gradient, gradient: colors, angle: angle}),
    do: "background-image: linear-gradient(#{angle}deg, #{Enum.map_join(colors, ", ", &css/1)});"

  @doc """
  Return the declarations of the `img` element of an image

      iex> {:ok, background} = Expresso.Background.option(image: "a.png", position: "center top")
      iex> Expresso.Background.fit(background)
      "object-fit: cover; object-position: center top;"
  """
  @spec fit(t()) :: String.t()
  def fit(%__MODULE__{kind: :image, fit: fit, position: position}),
    do: "object-fit: #{fit}; object-position: #{position};"

  # A role becomes its custom property. A hex color stays as it is, and
  # `option/1` lets no other text through.
  defp css(color) when is_atom(color),
    do: "var(--#{color |> Atom.to_string() |> String.replace("_", "-")})"

  defp css(color), do: color
end
