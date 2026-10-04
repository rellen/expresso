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

  # The transfer function of sRGB, from IEC 61966-2-1. A channel at or under
  # the threshold is on a straight line, and a channel over it is on a power
  # curve. `@srgb_encoded_threshold` is the same point on the encoded side.
  @srgb_threshold 0.0031308
  @srgb_encoded_threshold 0.04045
  @srgb_slope 12.92
  @srgb_offset 0.055
  @srgb_gamma 2.4

  # The relative luminance of WCAG 2.2: the weight of each linear channel, and
  # the flare that the contrast ratio adds to each luminance.
  @wcag_weights {0.2126, 0.7152, 0.0722}
  @wcag_flare 0.05

  # The constants of APCA-W3 version 0.0.98G-4g, from
  # https://github.com/Myndex/apca-w3. APCA uses a simple power for each
  # channel, with its own weights.
  @apca_gamma 2.4
  @apca_weights {0.2126729, 0.7151522, 0.0721750}
  # A luminance under the threshold gets a soft clamp, for the flare of a
  # screen near black.
  @apca_black_threshold 0.022
  @apca_black_clamp 1.414
  # Two luminances closer than this value have no contrast.
  @apca_delta_min 0.0005
  # The exponents of the background and of the text. "Normal" is dark text on
  # a light background, and "reverse" is light text on a dark background.
  @apca_normal {0.56, 0.57}
  @apca_reverse {0.65, 0.62}
  # The scale of the result, the clip of a very low contrast, and the offset
  # that APCA removes from each result.
  @apca_scale 1.14
  @apca_low_clip 0.1
  @apca_offset 0.027

  # `adjust/4` moves the lightness in steps of 1/1000 of OKLab, and it reduces
  # the chroma in steps of 1/50 when a color is outside sRGB. A background with
  # a lightness under the midpoint is dark.
  @lightness_steps 1000
  @chroma_steps 50
  @lightness_midpoint 0.5
  # A linear channel can go this far past 0 or 1 from the rounding of floats.
  @gamut_tolerance 1.0e-9

  # The matrices of OKLab, from https://bottosson.github.io/posts/oklab/. The
  # first two go from linear sRGB to the cone responses LMS and from LMS to
  # OKLab. The last two go back.
  @lms_from_linear {{0.4122214708, 0.5363325363, 0.0514459929},
                    {0.2119034982, 0.6806995451, 0.1073969566},
                    {0.0883024619, 0.2817188376, 0.6299787005}}
  @oklab_from_lms {{0.2104542553, 0.7936177850, -0.0040720468},
                   {1.9779984951, -2.4285922050, 0.4505937099},
                   {0.0259040371, 0.7827717662, -0.8086757660}}
  @lms_from_oklab {{1.0, 0.3963377774, 0.2158037573}, {1.0, -0.1055613458, -0.0638541728},
                   {1.0, -0.0894841775, -1.2914855480}}
  @linear_from_lms {{4.0767416621, -3.3077115913, 0.2309699292},
                    {-1.2684380046, 2.6097574011, -0.3413193965},
                    {-0.0041960863, -0.7034186147, 1.7076147010}}

  @doc """
  Return the contrast ratio of two colors, as WCAG 2.2 defines it

  The ratio is `(L1 + 0.05) / (L2 + 0.05)`, where `L1` is the relative
  luminance of the lighter color and `L2` the luminance of the darker color.
  The order of the arguments is not important.

      iex> Expresso.Color.contrast("#000000", "#ffffff")
      21.0

      iex> Float.round(Expresso.Color.contrast("#777777", "#ffffff"), 2)
      4.48
  """
  @spec contrast(t(), t()) :: float()
  def contrast(first, second) do
    [high, low] = Enum.sort([luminance(first), luminance(second)], :desc)
    (high + @wcag_flare) / (low + @wcag_flare)
  end

  @doc """
  Return the lightness contrast `Lc` of a text on a background, as APCA defines it

  The function uses the constants of APCA-W3 version 0.0.98G-4g. APCA gives a
  negative value for light text on a dark background. This function returns
  the absolute value, so a larger value is always more contrast. The order of
  the arguments is important: the first color is the text.

  APCA raises each luminance to a different power for the text and for the
  background, and the powers depend on which color is lighter. Thus the
  same two colors give a different value when they change places, and a dark
  background gives less contrast than the contrast ratio of WCAG says.
  `docs/architecture.md` gives the formula.

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
      abs(y_background - y_text) < @apca_delta_min ->
        0.0

      y_background > y_text ->
        {background_exponent, text_exponent} = @apca_normal

        scaled =
          (:math.pow(y_background, background_exponent) - :math.pow(y_text, text_exponent)) *
            @apca_scale

        if scaled < @apca_low_clip, do: 0.0, else: (scaled - @apca_offset) * 100

      true ->
        {background_exponent, text_exponent} = @apca_reverse

        scaled =
          (:math.pow(y_background, background_exponent) - :math.pow(y_text, text_exponent)) *
            @apca_scale

        if scaled > -@apca_low_clip, do: 0.0, else: -(scaled + @apca_offset) * 100
    end
  end

  # The luminance of APCA: a simple power of each channel, with a soft clamp
  # near black for the flare of a screen.
  defp screen_luminance(color) do
    channels = color |> rgb() |> Enum.map(&:math.pow(&1, @apca_gamma))
    y = weigh(@apca_weights, channels)

    if y < @apca_black_threshold,
      do: y + :math.pow(@apca_black_threshold - y, @apca_black_clamp),
      else: y
  end

  @doc """
  Return the relative luminance of a color, from 0 for black to 1 for white
  """
  @spec luminance(t()) :: float()
  def luminance(color), do: weigh(@wcag_weights, color |> rgb() |> Enum.map(&linear/1))

  @doc """
  Return the color of a foreground with an opacity from 0 to 1 on a background

  Each channel is `opacity * foreground + (1 - opacity) * background`, on the
  encoded values of sRGB. A browser composites an element with a filter in
  this way.

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
  background, in steps of 0.001. The function reduces the chroma only where a
  color with the new lightness is outside sRGB. It returns `:error` when no
  lightness gives the contrast.

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
      direction = if elem(oklab(background), 0) < @lightness_midpoint, do: 1, else: -1

      1..@lightness_steps
      |> Stream.map(&(lightness + direction * &1 / @lightness_steps))
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
    0..@chroma_steps
    |> Stream.map(&(1 - &1 / @chroma_steps))
    |> Stream.map(&from_oklab(lightness, a * &1, b * &1))
    |> Enum.find(fn channels ->
      Enum.all?(channels, &(&1 >= -@gamut_tolerance and &1 <= 1 + @gamut_tolerance))
    end)
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

  defp linear(c) when c <= @srgb_encoded_threshold, do: c / @srgb_slope
  defp linear(c), do: :math.pow((c + @srgb_offset) / (1 + @srgb_offset), @srgb_gamma)

  defp gamma(c) when c <= @srgb_threshold, do: @srgb_slope * c
  defp gamma(c), do: (1 + @srgb_offset) * :math.pow(c, 1 / @srgb_gamma) - @srgb_offset

  # The sum of three channels, each multiplied by its weight.
  defp weigh({w1, w2, w3}, [c1, c2, c3]), do: w1 * c1 + w2 * c2 + w3 * c3

  # The product of a 3 × 3 matrix and a vector of three values.
  defp multiply({row1, row2, row3}, vector),
    do: [weigh(row1, vector), weigh(row2, vector), weigh(row3, vector)]

  defp oklab(color) do
    linear = color |> rgb() |> Enum.map(&linear/1)
    lms = @lms_from_linear |> multiply(linear) |> Enum.map(&:math.pow(&1, 1 / 3))
    [lightness, a, b] = multiply(@oklab_from_lms, lms)
    {lightness, a, b}
  end

  defp from_oklab(lightness, a, b) do
    lms = @lms_from_oklab |> multiply([lightness, a, b]) |> Enum.map(&:math.pow(&1, 3))

    @linear_from_lms
    |> multiply(lms)
    |> Enum.map(fn c -> if c > 0, do: gamma(c), else: c end)
  end
end
