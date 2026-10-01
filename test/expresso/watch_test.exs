defmodule Expresso.WatchTest do
  # The watch mode sets a global option of the compiler during each render, and
  # a failed render can make the compiler write to the global standard error.
  use ExUnit.Case, async: false

  alias Expresso.Watch

  @moduletag :tmp_dir

  # A script that returns an `Expresso.Deck` struct from `Expresso.Builder`, so
  # a render defines no module.
  defp script(text, extra \\ "") do
    """
    import Expresso.Builder

    deck(
      [
        slide("first",
          heading: "Hello",
          elements: [text_box(elements: [text_area(text: #{inspect(text)})])#{extra}]
        )
      ],
      name: "a watched deck"
    )
    """
  end

  # Start the watch mode in a process, and return the address of its page. The
  # messages of the watch mode go to a device of the test.
  defp start_watch(input, output \\ nil) do
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

  # Write a file, and set its time of change one second later than its old
  # time, so the next snapshot finds the change at once.
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

      %{url: url, device: device} = start_watch(input, output)
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

      start_watch(input)
      assert_receive {Watch, {:rendered, 1}}, 10_000
      refute_receive {Watch, {:rendered, _version}}, 500
    end

    test "keeps the last document after a failed render, and renders again after a fix",
         %{tmp_dir: dir} do
      input = Path.join(dir, "deck.exs")
      File.write!(input, script("good text"))

      %{url: url, device: device} = start_watch(input)
      assert_receive {Watch, {:rendered, 1}}, 10_000

      change(input, "deck(")
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
      File.write!(input, script("text", ", image(#{inspect(image)})"))

      start_watch(input)
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
end
