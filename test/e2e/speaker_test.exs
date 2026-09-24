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

  test "b in the speaker view gives a black screen to the audience", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("b")

    wait_for(audience, "document.body.dataset.blank === 'true'")
    assert js(audience, "getComputedStyle(document.body).backgroundColor") == "rgb(0, 0, 0)"
  end
end
