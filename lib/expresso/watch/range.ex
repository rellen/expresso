defmodule Expresso.Watch.Range do
  @moduledoc """
  Sends a part of a file of the watch server for a request with a `Range` header

  A browser asks for a part of a video file or of a sound file, so it can go
  to a time of the file before the whole file arrives. A `video` or an
  `audio` element with `external true` keeps its file next to the document,
  and the watch server sends that file. `Expresso.MediaFiles` gives the rules
  of such a file.

  `mod_range` of OTP writes the header `Content-Range: bytes=2-5/10`. The
  form of RFC 9110 is `bytes 2-5/10`, and a browser refuses the first form.
  Therefore this module answers the request.

  The module answers a request for one range: `bytes=2-5`, `bytes=2-` and
  `bytes=-4`. Each other request goes to the next module, which sends the
  whole file. `Expresso.Watch.Server` puts this module after `mod_alias` and
  in front of `mod_get` in the `:httpd` module list.
  """

  require Record

  Record.defrecordp(:request, :mod, Record.extract(:mod, from_lib: "inets/include/httpd.hrl"))

  @doc """
  Answer a `GET` request for one range of a file with that part of the file

  `:httpd` calls this function with its `mod` record. The function returns a
  response with the status 206 for a range that the file has. It passes each
  other request to the next module.
  """
  @spec unquote(:do)(tuple()) :: {:proceed, list()}
  def unquote(:do)(request) do
    data = request(request, :data)
    header = :proplists.get_value(~c"range", request(request, :parsed_header), nil)

    with ~c"GET" <- request(request, :method),
         true <- header != nil,
         path = path(request),
         {:ok, %File.Stat{type: :regular, size: size}} <- File.stat(path),
         {:ok, {first, last}} <- range(to_string(header), size),
         {:ok, bytes} <- part(path, first, last - first + 1) do
      head = [
        code: 206,
        content_type: type(request, path),
        content_length: Integer.to_charlist(byte_size(bytes)),
        content_range: String.to_charlist("bytes #{first}-#{last}/#{size}"),
        accept_ranges: ~c"bytes"
      ]

      {:proceed, [{:response, {:response, head, bytes}} | data]}
    else
      _no_range -> {:proceed, data}
    end
  end

  @doc """
  Return the first byte and the last byte of the one range of a `Range`
  header, for a file of a size

  The function returns `:error` for a header with more than one range, for a
  unit other than `bytes`, and for a range that the file does not have. A
  range past the end of the file stops at the last byte.

      iex> Expresso.Watch.Range.range("bytes=2-5", 10)
      {:ok, {2, 5}}
      iex> Expresso.Watch.Range.range("bytes=2-", 10)
      {:ok, {2, 9}}
      iex> Expresso.Watch.Range.range("bytes=-4", 10)
      {:ok, {6, 9}}
      iex> Expresso.Watch.Range.range("bytes=2-99", 10)
      {:ok, {2, 9}}
      iex> Expresso.Watch.Range.range("bytes=10-", 10)
      :error
      iex> Expresso.Watch.Range.range("bytes=5-2", 10)
      :error
      iex> Expresso.Watch.Range.range("bytes=0-1,4-5", 10)
      :error
      iex> Expresso.Watch.Range.range("items=0-1", 10)
      :error
  """
  @spec range(String.t(), non_neg_integer()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | :error
  def range(header, size) do
    case Regex.run(~r/\A\s*bytes\s*=\s*(\d*)-(\d*)\s*\z/, header, capture: :all_but_first) do
      [first, last] -> bounds(first, last, size)
      _other -> :error
    end
  end

  # The last bytes of the file, for a range with no first byte.
  defp bounds("", "", _size), do: :error

  defp bounds("", count, size) do
    count = String.to_integer(count)
    if count > 0 and size > 0, do: {:ok, {max(size - count, 0), size - 1}}, else: :error
  end

  defp bounds(first, last, size) do
    first = String.to_integer(first)
    last = if last == "", do: size - 1, else: min(String.to_integer(last), size - 1)
    if first <= last, do: {:ok, {first, last}}, else: :error
  end

  # The path of the file of a request. `mod_alias` ran before this module,
  # and `:httpd` refused a request that goes out of the directory of the
  # server.
  defp path(request) do
    data = request(request, :data)
    config = request(request, :config_db)
    data |> :mod_alias.path(config, request(request, :request_uri)) |> to_string()
  end

  defp type(request, path) do
    suffix = path |> Path.extname() |> String.trim_leading(".") |> String.to_charlist()
    :httpd_util.lookup_mime_default(request(request, :config_db), suffix, ~c"text/plain")
  end

  # The path comes from `mod_alias`, as the path of `mod_get` does.
  # sobelow_skip ["Traversal.FileModule"]
  defp part(path, first, length) do
    with {:ok, file} <- :file.open(path, [:read, :raw, :binary]) do
      try do
        :file.pread(file, first, length)
      after
        :file.close(file)
      end
    end
  end
end
