defmodule Expresso.Test.PngWriter do
  @moduledoc """
  Writes an RGB image as a PNG image of 8-bit RGB, for the tests of `Expresso.Gif`

  Each row can have a different filter, so a test can make sure that
  `Expresso.Gif.Nif.unfilter/3` removes each of the five filters of PNG.
  """

  import Bitwise

  @doc "Write the RGB bytes of a `width` by `height` image, with one filter from 0 to 4 for each row"
  @spec png(binary(), pos_integer(), pos_integer(), [0..4]) :: binary()
  def png(rgb, width, height, filters \\ []) do
    stride = width * 3
    filters = filters ++ List.duplicate(0, max(height - length(filters), 0))

    {rows, _above} =
      Enum.map_reduce(Enum.zip(0..(height - 1), filters), :binary.copy(<<0>>, stride), fn {y,
                                                                                           filter},
                                                                                          above ->
        line = binary_part(rgb, y * stride, stride)
        {[filter, filter(filter, line, above)], line}
      end)

    ihdr = <<width::32, height::32, 8, 2, 0, 0, 0>>
    idat = :zlib.compress(IO.iodata_to_binary(rows))

    IO.iodata_to_binary([
      <<137, "PNG", 13, 10, 26, 10>>,
      chunk("IHDR", ihdr),
      chunk("IDAT", idat),
      chunk("IEND", <<>>)
    ])
  end

  defp chunk(type, data),
    do: [<<byte_size(data)::32>>, type, data, <<:erlang.crc32([type, data])::32>>]

  defp filter(filter, line, above) do
    line = :binary.bin_to_list(line)
    above = :binary.bin_to_list(above)
    left = [0, 0, 0 | line]
    upper_left = [0, 0, 0 | above]

    for {{x, a}, {b, c}} <- Enum.zip(Enum.zip(line, left), Enum.zip(above, upper_left)),
        into: <<>> do
      <<x - predict(filter, a, b, c) &&& 255>>
    end
  end

  defp predict(0, _a, _b, _c), do: 0
  defp predict(1, a, _b, _c), do: a
  defp predict(2, _a, b, _c), do: b
  defp predict(3, a, b, _c), do: div(a + b, 2)

  defp predict(4, a, b, c) do
    p = a + b - c
    {pa, pb, pc} = {abs(p - a), abs(p - b), abs(p - c)}

    cond do
      pa <= pb and pa <= pc -> a
      pb <= pc -> b
      true -> c
    end
  end
end
