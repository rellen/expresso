defmodule Expresso.Color do
  @moduledoc """
  Calculates the contrast of two colors, and moves the lightness of a color

  A color is a `#rrggbb` string of sRGB. `contrast/2` returns the contrast ratio
  of WCAG 2.2, from 1 to 21. `blend/3` returns the color of a foreground with an
  opacity on a background, as a browser paints it. `adjust/3` makes a
  foreground lighter or darker until it has a contrast ratio with a background.
  It changes only the lightness of the color in OKLab, so the hue stays the same.
  `Expresso.Palette` uses these functions for the themes.
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
  at least `minimum`

  The function returns the color and the change of its lightness in OKLab, from
  0 to 1. A color that already has the contrast comes back with the change 0.
  The foreground becomes lighter on a dark background and darker on a light
  background. The function reduces the chroma only where a color with the new
  lightness is outside sRGB. It returns `:error` when no lightness gives the
  contrast.

      iex> Expresso.Color.adjust("#ffffff", "#000000", 4.5)
      {:ok, "#ffffff", 0.0}
  """
  @spec adjust(t(), t(), number()) :: {:ok, t(), float()} | :error
  def adjust(foreground, background, minimum) do
    if contrast(foreground, background) >= minimum do
      {:ok, foreground, 0.0}
    else
      {lightness, a, b} = oklab(foreground)
      direction = if elem(oklab(background), 0) < 0.5, do: 1, else: -1

      1..1000
      |> Stream.map(&(lightness + direction * &1 / 1000))
      |> Stream.take_while(&(&1 >= 0 and &1 <= 1))
      |> Stream.map(&{in_gamut(&1, a, b), abs(&1 - lightness)})
      |> Enum.find(fn {color, _change} -> contrast(color, background) >= minimum end)
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
