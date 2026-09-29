defmodule Expresso.Watch.Host do
  @moduledoc """
  Refuses a request for a host other than 127.0.0.1 or localhost

  The watch server listens on 127.0.0.1 only, so no other computer can
  connect. But a web page that the user opens can try DNS rebinding:

  1. The page's host name points to the page's own server.
  2. The host name then changes to point to 127.0.0.1.
  3. The browser now sends the page's requests to the watch server, and the
     page can read the deck.

  Each such request still has the page's host name in its `Host` header. This
  module passes a request only when that header is `127.0.0.1` or
  `localhost`, with any port. The server answers each other request, and a
  request with no `Host` header, with the status 403.

  `Expresso.Watch.Server` puts this module first in the `:httpd` module list,
  and `:httpd` calls `do/1` for each request.
  """

  require Record

  Record.defrecordp(:request, :mod, Record.extract(:mod, from_lib: "inets/include/httpd.hrl"))

  @hosts ["127.0.0.1", "localhost"]

  @forbidden ~c"Expresso serves the deck at http://127.0.0.1 and http://localhost only.\n"

  @doc """
  Pass a request with an allowed `Host` header to the next module

  `:httpd` calls this function with its `mod` record. The function returns
  `{:proceed, data}` for an allowed host, and a 403 response otherwise.
  """
  @spec unquote(:do)(tuple()) :: {:proceed, list()} | {:break, [{:response, {403, charlist()}}]}
  def unquote(:do)(request) do
    host = :proplists.get_value(~c"host", request(request, :parsed_header), nil)

    if host != nil and allowed?(to_string(host)),
      do: {:proceed, request(request, :data)},
      else: {:break, [response: {403, @forbidden}]}
  end

  @doc """
  Tell whether the value of a `Host` header names this computer

  The port is not part of the check, because a tunnel can use a different
  port.

      iex> Expresso.Watch.Host.allowed?("127.0.0.1:4100")
      true

      iex> Expresso.Watch.Host.allowed?("LocalHost:8080")
      true

      iex> Expresso.Watch.Host.allowed?("localhost")
      true

      iex> Expresso.Watch.Host.allowed?("attacker.example:4100")
      false

      iex> Expresso.Watch.Host.allowed?("localhost.attacker.example")
      false
  """
  @spec allowed?(String.t()) :: boolean()
  def allowed?(host) do
    name = host |> String.downcase() |> String.split(":") |> hd()
    name in @hosts
  end
end
