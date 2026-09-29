defmodule Expresso.Watch.ServerTest do
  use ExUnit.Case, async: true

  alias Expresso.Watch.Server

  setup do
    {:ok, server} = Server.start(0)
    on_exit(fn -> Server.stop(server) end)
    %{server: server}
  end

  defp get(url) do
    {:ok, {{_version, status, _reason}, _headers, body}} =
      :httpc.request(:get, {String.to_charlist(url), []}, [], body_format: :binary)

    {status, body}
  end

  test "serves a short text and the version 0 before the first document", %{server: server} do
    assert {200, page} = get(Server.url(server))
    assert page =~ "Expresso renders the deck"
    assert get(Server.url(server) <> "version") == {200, "0"}
  end

  test "publish/2 serves the document with the next version", %{server: server} do
    server = Server.publish(server, "<html><body><p>the deck</p></body></html>")

    assert server.version == 1
    assert {200, page} = get(Server.url(server))
    assert page =~ "the deck"
    assert page =~ ~s(const version = "1")
    assert get(Server.url(server) <> "version") == {200, "1"}
  end

  test "publish/2 puts the reload script in front of the last </body>", %{server: server} do
    server = Server.publish(server, "<html><body><p>&lt;/body&gt;</p></body></html>")

    assert {200, page} = get(Server.url(server))
    assert [_before, after_script] = String.split(page, "</script>")
    assert after_script =~ ~r{^\s*</body></html>$}
  end

  test "listens on 127.0.0.1 only", %{server: server} do
    assert Server.url(server) =~ ~r{^http://127\.0\.0\.1:\d+/$}
    assert Keyword.fetch!(:httpd.info(server.pid), :bind_address) == {127, 0, 0, 1}
  end
end
