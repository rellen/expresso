defmodule Expresso.Gif.Container do
  @moduledoc """
  Writes the parts of a GIF89a file around the encoded frames

  Each frame is a rectangle of the logical screen, with its own color table
  and its own delay. A frame with a transparent index lets the pixels of the
  frame before it show through, because each frame keeps the disposal method
  "do not dispose". The NETSCAPE2.0 extension makes the GIF repeat with no
  end.
  """

  import Bitwise

  @typedoc """
  One encoded frame of `Expresso.Gif.Nif.encode_frame/4`, with its delay

  `palette` holds 3 bytes for each color. `transparent` is the index of the
  transparent pixels, or -1. Each index of `lzw` is less than
  `2 ** code_size`.
  """
  @type image :: %{
          x: non_neg_integer(),
          y: non_neg_integer(),
          width: pos_integer(),
          height: pos_integer(),
          palette: binary(),
          transparent: integer(),
          code_size: 2..8,
          lzw: binary(),
          delay: non_neg_integer()
        }

  @doc "Write a GIF of a logical screen of `width` by `height` from the frames, in order"
  @spec gif(pos_integer(), pos_integer(), [image()]) :: binary()
  def gif(width, height, images) do
    IO.iodata_to_binary([
      "GIF89a",
      # The logical screen: no global color table, 8 bits of color resolution.
      <<width::little-16, height::little-16, 0x70, 0, 0>>,
      <<0x21, 0xFF, 11, "NETSCAPE2.0", 3, 1, 0::little-16, 0>>,
      Enum.map(images, &frame/1),
      0x3B
    ])
  end

  defp frame(image) do
    entries = 1 <<< image.code_size
    padding = :binary.copy(<<0>>, (entries - div(byte_size(image.palette), 3)) * 3)
    {flag, index} = if image.transparent >= 0, do: {1, image.transparent}, else: {0, 0}

    [
      # The disposal method 1, "do not dispose", and the delay in hundredths
      # of a second.
      <<0x21, 0xF9, 4, 0b0000_0100 ||| flag, div(image.delay + 5, 10)::little-16, index, 0>>,
      <<0x2C, image.x::little-16, image.y::little-16, image.width::little-16,
        image.height::little-16, 0x80 ||| image.code_size - 1>>,
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
end
