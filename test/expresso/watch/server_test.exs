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

  test "publish/3 serves the copy of a file of an element with external true", %{server: server} do
    bytes = File.read!("test/fixtures/clip.webm")
    files = [{"talk_files/clip-3dc53cfe.webm", bytes}, {"talk_files/chime-3e700d6d.wav", "RIFF"}]
    server = Server.publish(server, "<html><body><p>the deck</p></body></html>", files)

    assert get(Server.url(server) <> "talk_files/clip-3dc53cfe.webm") == {200, bytes}
    assert get(Server.url(server) <> "talk_files/chime-3e700d6d.wav") == {200, "RIFF"}

    # The browser asks for the kind of the file.
    answer = raw_get(server.port, "/talk_files/clip-3dc53cfe.webm")
    assert answer =~ ~r/\AHTTP\/1\.[01] 200/
    assert answer =~ ~r/content-type: video\/webm/i

    answer = raw_get(server.port, "/talk_files/chime-3e700d6d.wav")
    assert answer =~ ~r/content-type: audio\/wav/i
  end

  # Ask for a range of a file of the server over HTTP/1.1, as a browser does,
  # and return the status, the headers and the body. `:httpd` gives the
  # status 206 only to a request of HTTP/1.1.
  defp ranged(server, path, range) do
    url = String.to_charlist(Server.url(server) <> path)

    {:ok, {{_version, status, _reason}, headers, body}} =
      :httpc.request(:get, {url, [{~c"range", String.to_charlist(range)}]}, [],
        body_format: :binary
      )

    {status, Map.new(headers, fn {name, value} -> {to_string(name), to_string(value)} end), body}
  end

  test "sends a part of a copy for a request with a range", %{server: server} do
    files = [{"talk_files/run-ba7816bf.webm", "0123456789"}]
    server = Server.publish(server, "<html><body></body></html>", files)
    path = "talk_files/run-ba7816bf.webm"

    assert {206, headers, "2345"} = ranged(server, path, "bytes=2-5")
    # A browser refuses `bytes=2-5/10`, which `mod_range` of OTP writes.
    assert headers["content-range"] == "bytes 2-5/10"
    assert headers["content-length"] == "4"
    assert headers["content-type"] == "video/webm"
    assert headers["accept-ranges"] == "bytes"

    # A browser asks for the file from its start, and from a later byte.
    assert {206, %{"content-range" => "bytes 0-9/10"}, "0123456789"} =
             ranged(server, path, "bytes=0-")

    assert {206, %{"content-range" => "bytes 6-9/10"}, "6789"} = ranged(server, path, "bytes=6-")
    assert {206, %{"content-range" => "bytes 7-9/10"}, "789"} = ranged(server, path, "bytes=-3")
  end

  test "sends the whole file for a range that the file does not have", %{server: server} do
    files = [{"talk_files/run-ba7816bf.webm", "0123456789"}]
    server = Server.publish(server, "<html><body></body></html>", files)

    for range <- ["bytes=20-", "bytes=0-1,4-5", "items=0-1"] do
      assert {200, _headers, "0123456789"} =
               ranged(server, "talk_files/run-ba7816bf.webm", range),
             range
    end
  end

  test "a request with a range for a file that is not there gets the status 404", %{
    server: server
  } do
    assert {404, _headers, _body} = ranged(server, "talk_files/none.webm", "bytes=0-")
  end

  test "a request with a range does not go out of the directory of the server", %{
    server: server
  } do
    outside = Path.join(Path.dirname(server.directory), "expresso-outside-#{server.port}.txt")
    File.write!(outside, "the content of a file outside")
    on_exit(fn -> File.rm(outside) end)

    answer =
      raw_get(
        server.port,
        "/../" <> Path.basename(outside),
        "Host: 127.0.0.1\r\nRange: bytes=0-\r\n"
      )

    refute answer =~ "the content of a file outside"
    refute answer =~ ~r/\AHTTP\/1\.[01] 20[06]/
  end

  test "a copy of an earlier document stays, and a new document adds its copies", %{
    server: server
  } do
    server = Server.publish(server, "<html><body></body></html>", [{"t_files/a-1.webm", "a"}])
    server = Server.publish(server, "<html><body></body></html>", [{"t_files/b-2.webm", "b"}])

    assert get(Server.url(server) <> "t_files/a-1.webm") == {200, "a"}
    assert get(Server.url(server) <> "t_files/b-2.webm") == {200, "b"}
    assert server.version == 2
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
