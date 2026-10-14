defmodule Expresso.Element.Stat do
  @moduledoc """
  A big number with a label, such as "1,250 orders"

  The value is a number, so the `count` option can count from `from` to the
  value when the stat shows. The `prefix` and the `suffix` go before and after
  the number, such as `"$"` and `"k"`. The number has `decimals` digits after
  the point, and a comma between each group of three digits unless `group` is
  false.

  The count reads the registered property `--chart-n`, as the numbers of a
  chart with frames do, and `assets/src/chart.ts` writes its value as the text
  of the number at each frame of the browser. A screen reader reads the value
  from a text that the eye does not see, so it never reads a number in the
  middle of the count.
  """

  use Expresso.Element

  @typedoc "The struct of a stat"
  @type t :: %__MODULE__{}

  defstruct [
              :value,
              :label,
              :prefix,
              :suffix,
              :decimals,
              :class,
              group: true,
              count: false,
              from: 0,
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Return the number of decimals of a value: 0 for an integer, else the
  decimals of its shortest form

      iex> Expresso.Element.Stat.decimals(1250)
      0
      iex> Expresso.Element.Stat.decimals(99.95)
      2
  """
  @spec decimals(number()) :: non_neg_integer()
  def decimals(value) when is_integer(value), do: 0

  def decimals(value) when is_float(value) do
    case value |> :erlang.float_to_binary([:short]) |> String.split(".") do
      [_whole, fraction] -> if fraction == "0", do: 0, else: String.length(fraction)
      [_whole] -> 0
    end
  end

  @doc """
  Write a number with a number of decimals, and with a comma between each
  group of three digits when `group` is true

      iex> Expresso.Element.Stat.format(1250, 0, true)
      "1,250"
      iex> Expresso.Element.Stat.format(-1234567.5, 2, true)
      "-1,234,567.50"
      iex> Expresso.Element.Stat.format(1250, 0, false)
      "1250"
  """
  @spec format(number(), non_neg_integer(), boolean()) :: String.t()
  def format(value, decimals, group) do
    text = :erlang.float_to_binary(abs(value) / 1, decimals: decimals)
    [whole | fraction] = String.split(text, ".")
    whole = if group, do: group(whole), else: whole
    # A value that rounds to zero has no sign.
    sign = if value < 0 and String.trim(text, "0") not in ["", "."], do: "-", else: ""
    Enum.join([sign <> whole | fraction], ".")
  end

  defp group(digits) do
    digits
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(",", &Enum.join/1)
    |> String.reverse()
  end

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(%__MODULE__{} = stat) do
    decimals = stat.decimals || decimals(stat.value)
    number = format(stat.value, decimals, stat.group)

    %{
      number: number,
      text: "#{stat.prefix}#{number}#{stat.suffix}",
      prefix: stat.prefix,
      suffix: stat.suffix,
      label: stat.label,
      count: stat.count,
      style: "--stat-from: #{stat.from}; --stat-to: #{stat.value};",
      decimals: decimals,
      group: stat.group,
      overlay: Expresso.Overlay.Render.attributes(stat)
    }
  end

  @doc """
  Make the HTML of a stat

  The figure holds the number and its label. The number that the eye sees is
  hidden from a screen reader, and a hidden text holds the whole value for a
  screen reader. With `count`, the number has the class `stat-count`.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      figure class: Expresso.Element.classes("stat", assigns[:class]), rest!: @overlay do
        p class: "stat-value" do
          span "aria-hidden": "true" do
            if @prefix, do: span(class: "stat-prefix", do: @prefix)

            span class: if(@count, do: "stat-number stat-count", else: "stat-number"),
                 style: @style,
                 data_decimals: @decimals,
                 data_group: to_string(@group) do
              @number
            end

            if @suffix, do: span(class: "stat-suffix", do: @suffix)
          end

          span class: "stat-text", do: @text
        end

        if @label, do: figcaption(class: "stat-label", do: @label)
      end
    end
  end
end
