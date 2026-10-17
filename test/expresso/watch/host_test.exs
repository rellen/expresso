defmodule Expresso.Watch.HostTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTTP

  alias Expresso.Watch.Server

  doctest Expresso.Watch.Host

  setup do
    {:ok, server} = Server.start(0)
    on_exit(fn -> Server.stop(server) end)
    %{port: server.port}
  end

  # Send a raw request, so that the test controls the `Host` header. HTTP/1.0
  # makes the server close the connection after the answer.
  test "answers a request for 127.0.0.1 or localhost, with any port", %{port: port} do
    for host <- ["127.0.0.1:#{port}", "localhost:#{port}", "localhost:8080", "LOCALHOST"] do
      assert raw_get(port, "/version", "Host: #{host}\r\n") =~
               ~r{\AHTTP/1\.[01] 200 .*\r\n\r\n0\z}s
    end
  end

  test "refuses a request for a different host with the status 403", %{port: port} do
    for host <- ["attacker.example:#{port}", "localhost.attacker.example", "127.0.0.2"] do
      answer = raw_get(port, "/version", "Host: #{host}\r\n")
      assert answer =~ ~r{\AHTTP/1\.[01] 403 }
      assert answer =~ "Expresso serves the deck at http://127.0.0.1 and http://localhost only."
    end
  end

  test "refuses a request with no Host header", %{port: port} do
    assert raw_get(port, "/version", "") =~ ~r{\AHTTP/1\.[01] 403 }
  end
end
