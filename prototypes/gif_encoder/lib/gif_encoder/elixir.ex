defmodule GifEncoder.Elixir do
  @moduledoc """
  Encodes a GIF in pure Elixir

  For each frame, the encoder:

  1. decodes the PNG image with `GifEncoder.Png`;
  2. counts each exact color of the frame;
  3. makes a palette of at most 256 colors with median cut, so a frame of 256
     colors or fewer keeps its exact colors;
  4. gives each pixel the index of the box of its color;
  5. compresses the indices with LZW.

  `GifEncoder.Zig` does the same steps in Zig.
  """

  use GifEncoder.PerFrame

  import Bitwise

  alias GifEncoder.{Container, Png}

  @impl GifEncoder.PerFrame
  def encode_frame(png, _opts) do
    with {:ok, {width, height, rgb}} <- Png.decode(png) do
      counts = Enum.frequencies(for <<color::24 <- rgb>>, do: color)
      boxes = median_cut([Map.to_list(counts)], 256)
      palette = for box <- boxes, into: <<>>, do: mean(box)

      index =
        for {box, i} <- Enum.with_index(boxes), {color, _count} <- box, into: %{}, do: {color, i}

      indices = for <<color::24 <- rgb>>, into: <<>>, do: <<Map.fetch!(index, color)>>
      code_size = Container.code_size(length(boxes))

      {:ok,
       %{
         width: width,
         height: height,
         palette: palette,
         code_size: code_size,
         lzw: lzw(indices, code_size)
       }}
    end
  end

  # Split the box with the largest range on one channel, at the median of its
  # pixels, until there are `limit` boxes or no box can split.
  defp median_cut(boxes, limit) when length(boxes) >= limit, do: boxes

  defp median_cut(boxes, limit) do
    case boxes
         |> Enum.filter(&(length(&1) > 1))
         |> Enum.max_by(&elem(widest(&1), 1), fn -> nil end) do
      nil ->
        boxes

      box ->
        {shift, _range} = widest(box)
        sorted = Enum.sort_by(box, fn {color, _count} -> color >>> shift &&& 255 end)
        half = div(Enum.sum_by(sorted, &elem(&1, 1)) + 1, 2)
        {low, high} = split(sorted, half, 0, [])
        median_cut([low, high | List.delete(boxes, box)], limit)
    end
  end

  # The channel with the largest range, as a shift, and the range.
  defp widest(box) do
    for shift <- [16, 8, 0] do
      values = Enum.map(box, fn {color, _count} -> color >>> shift &&& 255 end)
      {shift, Enum.max(values) - Enum.min(values)}
    end
    |> Enum.max_by(&elem(&1, 1))
  end

  # The low part takes colors until it holds half of the pixels, and each part
  # keeps one color at least.
  defp split([color | rest], half, sum, low) when rest != [] and (low == [] or sum < half),
    do: split(rest, half, sum + elem(color, 1), [color | low])

  defp split(rest, _half, _sum, low), do: {low, rest}

  defp mean(box) do
    total = Enum.sum_by(box, &elem(&1, 1))

    for shift <- [16, 8, 0], into: <<>> do
      sum = Enum.sum_by(box, fn {color, count} -> (color >>> shift &&& 255) * count end)
      <<div(sum + div(total, 2), total)>>
    end
  end

  @doc """
  Compress the indices with the LZW of GIF

  The code size starts at `code_size + 1` bits. It grows after a code when the
  next free code needs more bits, and a clear code restarts the table at 4096
  codes.
  """
  @spec lzw(binary(), 2..8) :: binary()
  def lzw(<<first, rest::binary>>, code_size) do
    clear = 1 <<< code_size
    state = %{out: [], acc: 0, bits: 0, size: code_size + 1, next: clear + 2, table: %{}}
    state = emit(state, clear)

    state =
      for <<k <- rest>>, reduce: {state, first} do
        {state, current} ->
          case Map.fetch(state.table, current <<< 8 ||| k) do
            {:ok, code} -> {state, code}
            :error -> {add(emit(state, current), current, k, clear, code_size), k}
          end
      end
      |> then(fn {state, current} -> emit(state, current) end)
      |> emit(clear + 1)

    state = if state.bits > 0, do: %{state | out: [state.out | <<state.acc>>]}, else: state
    IO.iodata_to_binary(state.out)
  end

  defp add(%{next: 4096} = state, _current, _k, clear, code_size) do
    state = emit(state, clear)
    %{state | table: %{}, next: clear + 2, size: code_size + 1}
  end

  defp add(state, current, k, _clear, _code_size),
    do: %{
      state
      | table: Map.put(state.table, current <<< 8 ||| k, state.next),
        next: state.next + 1
    }

  # Write a code with the current size, then grow the size when the next free
  # code does not fit in it.
  defp emit(state, code) do
    {out, acc, bits} =
      flush(state.out, state.acc ||| code <<< state.bits, state.bits + state.size)

    size =
      if state.next > (1 <<< state.size) - 1 and state.size < 12,
        do: state.size + 1,
        else: state.size

    %{state | out: out, acc: acc, bits: bits, size: size}
  end

  defp flush(out, acc, bits) when bits >= 8,
    do: flush([out | <<acc &&& 255>>], acc >>> 8, bits - 8)

  defp flush(out, acc, bits), do: {out, acc, bits}
end
