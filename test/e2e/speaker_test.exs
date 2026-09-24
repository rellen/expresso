defmodule Expresso.E2E.SpeakerTest do
  use Expresso.E2E, async: false

  # Slide 1 has two steps and notes. Slide 2 has one step and no notes.
  defmodule Deck do
    use Expresso

    name "speaker deck"

    slide "with notes" do
      notes "Say hello."
      steps 2

      text_box do
        text_area(text: "One")
      end
    end

    slide "without notes" do
      text_box do
        text_area(text: "Two")
      end
    end
  end

  setup %{page: page, context: context, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))
    speaker = popup(context, fn -> press(audience, "s") end)
    %{audience: audience, speaker: speaker}
  end

  defp text(page, id), do: js(page, "document.getElementById('#{id}').textContent")

  defp marked(page) do
    js(page, """
    [...document.querySelectorAll(".handout-page[data-speaker]")]
      .map((page) => page.dataset.speaker + " " + page.dataset.slide + "." + page.dataset.step)
    """)
  end

  test "s opens the speaker view at the current step, with the notes and the next step", %{
    speaker: speaker
  } do
    assert js(speaker, "location.search") =~ "speaker"
    assert js(speaker, "document.body.dataset.view") == "speaker"
    assert marked(speaker) == ["current 1.1", "next 1.2"]
    assert text(speaker, "speaker-notes") == "Say hello."
    assert text(speaker, "speaker-position") == "Slide 1 of 2, step 1 of 2"
  end

  test "a key in the present view moves the speaker view", %{
    audience: audience,
    speaker: speaker
  } do
    audience |> keys(["j", "j"])

    wait_for(
      speaker,
      "document.getElementById('speaker-position').textContent === 'Slide 2 of 2'"
    )

    assert marked(speaker) == ["current 2.1"]
    assert text(speaker, "speaker-notes") == ""
  end

  test "a key in the speaker view moves the present view", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("j")

    wait_for(audience, "location.hash === '#1.2'")
    assert position(audience) == "1.2"
  end

  test "a click and a swipe in the speaker view move the present view", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> click(1000, 360)
    wait_for(audience, "location.hash === '#1.2'")

    speaker |> swipe({900, 600}, {600, 600})
    wait_for(audience, "location.hash === '#2.1'")

    speaker |> click(100, 600)
    wait_for(audience, "location.hash === '#1.2'")
    assert position(audience) == "1.2"
  end

  test "f in the speaker view puts only the speaker view in full screen", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("f")

    wait_for(speaker, "document.fullscreenElement === document.documentElement")
    assert js(audience, "document.fullscreenElement") == nil
    assert js(audience, "location.hash") == ""
  end

  test "b in the speaker view gives a black screen to the audience", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("b")

    wait_for(audience, "document.body.dataset.blank === 'true'")
    assert js(audience, "getComputedStyle(document.body).backgroundColor") == "rgb(0, 0, 0)"
  end

  # Two keys in one task reach the present view before the speaker view can
  # answer the first one. An echo of the first position then came back after
  # the second key, and the two windows sent the two positions to each other
  # with no end.
  test "two keys faster than a message leave both windows at the same step", %{
    audience: audience,
    speaker: speaker
  } do
    js(audience, """
    (() => {
      for (let i = 0; i < 2; i++) {
        document.dispatchEvent(new KeyboardEvent("keydown", { key: "j" }));
      }
    })()
    """)

    wait_for(speaker, "location.hash === '#2.1'")

    count =
      "window.__writes = 0; history.replaceState = ((write) => (...a) => { window.__writes++; return write(...a); })(history.replaceState.bind(history))"

    js(audience, count)
    js(speaker, count)
    Process.sleep(300)

    assert js(audience, "location.hash") == "#2.1"
    assert js(speaker, "location.hash") == "#2.1"
    assert js(audience, "window.__writes") == 0
    assert js(speaker, "window.__writes") == 0
  end
end
