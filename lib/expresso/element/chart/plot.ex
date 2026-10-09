defmodule Expresso.Element.Chart.Plot do
  @moduledoc """
  The arithmetic of a chart: the ticks of the axis, the numbers and the paths

  Each function takes numbers and returns numbers or the text of a path, so
  the tests need no render. The chart draws in a box of 800 by 450 units, and
  the SVG scales that box to the width of the element.
  """

  @doc """
  Return the ticks of an axis that holds each value and zero

  The step is 1, 2, 2.5 or 5 times a power of ten, so the ticks are round
  numbers. The axis has approximately five ticks.

      iex> Expresso.Element.Chart.Plot.ticks([120, 180, 240])
      [0, 50, 100, 150, 200, 250]

      iex> Expresso.Element.Chart.Plot.ticks([-3, 7])
      [-4, -2, 0, 2, 4, 6, 8]

      iex> Expresso.Element.Chart.Plot.ticks([0, 0])
      [0, 1]
  """
  @spec ticks([number()]) :: [number()]
  def ticks(values) do
    low = min(Enum.min(values), 0)
    high = max(Enum.max(values), 0)

    if low == high do
      [0, 1]
    else
      step = step((high - low) / 5)
      first = Float.floor(low / step) |> trunc()
      last = Float.ceil(high / step) |> trunc()
      for n <- first..last, do: number(n * step)
    end
  end

  defp step(rough) do
    power = :math.pow(10, Float.floor(:math.log10(rough)))

    factor =
      Enum.find([1, 2, 2.5, 5, 10], fn factor -> rough <= factor * power end)

    factor * power
  end

  @doc """
  Return a number as an integer when it has no fraction, and with no error of
  the floating point

      iex> Expresso.Element.Chart.Plot.number(250.0)
      250
      iex> Expresso.Element.Chart.Plot.number(0.30000000000000004)
      0.3
  """
  @spec number(number()) :: number()
  def number(value) when is_integer(value), do: value

  def number(value) do
    rounded = Float.round(value, 6)
    if rounded == trunc(rounded), do: trunc(rounded), else: rounded
  end

  @doc """
  Write a number for a label of a chart

      iex> Expresso.Element.Chart.Plot.label(1250)
      "1250"
      iex> Expresso.Element.Chart.Plot.label(2.5)
      "2.5"
  """
  @spec label(number()) :: String.t()
  def label(value) do
    case number(value) do
      integer when is_integer(integer) -> Integer.to_string(integer)
      float -> :erlang.float_to_binary(float, [:short])
    end
  end

  @doc """
  Return the path of a bar from the base line to a value line, with round
  corners at the end of the value

  A bar of a negative value goes down, and its round corners are at the
  bottom. The radius is 4 units, or less for a narrow or a short bar.

      iex> Expresso.Element.Chart.Plot.bar(10, 20, 100, 60)
      "M10 100V64Q10 60 14 60H26Q30 60 30 64V100Z"
  """
  @spec bar(number(), number(), number(), number()) :: String.t()
  def bar(x, width, base, top) do
    height = abs(base - top)
    radius = Enum.min([4, width / 2, height])
    right = x + width
    direction = if top <= base, do: 1, else: -1
    corner = top + direction * radius

    "M#{f(x)} #{f(base)}V#{f(corner)}Q#{f(x)} #{f(top)} #{f(x + radius)} #{f(top)}" <>
      "H#{f(right - radius)}Q#{f(right)} #{f(top)} #{f(right)} #{f(corner)}V#{f(base)}Z"
  end

  @doc """
  Return the path of a slice of a pie, from an angle to an angle in turns

  A turn of 0 is at the top, and the angle grows clockwise. A slice of a whole
  turn is a circle.

      iex> Expresso.Element.Chart.Plot.slice(100, 100, 50, 0, 0.25)
      "M100 100L100 50A50 50 0 0 1 150 100Z"
  """
  @spec slice(number(), number(), number(), number(), number()) :: String.t()
  def slice(cx, cy, r, from, to) when to - from >= 1 do
    "M#{f(cx)} #{f(cy - r)}A#{f(r)} #{f(r)} 0 1 1 #{f(cx)} #{f(cy + r)}" <>
      "A#{f(r)} #{f(r)} 0 1 1 #{f(cx)} #{f(cy - r)}Z"
  end

  def slice(cx, cy, r, from, to) do
    {x0, y0} = point(cx, cy, r, from)
    {x1, y1} = point(cx, cy, r, to)
    large = if to - from > 0.5, do: 1, else: 0

    "M#{f(cx)} #{f(cy)}L#{f(x0)} #{f(y0)}A#{f(r)} #{f(r)} 0 #{large} 1 #{f(x1)} #{f(y1)}Z"
  end

  defp point(cx, cy, r, turn) do
    angle = turn * 2 * :math.pi()
    {cx + r * :math.sin(angle), cy - r * :math.cos(angle)}
  end

  @doc """
  Move the labels at the ends of the lines apart, so no two are closer than
  a gap

  The function takes a list of positions, and it returns the new positions in
  the same order. A label moves down only as far as it must.

      iex> Expresso.Element.Chart.Plot.spread([100, 105, 300], 18)
      [100, 118, 300]
  """
  @spec spread([number()], number()) :: [number()]
  def spread(positions, gap) do
    {placed, _last} =
      positions
      |> Enum.with_index()
      |> Enum.sort()
      |> Enum.map_reduce(nil, fn {position, index}, last ->
        position = if last && position - last < gap, do: last + gap, else: position
        {{index, position}, position}
      end)

    placed |> Enum.sort() |> Enum.map(&elem(&1, 1))
  end

  @doc """
  Write a coordinate with at most one decimal

      iex> Expresso.Element.Chart.Plot.f(12.345)
      "12.3"
  """
  @spec f(number()) :: String.t()
  def f(value), do: value |> Kernel./(1) |> Float.round(1) |> label()
end
