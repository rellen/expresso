defmodule Expresso.Gif.Png do
  @moduledoc """
  Reads the size and the filtered rows of a PNG image of 8-bit RGB

  Chromium writes each screenshot in this format. `:zlib` inflates the data.
  `Expresso.Gif.Nif.unfilter/3` then removes the filter of each row.
  """

  @doc "Return the width, the height and the filtered rows of a PNG image"
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
      {"IHDR", _data} -> {:error, "the PNG image is not 8-bit RGB with no interlace"}
      {"IDAT", _data} -> chunks(rest, size, [idat, data])
      {"IEND", _data} -> rows(size, idat)
      _other -> chunks(rest, size, idat)
    end
  end

  defp chunks(_data, _size, _idat), do: {:error, "the PNG image is damaged"}

  defp rows(nil, _idat), do: {:error, "the PNG image has no IHDR chunk"}

  defp rows({width, height}, idat) do
    case uncompress(idat) do
      {:ok, rows} when byte_size(rows) == height * (width * 3 + 1) -> {:ok, {width, height, rows}}
      _other -> {:error, "the PNG image is damaged"}
    end
  end

  defp uncompress(idat) do
    {:ok, :zlib.uncompress(idat)}
  rescue
    ErlangError -> :error
  end
end
