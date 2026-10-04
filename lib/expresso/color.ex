defmodule Expresso.Color do
  @moduledoc """
  Calculates the contrast of two colors, and moves the lightness of a color

  A color is a `#rrggbb` string of sRGB. `contrast/2` returns the contrast ratio
  of WCAG 2.2, from 1 to 21. `lightness_contrast/2` returns the lightness
  contrast `Lc` of APCA, from 0 to about 108. `blend/3` returns the color of a
  foreground with an opacity on a background, as a browser paints it.
  `adjust/4` makes a foreground lighter or darker until it has a contrast ratio
  and a lightness contrast with a background. It changes only the lightness of
  the color in OKLab, so the hue stays the same. `Expresso.Palette` uses these
  functions for the themes.
  """

  @typedoc "A color as `#rrggbb`"
  @type t :: String.t()

  @doc """
  Return the contrast ratio of two colors, as WCAG 2.2 defines it

      iex> Expresso.Color.contrast("#000000", "#ffffff")
      21.0

      iex> Float.round(Expresso.Color.contrast("#777777", "#ffffff"), 2)
      4.48
  """
  @spec contrast(t(), t()) :: float()
  def contrast(first, second) do
    [high, low] = Enum.sort([luminance(first), luminance(second)], :desc)
    (high + 0.05) / (low + 0.05)
  end

  @doc """
  Return the lightness contrast `Lc` of a text on a background, as APCA defines it

  The function uses the constants of APCA-W3 version 0.0.98G-4g. APCA gives a
  negative value for light text on a dark background. This function returns
  the absolute value, so a larger value is always more contrast. The order of
  the arguments is important: the first color is the text.

      iex> Float.round(Expresso.Color.lightness_contrast("#000000", "#ffffff"), 1)
      106.0

      iex> Float.round(Expresso.Color.lightness_contrast("#ffffff", "#000000"), 1)
      107.9

      iex> Float.round(Expresso.Color.lightness_contrast("#888888", "#ffffff"), 1)
      63.1
  """
  @spec lightness_contrast(t(), t()) :: float()
  def lightness_contrast(text, background) do
    y_text = screen_luminance(text)
    y_background = screen_luminance(background)

    cond do
      abs(y_background - y_text) < 0.0005 ->
        0.0

      y_background > y_text ->
        scaled = (:math.pow(y_background, 0.56) - :math.pow(y_text, 0.57)) * 1.14
        if scaled < 0.1, do: 0.0, else: (scaled - 0.027) * 100

      true ->
        scaled = (:math.pow(y_background, 0.65) - :math.pow(y_text, 0.62)) * 1.14
        if scaled > -0.1, do: 0.0, else: -(scaled + 0.027) * 100
    end
  end

  # The luminance of APCA: a simple power of each channel, with a soft clamp
  # near black for the flare of a screen.
  defp screen_luminance(color) do
    [r, g, b] = color |> rgb() |> Enum.map(&:math.pow(&1, 2.4))
    y = 0.2126729 * r + 0.7151522 * g + 0.0721750 * b
    if y < 0.022, do: y + :math.pow(0.022 - y, 1.414), else: y
  end

  @doc """
  Return the relative luminance of a color, from 0 for black to 1 for white
  """
  @spec luminance(t()) :: float()
  def luminance(color) do
    [r, g, b] = color |> rgb() |> Enum.map(&linear/1)
    0.2126 * r + 0.7152 * g + 0.0722 * b
  end

  @doc """
  Return the color of a foreground with an opacity from 0 to 1 on a background

      iex> Expresso.Color.blend("#000000", "#ffffff", 0.5)
      "#808080"
  """
  @spec blend(t(), t(), float()) :: t()
  def blend(foreground, background, opacity) do
    rgb(foreground)
    |> Enum.zip(rgb(background))
    |> Enum.map(fn {f, b} -> opacity * f + (1 - opacity) * b end)
    |> hex()
  end

  @doc """
  Make a foreground lighter or darker until its contrast with the background is
  at least `minimum`, and its lightness contrast is at least `lc`

  `minimum` is a contrast ratio of WCAG, and `lc` is an absolute value of APCA.
  The default `lc` of 0 asks only for the contrast ratio.

  The function returns the color and the change of its lightness in OKLab, from
  0 to 1. A color that already has the contrast comes back with the change 0.
  The foreground becomes lighter on a dark background and darker on a light
  background. The function reduces the chroma only where a color with the new
  lightness is outside sRGB. It returns `:error` when no lightness gives the
  contrast.

      iex> Expresso.Color.adjust("#ffffff", "#000000", 4.5)
      {:ok, "#ffffff", 0.0}
  """
  @spec adjust(t(), t(), number(), number()) :: {:ok, t(), float()} | :error
  def adjust(foreground, background, minimum, lc \\ 0) do
    meets = &(contrast(&1, background) >= minimum and lightness_contrast(&1, background) >= lc)

    if meets.(foreground) do
      {:ok, foreground, 0.0}
    else
      {lightness, a, b} = oklab(foreground)
      direction = if elem(oklab(background), 0) < 0.5, do: 1, else: -1

      1..1000
      |> Stream.map(&(lightness + direction * &1 / 1000))
      |> Stream.take_while(&(&1 >= 0 and &1 <= 1))
      |> Stream.map(&{in_gamut(&1, a, b), abs(&1 - lightness)})
      |> Enum.find(fn {color, _change} -> meets.(color) end)
      |> case do
        {color, change} -> {:ok, color, change}
        nil -> :error
      end
    end
  end

  # The color with a lightness and the largest part of the chroma `a`, `b` that
  # sRGB can show, rounded to `#rrggbb`.
  defp in_gamut(lightness, a, b) do
    0..50
    |> Stream.map(&(1 - &1 / 50))
    |> Stream.map(&from_oklab(lightness, a * &1, b * &1))
    |> Enum.find(fn channels -> Enum.all?(channels, &(&1 >= -1.0e-9 and &1 <= 1 + 1.0e-9)) end)
    |> hex()
  end

  defp rgb("#" <> <<r::binary-2, g::binary-2, b::binary-2>>),
    do: Enum.map([r, g, b], &(String.to_integer(&1, 16) / 255))

  defp hex(channels) do
    "#" <>
      Enum.map_join(channels, fn c ->
        c
        |> max(0.0)
        |> min(1.0)
        |> Kernel.*(255)
        |> round()
        |> Integer.to_string(16)
        |> String.pad_leading(2, "0")
        |> String.downcase()
      end)
  end

  defp linear(c) when c <= 0.04045, do: c / 12.92
  defp linear(c), do: :math.pow((c + 0.055) / 1.055, 2.4)

  defp gamma(c) when c <= 0.0031308, do: 12.92 * c
  defp gamma(c), do: 1.055 * :math.pow(c, 1 / 2.4) - 0.055

  # The conversion of OKLab, from https://bottosson.github.io/posts/oklab/.
  defp oklab(color) do
    [r, g, b] = color |> rgb() |> Enum.map(&linear/1)
    l = :math.pow(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b, 1 / 3)
    m = :math.pow(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b, 1 / 3)
    s = :math.pow(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b, 1 / 3)

    {0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s}
  end

  defp from_oklab(lightness, a, b) do
    l = :math.pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
    m = :math.pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
    s = :math.pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)

    [
      4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
      -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
      -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
    ]
    |> Enum.map(fn c -> if c > 0, do: gamma(c), else: c end)
  end
end
