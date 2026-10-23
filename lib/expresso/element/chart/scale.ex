defmodule Expresso.Element.Chart.Scale do
  @moduledoc """
  An axis of a scatter plot: its range, its ticks, and the place of a value on it

  A linear axis has round ticks, as `Expresso.Element.Chart.Plot.ticks/1`
  gives, but it does not need zero. A logarithmic axis has a tick at each
  power of ten, and also at 2 and 5 times each power when the axis holds two
  powers of ten or less. A range from the deck, such as `{0, 100}`, gives the
  ends of the axis, and the ticks are the round numbers between the ends.

  Each function takes numbers and returns numbers, so the tests need no
  render.
  """

  alias Expresso.Element.Chart.Plot

  @typedoc """
  An axis: `:linear` or `:log`, the value at each end, and the value of each tick
  """
  @type t :: %__MODULE__{
          type: :linear | :log,
          low: number(),
          high: number(),
          ticks: [number()]
        }

  defstruct [:type, :low, :high, :ticks]

  @doc """
  Make the axis of a list of values, from a range or from the values

      iex> Expresso.Element.Chart.Scale.new([12, 47], nil, :linear)
      %Expresso.Element.Chart.Scale{type: :linear, low: 10, high: 50, ticks: [10, 20, 30, 40, 50]}

      iex> Expresso.Element.Chart.Scale.new([12, 47], {0, 60}, :linear).ticks
      [0, 20, 40, 60]

      iex> Expresso.Element.Chart.Scale.new([3, 2500], nil, :log).ticks
      [1, 10, 100, 1000, 10000]

      iex> Expresso.Element.Chart.Scale.new([3, 40], nil, :log).ticks
      [1, 2, 5, 10, 20, 50, 100]
  """
  @spec new([number(), ...], {number(), number()} | nil, :linear | :log) :: t()
  def new(values, nil, :linear) do
    {low, high} = spread(Enum.min(values), Enum.max(values))
    step = Plot.step((high - low) / 5)
    first = trunc(Float.floor(low / step))
    last = trunc(Float.ceil(high / step))
    ticks = for n <- first..last, do: Plot.number(n * step)
    %__MODULE__{type: :linear, low: hd(ticks), high: List.last(ticks), ticks: ticks}
  end

  def new(_values, {low, high}, :linear) do
    step = Plot.step((high - low) / 5)
    first = trunc(Float.ceil(low / step - 1.0e-9))
    last = trunc(Float.floor(high / step + 1.0e-9))
    ticks = for n <- first..last//1, do: Plot.number(n * step)
    %__MODULE__{type: :linear, low: low, high: high, ticks: ticks}
  end

  def new(values, nil, :log) do
    low = power(Float.floor(:math.log10(Enum.min(values))))
    high = power(Float.ceil(:math.log10(Enum.max(values))))
    high = if high == low, do: Plot.number(low * 10), else: high
    %__MODULE__{type: :log, low: low, high: high, ticks: log_ticks(low, high)}
  end

  def new(_values, {low, high}, :log),
    do: %__MODULE__{type: :log, low: low, high: high, ticks: log_ticks(low, high)}

  # A range of one value gets a width, so the axis has two ends.
  defp spread(value, value) when value == 0, do: {-1, 1}
  defp spread(value, value), do: {value - abs(value) / 10, value + abs(value) / 10}
  defp spread(low, high), do: {low, high}

  defp power(exponent), do: Plot.number(:math.pow(10, exponent))

  # The ticks of a logarithmic axis between two values. The factors 2 and 5
  # add ticks to a short axis.
  defp log_ticks(low, high) do
    factors = if :math.log10(high / low) <= 2, do: [1, 2, 5], else: [1]
    first = trunc(Float.floor(:math.log10(low)))
    last = trunc(Float.ceil(:math.log10(high)))

    for exponent <- first..last,
        factor <- factors,
        value = Plot.number(factor * :math.pow(10, exponent)),
        value >= low * (1 - 1.0e-9) and value <= high * (1 + 1.0e-9),
        do: value
  end

  @doc """
  Return the place of a value on an axis, from 0 at the low end to 1 at the high end

      iex> scale = Expresso.Element.Chart.Scale.new([12, 47], nil, :linear)
      iex> Expresso.Element.Chart.Scale.fraction(scale, 30)
      0.5

      iex> scale = Expresso.Element.Chart.Scale.new([3, 2500], nil, :log)
      iex> Expresso.Element.Chart.Scale.fraction(scale, 100)
      0.5
  """
  @spec fraction(t(), number()) :: float()
  def fraction(%__MODULE__{type: :linear, low: low, high: high}, value),
    do: (value - low) / (high - low)

  def fraction(%__MODULE__{type: :log, low: low, high: high}, value),
    do: (:math.log10(value) - :math.log10(low)) / (:math.log10(high) - :math.log10(low))
end
