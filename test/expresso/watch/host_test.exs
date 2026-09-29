defmodule Expresso.Watch.HostTest do
  use ExUnit.Case, async: true

  alias Expresso.Watch.Server

  doctest Expresso.Watch.Host

  setup do
    {:ok, server} = Server.start(0)
    on_exit(fn -> Server.stop(server) end)
    %{port: server.port}
  end

  # A request with HTTP/1.0 and the lines of `headers`, so the test sets the
  # `Host` header itself, and the server closes the connection after the
  # answer.
  defp get(port, headers) do
    {:ok, socket} = :gen_tcp.connect({127, 0, 0, 1}, port, [:binary, active: false])
    :ok = :gen_tcp.send(socket, ["GET /version HTTP/1.0\r\n", headers, "\r\n"])
    answer = receive_all(socket, "")
    :gen_tcp.close(socket)
    answer
  end

  defp receive_all(socket, answer) do
    case :gen_tcp.recv(socket, 0, 5_000) do
      {:ok, data} -> receive_all(socket, answer <> data)
      {:error, :closed} -> answer
    end
  end

  test "answers a request for 127.0.0.1 or localhost, with any port", %{port: port} do
    for host <- ["127.0.0.1:#{port}", "localhost:#{port}", "localhost:8080", "LOCALHOST"] do
      assert get(port, "Host: #{host}\r\n") =~ ~r{\AHTTP/1\.[01] 200 .*\r\n\r\n0\z}s
    end
  end

  test "refuses a request for a different host with the status 403", %{port: port} do
    for host <- ["attacker.example:#{port}", "localhost.attacker.example", "127.0.0.2"] do
      answer = get(port, "Host: #{host}\r\n")
      assert answer =~ ~r{\AHTTP/1\.[01] 403 }
      assert answer =~ "Expresso serves the deck at http://127.0.0.1 and http://localhost only."
    end
  end

  test "refuses a request with no Host header", %{port: port} do
    assert get(port, "") =~ ~r{\AHTTP/1\.[01] 403 }
  end
end
