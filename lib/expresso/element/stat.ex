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
  of the number at each frame of the browser. At the end of the count, the
  script writes a text from the attribute `data-texts`, so the number shows
  each digit of the value. A screen reader reads the value
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

  The shortest form of a very small or a very large float has an exponent,
  such as `1.5e-4`. The decimals are the digits of the fraction less the
  exponent, and at least 0.

      iex> Expresso.Element.Stat.decimals(1250)
      0
      iex> Expresso.Element.Stat.decimals(99.95)
      2
      iex> Expresso.Element.Stat.decimals(1.5e-4)
      5
      iex> Expresso.Element.Stat.decimals(2.5e15)
      0
  """
  @spec decimals(number()) :: non_neg_integer()
  def decimals(value) when is_integer(value), do: 0

  def decimals(value) when is_float(value) do
    {mantissa, exponent} =
      case value |> :erlang.float_to_binary([:short]) |> String.split("e") do
        [mantissa, exponent] -> {mantissa, String.to_integer(exponent)}
        [mantissa] -> {mantissa, 0}
      end

    fraction =
      case String.split(mantissa, ".") do
        [_whole, fraction] -> String.trim_trailing(fraction, "0")
        [_whole] -> ""
      end

    max(String.length(fraction) - exponent, 0)
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
      iex> Expresso.Element.Stat.format(12345678901234567890, 0, true)
      "12,345,678,901,234,567,890"
  """
  @spec format(number(), non_neg_integer(), boolean()) :: String.t()
  def format(value, decimals, group) do
    text = digits(abs(value), decimals)
    [whole | fraction] = String.split(text, ".")
    whole = if group, do: group(whole), else: whole
    # A value that rounds to zero has no sign.
    sign = if value < 0 and String.trim(text, "0") not in ["", "."], do: "-", else: ""
    Enum.join([sign <> whole | fraction], ".")
  end

  # The digits of a value that is not negative. An integer stays an integer,
  # because a float keeps only approximately 16 significant digits.
  defp digits(value, 0) when is_integer(value), do: Integer.to_string(value)

  defp digits(value, decimals) when is_integer(value),
    do: Integer.to_string(value) <> "." <> String.duplicate("0", decimals)

  defp digits(value, decimals), do: :erlang.float_to_binary(value, decimals: decimals)

  # The texts of the number at rest, as JSON: `from` and the value. The script
  # writes one of them when the count ends, because Chromium keeps only six
  # significant digits in the text of `--chart-n`.
  defp texts(values, decimals, group) do
    values |> Enum.map(&format(&1, decimals, group)) |> Enum.uniq() |> JSON.encode!()
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
      texts: if(stat.count, do: texts([stat.from, stat.value], decimals, stat.group)),
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
                 data_group: to_string(@group),
                 data_texts: @texts do
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
