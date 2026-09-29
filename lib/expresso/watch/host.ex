defmodule Expresso.Watch.Host do
  @moduledoc """
  Refuses a request to the watch server that names a different host

  The watch server listens on 127.0.0.1 only, so no other computer can
  connect. A web page in the browser of the user can still try DNS
  rebinding. The host name of that page first points to its own server, and
  then to 127.0.0.1. The browser then sends the requests of the page to the
  watch server, and the page can read the deck.

  Each of those requests names the host of the page in its `Host` header. This
  module passes a request only for the host `127.0.0.1` or `localhost`, with
  any port. For each other request, and for a request with no `Host` header,
  the server answers with the status 403.

  `Expresso.Watch.Server` gives this module to `:httpd` in front of the other
  modules, and `:httpd` calls `do/1` for each request.
  """

  require Record

  Record.defrecordp(:request, :mod, Record.extract(:mod, from_lib: "inets/include/httpd.hrl"))

  @hosts ["127.0.0.1", "localhost"]

  @forbidden ~c"Expresso serves the deck at http://127.0.0.1 and http://localhost only.\n"

  @doc """
  Pass a request with an allowed `Host` header to the next module

  `:httpd` calls this function with its `mod` record. The function returns
  `{:proceed, data}` for an allowed host, and a response with the status 403
  for each other request.
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

  The port does not count, because a tunnel can give the server a different
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
