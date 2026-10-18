defmodule Expresso.E2E.WatchTest do
  use Expresso.E2E, async: false

  # A deck with two slides from a script, so a render defines no module.
  defp script(text) do
    """
    import Expresso.Builder

    box = &text_box(elements: [text_area(text: &1)])

    deck(
      [
        slide("one", heading: "One", elements: [box.("the first slide")]),
        slide("two", heading: "Two", elements: [box.(#{inspect(text)})])
      ],
      name: "a watched deck"
    )
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

  # `s` opens the address with `?speaker=`. The watch server serves
  # `index.html` for it, so the speaker view shows the deck and reloads too.
  test "s opens the speaker view, and the speaker view reloads after a change", %{
    page: page,
    context: context,
    input: input,
    url: url
  } do
    audience = open(page, url)
    speaker = popup(context, fn -> press(audience, "s") end)

    assert js(speaker, "location.search") =~ "speaker"
    assert js(speaker, "document.body.dataset.view") == "speaker"
    assert js(speaker, "document.body.innerText.includes('the first slide')")

    %File.Stat{mtime: mtime} = File.stat!(input, time: :posix)
    File.write!(input, script("the new text"))
    File.touch!(input, mtime + 1)
    assert_receive {Expresso.Watch, {:rendered, 2}}, 10_000

    speaker
    |> wait_for("document.body.dataset.view === 'speaker'")
    |> wait_for("document.body.innerText.includes('the new text')")
  end
end
