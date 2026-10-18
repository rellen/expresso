defmodule Expresso.E2E.TwoWindowsTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.Frame

  # Slide 1 has two steps. The theme has a light and a dark variant, so the
  # key t changes the variant.
  defmodule Deck do
    use Expresso

    name "two windows deck"
    theme dark: :dracula, light: :default

    slide "one" do
      steps 2

      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      text_box do
        text_area(text: "Two")
      end
    end

    slide "three" do
      text_box do
        text_area(text: "Three")
      end
    end

    slide "four" do
      text_box do
        text_area(text: "Four")
      end
    end
  end

  setup %{tmp_dir: tmp_dir} do
    %{url: render(Deck, tmp_dir)}
  end

  defp speaker(context, audience), do: popup(context, fn -> press(audience, "s") end)

  defp blank(page), do: js(page, "document.body.dataset.blank === 'true'")
  defp scheme(page), do: js(page, "document.documentElement.dataset.scheme ?? null")

  # Press a key on the element of a selector. `press/2` presses the key on the
  # `body`, which is behind the dialog of the list of keys.
  defp press_on(page, selector, key) do
    {:ok, _result} =
      Frame.press(page.main_frame.guid, timeout: 10_000, selector: selector, key: key)

    page
  end

  test "a frame of the document cannot control the present view", %{
    page: page,
    context: context,
    url: url
  } do
    audience = open(page, url <> "#2.1")

    js(audience, """
    (() => {
      const frame = document.createElement("iframe");
      frame.srcdoc = `<script>parent.postMessage({expresso: "position", slide: 3, step: 1,
        fields: {blank: true}, scheme: "dark", time: 1e15}, "*")<\\/script>`;
      document.body.append(frame);
    })()
    """)

    Process.sleep(300)
    assert js(audience, "location.hash") == "#2.1"
    refute blank(audience)

    speaker = speaker(context, audience)
    speaker |> press("j")

    wait_for(audience, "location.hash === '#3.1'")
    assert js(speaker, "location.hash") == "#3.1"
  end

  test "a reload of the speaker view keeps the black screen of the present view", %{
    page: page,
    context: context,
    url: url
  } do
    audience = open(page, url)
    speaker = speaker(context, audience)
    audience |> press("j") |> press("b")
    wait_for(speaker, "document.body.dataset.blank === 'true'")

    reload(speaker)

    wait_for(speaker, "document.body.dataset.blank === 'true'")
    Process.sleep(300)
    assert blank(audience)
    assert js(audience, "location.hash") == "#1.2"
  end

  test "a reload of the speaker view keeps the variant of the present view", %{
    page: page,
    context: context,
    url: url
  } do
    audience = open(page, url)
    audience |> press("j")
    speaker = speaker(context, audience)
    speaker |> press("t")
    wait_for(audience, "document.documentElement.dataset.scheme === 'dark'")
    # The address of the speaker view gives no variant.
    assert js(speaker, "location.search") == "?speaker="

    reload(speaker)

    wait_for(speaker, "document.documentElement.dataset.scheme === 'dark'")
    Process.sleep(300)
    assert scheme(audience) == "dark"
  end

  test "a second s after t shows the speaker view again, and does not load it again", %{
    page: page,
    context: context,
    url: url
  } do
    audience = open(page, url)
    speaker = speaker(context, audience)
    audience |> press("j")
    wait_for(speaker, "location.hash === '#1.2'")
    js(speaker, "window.__loaded = true")
    Process.sleep(1100)

    audience |> press("t") |> press("s")

    Process.sleep(300)
    assert js(speaker, "window.__loaded") == true
    assert js(speaker, "location.search") == "?speaker="
    refute js(speaker, "document.getElementById('speaker-timer').textContent") == "0:00"
  end

  test "the timer of a speaker view that opens at slide 3 waits for the first change", %{
    page: page,
    context: context,
    url: url
  } do
    audience = open(page, url <> "#3.1")
    speaker = speaker(context, audience)

    Process.sleep(1300)
    assert js(speaker, "document.getElementById('speaker-timer').textContent") == "0:00"

    audience |> press("j")
    wait_for(speaker, "document.getElementById('speaker-timer').textContent === '0:01'")
  end

  test "Tab, Enter and the space bar in the list of keys open a section, and the list stays open",
       %{page: page, url: url} do
    page = open(page, url)
    page |> press("Shift+Slash")
    assert js(page, "document.activeElement.id") == "help-filter"

    page |> press_on("#help-filter", "Tab") |> press_on("*:focus", "Tab")

    assert js(page, "document.getElementById('help').open")
    assert js(page, "document.activeElement.tagName") == "SUMMARY"
    assert js(page, "document.activeElement.parentElement.open") == false

    page |> press_on("*:focus", "Enter")
    assert js(page, "document.activeElement.parentElement.open")

    page |> press_on("*:focus", " ")
    assert js(page, "document.activeElement.parentElement.open") == false
    assert js(page, "document.body.dataset.help") == "true"
    assert position(page) == "1.1"
  end
end
