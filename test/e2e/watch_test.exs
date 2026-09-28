defmodule Expresso.E2E.WatchTest do
  use Expresso.E2E, async: false

  # A deck with two slides from a script, so a render defines no module.
  defp script(text) do
    """
    Expresso.Deck.new("a watched deck")
    |> Expresso.Deck.add_slide("one", %{heading: "One"}, [
      Expresso.Element.TextBox.new("the first slide")
    ])
    |> Expresso.Deck.add_slide("two", %{heading: "Two"}, [
      Expresso.Element.TextBox.new(#{inspect(text)})
    ])
    """
  end

  setup %{tmp_dir: tmp_dir} do
    input = Path.join(tmp_dir, "deck.exs")
    File.write!(input, script("the old text"))
    {:ok, device} = StringIO.open("")
    test = self()

    pid =
      spawn_link(fn ->
        Expresso.Watch.run(input, nil,
          port: 0,
          interval: 50,
          notify: test,
          device: device,
          error_device: device
        )
      end)

    on_exit(fn -> Process.exit(pid, :kill) end)
    assert_receive {Expresso.Watch, {:serving, url}}, 5_000
    assert_receive {Expresso.Watch, {:rendered, 1}}, 10_000
    %{input: input, url: url}
  end

  test "the page reloads after a change, and it shows the same step", %{
    page: page,
    input: input,
    url: url
  } do
    page = page |> open(url) |> press("j")
    assert position(page) == "2.1"
    assert js(page, "document.body.innerText.includes('the old text')")

    # A time of change one second later, so the next snapshot sees it.
    %File.Stat{mtime: mtime} = File.stat!(input, time: :posix)
    File.write!(input, script("the new text"))
    File.touch!(input, mtime + 1)
    assert_receive {Expresso.Watch, {:rendered, 2}}, 10_000

    page |> wait_for("document.body.innerText.includes('the new text')")
    assert position(page) == "2.1"
    assert js(page, "location.hash") == "#2.1"
  end
end
