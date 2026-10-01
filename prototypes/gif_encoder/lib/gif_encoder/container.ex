defmodule GifEncoder.Container do
  @moduledoc """
  Writes the parts of a GIF89a file around the encoded frames

  An encoder of one frame returns an `t:image/0`: the size, the palette, the
  minimum code size of the LZW data, and the LZW data. `gif/1` writes the
  header, the loop extension, each frame with its delay and its local color
  table, and the trailer.
  """

  import Bitwise

  @typedoc """
  One encoded frame

  `palette` holds 3 bytes for each color, and at most 256 colors. Each index
  of `lzw` is less than `2 ** code_size`.
  """
  @type image :: %{
          width: pos_integer(),
          height: pos_integer(),
          palette: binary(),
          code_size: 2..8,
          lzw: binary(),
          delay: non_neg_integer()
        }

  @doc "Write a GIF that repeats with no end from the frames, in order"
  @spec gif([image()]) :: binary()
  def gif([%{width: width, height: height} | _frames] = frames) do
    IO.iodata_to_binary([
      "GIF89a",
      # The logical screen: the size, no global color table, and 8 bits of
      # color resolution.
      <<width::little-16, height::little-16, 0x70, 0, 0>>,
      # The NETSCAPE2.0 extension: repeat with no end.
      <<0x21, 0xFF, 11, "NETSCAPE2.0", 3, 1, 0::little-16, 0>>,
      Enum.map(frames, &frame/1),
      0x3B
    ])
  end

  defp frame(image) do
    entries = 1 <<< image.code_size
    padding = :binary.copy(<<0>>, (entries - div(byte_size(image.palette), 3)) * 3)
    # The delay is in hundredths of a second.
    delay = div(image.delay + 5, 10)

    [
      <<0x21, 0xF9, 4, 0b0000_0100, delay::little-16, 0, 0>>,
      <<0x2C, 0::little-16, 0::little-16, image.width::little-16, image.height::little-16>>,
      <<0x80 ||| image.code_size - 1>>,
      image.palette,
      padding,
      image.code_size,
      blocks(image.lzw),
      0
    ]
  end

  defp blocks(<<block::binary-255, rest::binary>>), do: [255, block | blocks(rest)]
  defp blocks(<<>>), do: []
  defp blocks(rest), do: [byte_size(rest), rest]

  @doc """
  The minimum LZW code size for a palette of `colors` colors

  GIF needs at least 2 bits.

      iex> GifEncoder.Container.code_size(256)
      8
      iex> GifEncoder.Container.code_size(3)
      2
  """
  @spec code_size(pos_integer()) :: 2..8
  def code_size(colors), do: max(2, ceil_log2(colors))

  defp ceil_log2(n), do: Enum.find(1..8, &(1 <<< &1 >= n))
end
