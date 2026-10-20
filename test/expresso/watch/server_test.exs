defmodule Expresso.Watch.ServerTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTTP
  import Expresso.Test.PrivateDir

  alias Expresso.Watch.Server

  setup do
    {:ok, server} = Server.start(0)
    on_exit(fn -> Server.stop(server) end)
    %{server: server}
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

  test "serves index.html for / with a query", %{server: server} do
    server = Server.publish(server, "<html><body><p>the deck</p></body></html>")

    for query <- ["?speaker=", "?scheme=dark", "?check", "?speaker=&scheme=light"] do
      assert {200, page} = get(Server.url(server) <> query)
      assert page =~ "the deck"
    end

    assert get(Server.url(server) <> "version?x") == {200, "1"}
  end

  test "serves a new directory that only its user can read", %{server: server} do
    assert Path.basename(server.directory) =~ ~r/\Aexpresso-watch-[a-z2-7]{26}\z/

    for path <- [server.directory, Path.join(server.directory, "index.html")] do
      assert File.exists?(path)
    end

    assert Bitwise.band(File.stat!(server.directory).mode, 0o777) == 0o700
  end

  test "stop/1 removes the directory" do
    {:ok, server} = Server.start(0)
    assert Server.stop(server) == :ok
    refute File.exists?(server.directory)
  end

  test "the directory goes away when the process that started the server stops" do
    test = self()

    owner =
      spawn(fn ->
        {:ok, server} = Server.start(0)
        send(test, {:server, server})
        Process.sleep(:infinity)
      end)

    assert_receive {:server, %Server{directory: directory} = server}, wait()
    on_exit(fn -> :inets.stop(:httpd, server.pid) end)
    assert File.exists?(directory)
    Process.exit(owner, :kill)

    wait_for_removal(directory)
  end

  test "listens on 127.0.0.1 only", %{server: server} do
    assert Server.url(server) =~ ~r{^http://127\.0\.0\.1:\d+/$}
    assert Keyword.fetch!(:httpd.info(server.pid), :bind_address) == {127, 0, 0, 1}
  end
end
