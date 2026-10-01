defmodule GifEncoder.Png do
  @moduledoc """
  Reads a PNG image of 8-bit RGB, the format of a screenshot of Chromium

  `inflate/1` returns the size and the filtered rows, and `decode/1` also
  removes the filters, so it returns 3 bytes for each pixel. Another format
  returns an error.
  """

  import Bitwise

  @doc "Return the size and the filtered rows of a PNG image"
  @spec inflate(binary()) ::
          {:ok, {pos_integer(), pos_integer(), binary()}} | {:error, String.t()}
  def inflate(<<137, "PNG", 13, 10, 26, 10, chunks::binary>>), do: chunks(chunks, nil, [])
  def inflate(_data), do: {:error, "not a PNG image"}

  defp chunks(
         <<length::32, type::binary-4, data::binary-size(length), _crc::32, rest::binary>>,
         size,
         idat
       ) do
    case {type, data} do
      {"IHDR", <<width::32, height::32, 8, 2, 0, 0, 0>>} -> chunks(rest, {width, height}, idat)
      {"IHDR", _data} -> {:error, "only 8-bit RGB with no interlace"}
      {"IDAT", _data} -> chunks(rest, size, [idat, data])
      {"IEND", _data} -> finish(size, idat)
      _other -> chunks(rest, size, idat)
    end
  end

  defp chunks(_data, _size, _idat), do: {:error, "a damaged PNG image"}

  defp finish(nil, _idat), do: {:error, "no IHDR chunk"}

  defp finish({width, height}, idat),
    do: {:ok, {width, height, :zlib.uncompress(IO.iodata_to_binary(idat))}}

  @doc "Return the size and the RGB bytes of a PNG image, row by row"
  @spec decode(binary()) :: {:ok, {pos_integer(), pos_integer(), binary()}} | {:error, String.t()}
  def decode(png) do
    with {:ok, {width, height, rows}} <- inflate(png) do
      stride = width * 3
      {:ok, {width, height, unfilter(rows, stride, :binary.copy(<<0>>, stride), [])}}
    end
  end

  defp unfilter(<<>>, _stride, _previous, acc), do: acc |> Enum.reverse() |> IO.iodata_to_binary()

  defp unfilter(<<filter, rest::binary>>, stride, previous, acc) do
    <<line::binary-size(stride), rest::binary>> = rest
    row = row(filter, line, previous)
    unfilter(rest, stride, row, [row | acc])
  end

  defp row(0, line, _previous), do: line
  defp row(2, line, previous), do: up(line, previous, [])
  defp row(filter, line, previous), do: pixels(filter, line, previous, 0, 0, 0, 0, 0, 0, [])

  defp up(<<x, line::binary>>, <<b, previous::binary>>, acc),
    do: up(line, previous, [acc | <<x + b &&& 255>>])

  defp up(<<>>, <<>>, acc), do: IO.iodata_to_binary(acc)

  # The left pixel is a1 a2 a3, and the pixel above the left pixel is c1 c2 c3.
  defp pixels(
         f,
         <<x1, x2, x3, line::binary>>,
         <<b1, b2, b3, prev::binary>>,
         a1,
         a2,
         a3,
         c1,
         c2,
         c3,
         acc
       ) do
    v1 = byte(f, x1, a1, b1, c1)
    v2 = byte(f, x2, a2, b2, c2)
    v3 = byte(f, x3, a3, b3, c3)
    pixels(f, line, prev, v1, v2, v3, b1, b2, b3, [acc | <<v1, v2, v3>>])
  end

  defp pixels(_f, <<>>, <<>>, _a1, _a2, _a3, _c1, _c2, _c3, acc), do: IO.iodata_to_binary(acc)

  defp byte(1, x, a, _b, _c), do: x + a &&& 255
  defp byte(3, x, a, b, _c), do: x + ((a + b) >>> 1) &&& 255
  defp byte(4, x, a, b, c), do: x + paeth(a, b, c) &&& 255

  defp paeth(a, b, c) do
    p = a + b - c
    pa = abs(p - a)
    pb = abs(p - b)
    pc = abs(p - c)

    cond do
      pa <= pb and pa <= pc -> a
      pb <= pc -> b
      true -> c
    end
  end
end
