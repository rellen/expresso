defmodule Expresso.Element.Chart.Encoding do
  @moduledoc """
  The symbol, the color and the size of a mark of a scatter plot

  A point gives each of the three as a category, such as `"EU"`, or as a
  value: a symbol by its name, such as `:square`, a color by a role of the
  theme, such as `:chart_3` or `:accent`, and a size as a number. A category
  of the symbol takes the symbols in the order of `symbols/0`, and a category
  of the color takes `--chart-1` to `--chart-8`, each in the order of the
  first point of the category.

  Each symbol is a path of radius 1 at the origin. The symbols have
  approximately the area of a circle of radius 1, so a mark of one size looks
  as large with each symbol. The size of a point gives the area of its mark,
  so a size two times larger gives two times the area.

  A number as the color takes a place on the scale of the `color_scale`
  option: `scale/1` gives the color of the scale, and `scale_place/4` the
  place of a number on it.
  """

  alias Expresso.Element.Chart.Plot

  @symbols [:circle, :square, :triangle, :diamond, :cross, :star]

  @paths %{
    circle: "M1 0A1 1 0 1 1 -1 0A1 1 0 1 1 1 0Z",
    square: "M-0.886 -0.886H0.886V0.886H-0.886Z",
    triangle: "M0 -1.555L1.347 0.778H-1.347Z",
    diamond: "M0 -1.253L1.253 0L0 1.253L-1.253 0Z",
    cross: "M-0.35 -1.25H0.35V-0.35H1.25V0.35H0.35V1.25H-0.35V0.35H-1.25V-0.35H-0.35Z",
    star:
      "M0 -1.541L0.408 -0.561L1.466 -0.476L0.66 0.214L0.906 1.247L0 0.694L-0.906 1.247" <>
        "L-0.66 0.214L-1.466 -0.476L-0.408 -0.561Z"
  }

  @chart_roles for n <- 1..8, do: :"chart_#{n}"

  @doc """
  Return each symbol, in the order that the categories take them

      iex> Expresso.Element.Chart.Encoding.symbols()
      [:circle, :square, :triangle, :diamond, :cross, :star]
  """
  @spec symbols() :: [atom()]
  def symbols, do: @symbols

  @doc """
  Return each role that the color of a point takes: `:chart_1` to `:chart_8`
  and the roles of `Expresso.Element.Icon.colors/0`
  """
  @spec roles() :: [atom()]
  def roles, do: @chart_roles ++ Expresso.Element.Icon.colors()

  @doc """
  Check the `opacity` option: a number from 0 to 1

      iex> Expresso.Element.Chart.Encoding.opacity(0.6)
      {:ok, 0.6}
      iex> Expresso.Element.Chart.Encoding.opacity(2)
      {:error, "the opacity of a mark is a number from 0 to 1, such as 0.6"}
  """
  @spec opacity(term()) :: {:ok, number()} | {:error, String.t()}
  def opacity(value) when is_number(value) and value >= 0 and value <= 1, do: {:ok, value}
  def opacity(_value), do: {:error, "the opacity of a mark is a number from 0 to 1, such as 0.6"}

  @doc """
  Check the `jitter` option: a number from 0 to 0.2

      iex> Expresso.Element.Chart.Encoding.jitter(0.02)
      {:ok, 0.02}
      iex> Expresso.Element.Chart.Encoding.jitter(0.5)
      {:error, "the jitter is a part of the range of an axis from 0 to 0.2, such as 0.02"}
  """
  @spec jitter(term()) :: {:ok, number()} | {:error, String.t()}
  def jitter(value) when is_number(value) and value >= 0 and value <= 0.2, do: {:ok, value}

  def jitter(_value),
    do: {:error, "the jitter is a part of the range of an axis from 0 to 0.2, such as 0.02"}

  @doc """
  Return the path of a symbol of radius 1 at the origin

      iex> Expresso.Element.Chart.Encoding.path(:diamond)
      "M0 -1.253L1.253 0L0 1.253L-1.253 0Z"
  """
  @spec path(atom()) :: String.t()
  def path(symbol), do: Map.fetch!(@paths, symbol)

  @doc """
  Return the categories of a list of values: each string, one time, in the
  order of its first value

      iex> Expresso.Element.Chart.Encoding.categories(["EU", nil, :square, "US", "EU"])
      ["EU", "US"]
  """
  @spec categories([term()]) :: [String.t()]
  def categories(values), do: values |> Enum.filter(&is_binary/1) |> Enum.uniq()

  @doc """
  Return the symbol of a value: the symbol of its category, the symbol that
  it names, or a circle

      iex> Expresso.Element.Chart.Encoding.symbol("US", ["EU", "US"])
      :square
      iex> Expresso.Element.Chart.Encoding.symbol(:star, ["EU", "US"])
      :star
      iex> Expresso.Element.Chart.Encoding.symbol(nil, [])
      :circle
  """
  @spec symbol(String.t() | atom() | nil, [String.t()]) :: atom()
  def symbol(nil, _categories), do: :circle
  def symbol(symbol, _categories) when is_atom(symbol), do: symbol

  def symbol(category, categories),
    do: Enum.at(@symbols, Enum.find_index(categories, &(&1 == category)))

  @doc """
  Return the CSS color of a value: the color of its category, the role that
  it names, or a default

      iex> Expresso.Element.Chart.Encoding.color("US", ["EU", "US"], "var(--chart-1)")
      "var(--chart-2)"
      iex> Expresso.Element.Chart.Encoding.color(:chart_5, [], "var(--chart-1)")
      "var(--chart-5)"
      iex> Expresso.Element.Chart.Encoding.color(:accent, [], "var(--chart-1)")
      "var(--accent)"
      iex> Expresso.Element.Chart.Encoding.color(nil, [], "var(--muted)")
      "var(--muted)"
  """
  @spec color(String.t() | atom() | nil, [String.t()], String.t() | nil) :: String.t() | nil
  def color(nil, _categories, default), do: default
  def color(role, _categories, _default) when is_atom(role), do: role(role)

  def color(category, categories, _default),
    do: "var(--chart-#{Enum.find_index(categories, &(&1 == category)) + 1})"

  @doc """
  Return the CSS color of a role of the theme

      iex> Expresso.Element.Chart.Encoding.role(:chart_2)
      "var(--chart-2)"
  """
  @spec role(atom()) :: String.t()
  def role(role), do: "var(--#{String.replace(Atom.to_string(role), "_", "-")})"

  @doc """
  Return the CSS color of a scale of the `color_scale` option

  The color reads `--chart-h`, the place of the value of a mark on the scale.
  A sequential scale and a scale of two roles go from 0 to 1, and a
  diverging scale goes from -1 through 0 to 1.

      iex> Expresso.Element.Chart.Encoding.scale({:chart_1, :chart_4})
      "color-mix(in oklab, var(--chart-4) calc(var(--chart-h) * 100%), var(--chart-1))"
  """
  @spec scale(:sequential | :diverging | {atom(), atom()}) :: String.t()
  def scale(:sequential),
    do:
      "color-mix(in oklab, var(--accent) calc(var(--chart-h) * 100%), " <>
        "color-mix(in oklab, var(--accent) 15%, var(--background)))"

  def scale(:diverging),
    do:
      "color-mix(in oklab, var(--success) calc(max(var(--chart-h), 0) * 100%), " <>
        "color-mix(in oklab, var(--danger) calc(max(var(--chart-h) * -1, 0) * 100%), " <>
        "color-mix(in oklab, var(--muted) 35%, var(--background))))"

  def scale({from, to}),
    do: "color-mix(in oklab, #{role(to)} calc(var(--chart-h) * 100%), #{role(from)})"

  @doc """
  Return the place of a value on a scale of colors, from the lowest and the
  highest value of the chart

  The place goes from 0 to 1, or from -1 to 1 on a diverging scale. The
  middle of a diverging scale is 0 at `mid`, and each side reaches 1 at the
  value furthest from `mid`, so the colors of the two sides compare.

      iex> Expresso.Element.Chart.Encoding.scale_place(15, {10, 30}, :sequential, nil)
      0.25
      iex> Expresso.Element.Chart.Encoding.scale_place(-5, {-10, 20}, :diverging, 0)
      -0.25
  """
  @spec scale_place(number(), {number(), number()}, atom() | tuple(), number() | nil) :: float()
  def scale_place(value, {low, high}, :diverging, mid) do
    mid = mid || 0
    reach = max(abs(high - mid), abs(mid - low))
    if reach == 0, do: 0.0, else: (value - mid) / reach
  end

  def scale_place(_value, {low, low}, _scale, _mid), do: 1.0
  def scale_place(value, {low, high}, _scale, _mid), do: (value - low) / (high - low)

  @doc """
  Return the radius of a mark from its size, the largest size of the chart
  and the radius of the largest mark

      iex> Expresso.Element.Chart.Encoding.radius(25, 100, 30)
      15.0
  """
  @spec radius(number(), number(), number()) :: float()
  def radius(size, largest, most), do: most * :math.sqrt(size / largest)

  @doc """
  Return the three sizes of the legend of the sizes: round numbers at
  approximately the largest size, a quarter of it and a sixteenth of it

      iex> Expresso.Element.Chart.Encoding.legend_sizes(120_000)
      [100000, 20000, 5000]
      iex> Expresso.Element.Chart.Encoding.legend_sizes(3)
      [2, 0.5, 0.1]
  """
  @spec legend_sizes(number()) :: [number()]
  def legend_sizes(largest) do
    [largest, largest / 4, largest / 16] |> Enum.map(&round_down/1) |> Enum.uniq()
  end

  # The largest number of 1, 2 or 5 times a power of ten that is not more
  # than the value.
  defp round_down(value) do
    power = :math.pow(10, Float.floor(:math.log10(value)))
    factor = Enum.find([5, 2, 1], &(&1 * power <= value * (1 + 1.0e-9)))
    Plot.number(factor * power)
  end
end
