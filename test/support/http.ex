defmodule Expresso.Test.HTTP do
  @moduledoc """
  Sends the HTTP requests of the tests of the watch mode and of the binary

  `get/1` uses `:httpc`. `raw_get/3` writes the request to a TCP socket, so
  the test controls each header, and the binary tests do not start `:httpc`,
  which changes the monotonic counter of the VM.
  """

  @doc """
  Get a URL, and return the status and the body
  """
  @spec get(String.t()) :: {pos_integer(), binary()}
  def get(url) do
    {:ok, {{_version, status, _reason}, _headers, body}} =
      :httpc.request(:get, {String.to_charlist(url), []}, [], body_format: :binary)

    {status, body}
  end

  @doc """
  Send `GET path` over HTTP/1.0 to a port of 127.0.0.1, and return the whole
  answer, with its status line and its headers

  `headers` is the text of the headers, each with `\\r\\n` at its end.
  """
  @spec raw_get(:inet.port_number(), String.t(), String.t()) :: binary()
  def raw_get(port, path, headers \\ "Host: 127.0.0.1\r\n") do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false])
    :ok = :gen_tcp.send(socket, ["GET ", path, " HTTP/1.0\r\n", headers, "\r\n"])
    answer = receive_all(socket, "")
    :gen_tcp.close(socket)
    answer
  end

  defp receive_all(socket, answer) do
    case :gen_tcp.recv(socket, 0, 10_000) do
      {:ok, data} -> receive_all(socket, answer <> data)
      {:error, :closed} -> answer
    end
  end
end
