defmodule Expresso.Test.GifDecoder do
  @moduledoc """
  Decodes a GIF89a file to the RGB image of each frame, for the tests of `Expresso.Gif`

  The decoder knows only the parts that `Expresso.Gif.Container` writes: no
  global color table, a graphic control extension in front of each image, a
  local color table, and the disposal method "do not dispose". It returns the
  whole logical screen after each frame, so a test can compare the result with
  the frames that went into the encoder.
  """

  import Bitwise

  @typedoc "The logical screen after one frame, the delay in milliseconds and the rectangle of the frame"
  @type frame :: %{
          rgb: binary(),
          delay: non_neg_integer(),
          rect: {non_neg_integer(), non_neg_integer(), pos_integer(), pos_integer()}
        }

  @doc "Decode a GIF, and return its size, its loop count and its frames"
  @spec decode(binary()) :: %{
          width: pos_integer(),
          height: pos_integer(),
          loop: non_neg_integer() | nil,
          frames: [frame()]
        }
  def decode(<<"GIF89a", width::little-16, height::little-16, 0x70, 0, 0, rest::binary>>) do
    screen = :binary.copy(<<0, 0, 0>>, width * height)
    state = %{width: width, height: height, loop: nil, frames: [], screen: screen, control: nil}
    state = blocks(rest, state)
    %{width: width, height: height, loop: state.loop, frames: Enum.reverse(state.frames)}
  end

  defp blocks(<<0x3B>>, state), do: state

  defp blocks(<<0x21, 0xFF, 11, "NETSCAPE2.0", 3, 1, loop::little-16, 0, rest::binary>>, state),
    do: blocks(rest, %{state | loop: loop})

  defp blocks(<<0x21, 0xF9, 4, packed, delay::little-16, index, 0, rest::binary>>, state) do
    1 = packed >>> 2 &&& 0b111
    transparent = if (packed &&& 1) == 1, do: index, else: nil
    blocks(rest, %{state | control: {delay * 10, transparent}})
  end

  defp blocks(
         <<0x2C, x::little-16, y::little-16, w::little-16, h::little-16, packed, rest::binary>>,
         state
       ) do
    1 = packed >>> 7
    0 = packed >>> 6 &&& 1
    bytes = 3 <<< ((packed &&& 0b111) + 1)
    <<palette::binary-size(^bytes), code_size, rest::binary>> = rest
    {data, rest} = sub_blocks(rest, [])
    indices = lzw(data, code_size)
    ^w = div(byte_size(indices), h)
    {delay, transparent} = state.control
    screen = paint(state, {x, y, w, h}, palette, transparent, indices)
    frame = %{rgb: screen, delay: delay, rect: {x, y, w, h}}
    blocks(rest, %{state | screen: screen, control: nil, frames: [frame | state.frames]})
  end

  defp sub_blocks(<<0, rest::binary>>, acc), do: {IO.iodata_to_binary(Enum.reverse(acc)), rest}

  defp sub_blocks(<<size, block::binary-size(size), rest::binary>>, acc),
    do: sub_blocks(rest, [block | acc])

  defp paint(state, {x, y, w, h}, palette, transparent, indices) do
    true = x + w <= state.width and y + h <= state.height
    colors = List.to_tuple(for <<color::binary-3 <- palette>>, do: color)
    stride = state.width * 3

    rows =
      for row <- 0..(state.height - 1) do
        line = binary_part(state.screen, row * stride, stride)

        if row >= y and row < y + h do
          new = binary_part(indices, (row - y) * w, w)
          old = binary_part(line, x * 3, w * 3)
          after_rect = stride - (x + w) * 3

          [
            binary_part(line, 0, x * 3),
            paint_row(new, old, colors, transparent),
            binary_part(line, (x + w) * 3, after_rect)
          ]
        else
          line
        end
      end

    IO.iodata_to_binary(rows)
  end

  defp paint_row(indices, old, colors, transparent) do
    for {index, i} <- Enum.with_index(:binary.bin_to_list(indices)), into: <<>> do
      if index == transparent, do: binary_part(old, i * 3, 3), else: elem(colors, index)
    end
  end

  # The LZW of GIF, as the decoder of a viewer reads it.
  defp lzw(data, code_size) do
    clear = 1 <<< code_size
    initial = for i <- 0..(clear - 1), into: %{}, do: {i, <<i>>}
    reader = %{data: data, acc: 0, bits: 0}

    state = %{
      code_size: code_size,
      clear: clear,
      initial: initial,
      table: initial,
      next: clear + 2,
      size: code_size + 1,
      previous: nil
    }

    read_codes(reader, state, [])
  end

  defp read_codes(reader, state, out) do
    case read(reader, state.size) do
      :eof ->
        raise "the LZW data has no end code"

      {code, reader} ->
        cond do
          code == state.clear ->
            state = %{
              state
              | table: state.initial,
                next: state.clear + 2,
                size: state.code_size + 1,
                previous: nil
            }

            read_codes(reader, state, out)

          code == state.clear + 1 ->
            IO.iodata_to_binary(Enum.reverse(out))

          state.previous == nil ->
            read_codes(reader, %{state | previous: Map.fetch!(state.table, code)}, [
              Map.fetch!(state.table, code) | out
            ])

          true ->
            entry = entry(state, code)
            state = add(state, state.previous <> binary_part(entry, 0, 1))
            read_codes(reader, %{state | previous: entry}, [entry | out])
        end
    end
  end

  # A code can name the entry that the decoder adds for this code.
  defp entry(state, code) do
    case Map.fetch(state.table, code) do
      {:ok, entry} -> entry
      :error when code == state.next -> state.previous <> binary_part(state.previous, 0, 1)
    end
  end

  defp add(%{next: 4096} = state, _entry), do: state

  defp add(state, entry) do
    table = Map.put(state.table, state.next, entry)
    next = state.next + 1
    size = if next == 1 <<< state.size and state.size < 12, do: state.size + 1, else: state.size
    %{state | table: table, next: next, size: size}
  end

  defp read(%{bits: bits, acc: acc} = reader, size) when bits >= size,
    do: {acc &&& (1 <<< size) - 1, %{reader | acc: acc >>> size, bits: bits - size}}

  defp read(%{data: <<byte, rest::binary>>} = reader, size),
    do:
      read(
        %{reader | data: rest, acc: reader.acc ||| byte <<< reader.bits, bits: reader.bits + 8},
        size
      )

  defp read(_reader, _size), do: :eof
end
