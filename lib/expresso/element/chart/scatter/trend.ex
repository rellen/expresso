defmodule Expresso.Element.Chart.Scatter.Trend do
  @moduledoc """
  The arithmetic of a scatter plot that is not a place on an axis: the
  least-squares line of a group of points, and the jitter of a mark

  Each function takes the places of the points as fractions of the axes,
  from 0 at the low end to 1 at the high end. A logarithmic axis therefore
  fits the line to the logarithms of the values.
  """

  @doc """
  Return the least-squares line through points, as `{intercept, slope}`

  The function returns `nil` for fewer than two different x values, because
  such points give no line.

      iex> Expresso.Element.Chart.Scatter.Trend.fit([{0.0, 0.1}, {0.5, 0.35}, {1.0, 0.6}])
      {0.1, 0.5}
      iex> Expresso.Element.Chart.Scatter.Trend.fit([{0.5, 0.1}, {0.5, 0.9}])
      nil
  """
  @spec fit([{number(), number()}]) :: {float(), float()} | nil
  def fit(points) do
    n = length(points)
    mean_x = points |> Enum.map(&elem(&1, 0)) |> Enum.sum() |> Kernel./(max(n, 1))
    mean_y = points |> Enum.map(&elem(&1, 1)) |> Enum.sum() |> Kernel./(max(n, 1))
    sxx = points |> Enum.map(fn {x, _y} -> (x - mean_x) ** 2 end) |> Enum.sum()

    if sxx < 1.0e-12 do
      nil
    else
      sxy = points |> Enum.map(fn {x, y} -> (x - mean_x) * (y - mean_y) end) |> Enum.sum()
      slope = sxy / sxx
      {Float.round(mean_y - slope * mean_x, 12), Float.round(slope, 12)}
    end
  end

  @doc """
  Return the two ends of a line from the lowest x to the highest x, cut at
  the bottom and at the top of the plot

  The ends are `{x, y}` fractions of the axes. A line outside the plot from
  end to end returns `nil`.

      iex> Expresso.Element.Chart.Scatter.Trend.ends({0.1, 0.5}, 0.2, 0.8)
      {{0.2, 0.2}, {0.8, 0.5}}
      iex> Expresso.Element.Chart.Scatter.Trend.ends({0.5, 2.0}, 0.0, 1.0)
      {{0.0, 0.5}, {0.25, 1.0}}
  """
  @spec ends({number(), number()}, number(), number()) ::
          {{float(), float()}, {float(), float()}} | nil
  def ends({intercept, slope}, low, high) do
    y = &(intercept + slope * &1)

    {from, to} =
      if slope == 0,
        do: {low, high},
        else: cut({low, high}, (0 - intercept) / slope, (1 - intercept) / slope)

    if from > to or y.(from) < -1.0e-9 or y.(from) > 1 + 1.0e-9,
      do: nil,
      else: {{six(from), six(y.(from))}, {six(to), six(y.(to))}}
  end

  # The part of the range of x where the line is between 0 and 1.
  defp cut({low, high}, at_zero, at_one) do
    {a, b} = if at_zero < at_one, do: {at_zero, at_one}, else: {at_one, at_zero}
    {max(low, a), min(high, b)}
  end

  defp six(value), do: Float.round(value / 1, 6)

  @doc """
  Return the offset of a mark on one axis for the `jitter` option, as a
  fraction of the axis

  The offset comes from a hash of the name of the point and the axis, so each
  render gives the same chart. It is at most the jitter in each direction.

      iex> offset = Expresso.Element.Chart.Scatter.Trend.jitter("api", :x, 0.02)
      iex> offset == Expresso.Element.Chart.Scatter.Trend.jitter("api", :x, 0.02) and abs(offset) <= 0.02
      true
      iex> Expresso.Element.Chart.Scatter.Trend.jitter("api", :x, nil)
      0
  """
  @spec jitter(String.t(), :x | :y, number() | nil) :: number()
  def jitter(_name, _axis, nil), do: 0
  def jitter(name, axis, amount), do: amount * (:erlang.phash2({name, axis}, 2001) / 1000 - 1)
end
