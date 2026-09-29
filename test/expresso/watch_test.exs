defmodule Expresso.WatchTest do
  # The watch mode sets a global option of the compiler during each render, and
  # a failed render can make the compiler write to the global standard error.
  use ExUnit.Case, async: false

  alias Expresso.Watch
  alias Expresso.Watch.{Files, Server}

  @moduletag :tmp_dir

  # A script that returns an `Expresso.Deck` struct, so a render defines no
  # module.
  defp script(text, extra \\ "") do
    """
    Expresso.Deck.new("a watched deck")
    |> Expresso.Deck.add_slide("first", %{heading: "Hello"}, [
      Expresso.Element.TextBox.new(#{inspect(text)})#{extra}
    ])
    """
  end

  # Start the watch mode in a process, and give the address of its page. The
  # messages of the watch mode go to a device of the test.
  defp start(input, output \\ nil) do
    {:ok, device} = StringIO.open("")
    test = self()

    pid =
      spawn_link(fn ->
        Watch.run(input, output,
          port: 0,
          interval: 50,
          notify: test,
          device: device,
          error_device: device
        )
      end)

    on_exit(fn -> Process.exit(pid, :kill) end)
    assert_receive {Watch, {:serving, url}}, 5_000
    %{url: url, device: device}
  end

  # Write a file with a time of change one second later than its old time, so a
  # snapshot sees the change at once.
  defp change(path, contents) do
    %File.Stat{mtime: mtime} = File.stat!(path, time: :posix)
    File.write!(path, contents)
    File.touch!(path, mtime + 1)
  end

  defp get(url) do
    {:ok, {{_version, status, _reason}, _headers, body}} =
      :httpc.request(:get, {String.to_charlist(url), []}, [], body_format: :binary)

    {status, body}
  end

  describe "run/3" do
    test "serves the deck, and serves it again after a change", %{tmp_dir: dir} do
      input = Path.join(dir, "deck.exs")
      output = Path.join(dir, "deck.html")
      File.write!(input, script("first text"))

      %{url: url, device: device} = start(input, output)
      assert_receive {Watch, {:rendered, 1}}, 10_000

      assert {200, page} = get(url)
      assert page =~ "first text"
      assert page =~ ~s(const version = "1")
      assert get(url <> "version") == {200, "1"}

      # The output file gets the document without the script of the reload.
      assert File.read!(output) =~ "first text"
      refute File.read!(output) =~ "const version"

      change(input, script("second text"))
      assert_receive {Watch, {:rendered, 2}}, 10_000

      assert {200, page} = get(url)
      assert page =~ "second text"
      assert get(url <> "version") == {200, "2"}
      assert File.read!(output) =~ "second text"

      assert {_input, messages} = StringIO.contents(device)
      assert messages =~ "Serving #{input} at #{url}"
      assert messages =~ ~r/Rendered .*deck\.exs in \d+ ms, and wrote .*deck\.html/
    end

    test "does not render again without a change", %{tmp_dir: dir} do
      input = Path.join(dir, "deck.exs")
      File.write!(input, script("text"))

      start(input)
      assert_receive {Watch, {:rendered, 1}}, 10_000
      refute_receive {Watch, {:rendered, _version}}, 500
    end

    test "keeps the last document after a failed render, and renders again after a fix",
         %{tmp_dir: dir} do
      input = Path.join(dir, "deck.exs")
      File.write!(input, script("good text"))

      %{url: url, device: device} = start(input)
      assert_receive {Watch, {:rendered, 1}}, 10_000

      change(input, "Expresso.Deck.new(")
      assert_receive {Watch, {:failed, message}}, 10_000
      assert message =~ "TokenMissingError"

      assert {200, page} = get(url)
      assert page =~ "good text"
      assert get(url <> "version") == {200, "1"}
      assert {_input, messages} = StringIO.contents(device)
      assert messages =~ ~r/Couldn't render .*deck\.exs:/

      change(input, script("fixed text"))
      assert_receive {Watch, {:rendered, 2}}, 10_000
      assert {200, page} = get(url)
      assert page =~ "fixed text"
    end

    test "renders again after a change to an image of the deck", %{tmp_dir: dir} do
      image = Path.join(dir, "dot.png")
      File.cp!("test/fixtures/dot.png", image)
      input = Path.join(dir, "deck.exs")
      File.write!(input, script("text", ",\n  Expresso.Element.Image.new(#{inspect(image)})"))

      start(input)
      assert_receive {Watch, {:rendered, 1}}, 10_000

      change(image, File.read!("test/fixtures/dot.png") <> "more bytes")
      assert_receive {Watch, {:rendered, 2}}, 10_000
    end

    test "gives an error for a port in use", %{tmp_dir: dir} do
      {:ok, socket} = :gen_tcp.listen(0, ip: {127, 0, 0, 1})
      {:ok, port} = :inet.port(socket)
      {:ok, device} = StringIO.open("")

      message = "Port #{port} is in use. Give a different port with --port."

      assert Watch.run(Path.join(dir, "deck.exs"), nil, port: port, error_device: device) ==
               {:error, message}

      assert {_input, ^message <> "\n"} = StringIO.contents(device)
      :gen_tcp.close(socket)
    end
  end

  describe "Expresso.Watch.Files" do
    test "changed?/2 compares the time, the size and two digests", %{tmp_dir: dir} do
      path = Path.join(dir, "deck.exs")
      File.write!(path, "one")
      recent = Files.snapshot([path])

      assert %{^path => {_time, 3, digest}} = recent
      refute digest == nil
      refute Files.changed?(recent, Files.snapshot([path]))

      # A change of the bytes in the same second.
      %File.Stat{mtime: mtime} = File.stat!(path, time: :posix)
      File.write!(path, "two")
      File.touch!(path, mtime)
      assert Files.changed?(recent, Files.snapshot([path]))

      # A snapshot without a digest, as for an old file, is no change.
      {time, size, _digest} = recent[path]
      refute Files.changed?(recent, %{path => {time, size, nil}})
      assert Files.changed?(recent, %{path => {time + 1, size, nil}})
    end

    test "changed?/2 sees a file that appears or goes", %{tmp_dir: dir} do
      path = Path.join(dir, "new.css")
      missing = Files.snapshot([path])
      assert missing == %{path => :missing}

      File.write!(path, "a {}")
      assert Files.changed?(missing, Files.snapshot([path]))
      assert Files.changed?(%{}, missing)
    end
  end

  describe "Expresso.Watch.Server" do
    test "serves a text before the first document, and puts the script in front of the last body end" do
      {:ok, server} = Server.start(0)
      on_exit(fn -> Server.stop(server) end)

      assert {200, page} = get(Server.url(server))
      assert page =~ "Expresso renders the deck"
      assert get(Server.url(server) <> "version") == {200, "0"}

      server = Server.publish(server, "<html><body><p>&lt;/body&gt;</p></body></html>")
      assert server.version == 1
      assert {200, page} = get(Server.url(server))
      assert [_before, after_script] = String.split(page, "</script>")
      assert after_script =~ ~r{^\s*</body></html>$}
    end

    test "listens on 127.0.0.1 only" do
      {:ok, server} = Server.start(0)
      on_exit(fn -> Server.stop(server) end)

      assert Server.url(server) =~ ~r{^http://127\.0\.0\.1:\d+/$}
      assert Keyword.fetch!(:httpd.info(server.pid), :bind_address) == {127, 0, 0, 1}
    end
  end
end
