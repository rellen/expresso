defmodule Expresso.E2E.NotesTest do
  use Expresso.E2E, async: false

  # Slide 1 has three steps, a note for each step and a note for step 2 and
  # for step 3. Slide 2 has two steps, and the handout view shows only the
  # last one.
  defmodule Deck do
    use Expresso

    name "notes deck"

    slide "steps" do
      notes """
      Start **slow**.

      - Say hello
      - Give your name
      """

      text_box do
        text_area(text: "One")
      end

      text_box do
        at from: 2
        text_area(text: "Two")
      end

      text_box do
        at from: 3
        text_area(text: "Three")
      end

      note "Ask the *room*.", at: 2
      note "Show `42` and [the book](https://example.com/book).", at: 3
    end

    slide "last" do
      handout :last

      text_box do
        text_area(text: "One")
      end

      text_box do
        at from: 2
        text_area(text: "Two")
      end

      note "At step one.", at: 1
      note "At step two.", at: 2
    end
  end

  setup %{page: page, context: context, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))
    speaker = popup(context, fn -> press(audience, "s") end)
    %{audience: audience, speaker: speaker}
  end

  # The text of each note of the speaker view.
  defp notes(page) do
    js(page, """
    [...document.querySelectorAll("#speaker-notes > .note")].map((note) => note.innerText.trim())
    """)
  end

  defp count(page, selector),
    do: js(page, "document.querySelectorAll(#{JSON.encode!(selector)}).length")

  defp wait_for_step(page, position),
    do:
      wait_for(page, "document.getElementById('speaker-position').textContent === '#{position}'")

  # The text of each note that shows on the page of a step, in the handout
  # view.
  defp shown(page, slide, step) do
    js(page, """
    [...document.querySelectorAll('.handout-page[data-slide="#{slide}"][data-step="#{step}"] .note')]
      .filter((note) => note.checkVisibility())
      .map((note) => note.innerText.trim())
    """)
  end

  test "the speaker view shows the note of the slide with its markup", %{speaker: speaker} do
    assert notes(speaker) == ["Start slow.\n\nSay hello\nGive your name"]
    assert count(speaker, "#speaker-notes strong") == 1
    assert count(speaker, "#speaker-notes ul > li") == 2
  end

  test "the speaker view shows the note of the current step under the note of the slide", %{
    speaker: speaker
  } do
    speaker |> press("j")
    wait_for_step(speaker, "Slide 1 of 2, step 2 of 3")

    assert notes(speaker) == ["Start slow.\n\nSay hello\nGive your name", "Ask the room."]
    assert count(speaker, "#speaker-notes em") == 1

    speaker |> press("j")
    wait_for_step(speaker, "Slide 1 of 2, step 3 of 3")

    assert notes(speaker) == [
             "Start slow.\n\nSay hello\nGive your name",
             "Show 42 and the book."
           ]

    assert count(speaker, "#speaker-notes code") == 1

    assert js(speaker, ~s|document.querySelector("#speaker-notes a").getAttribute("href")|) ==
             "https://example.com/book"

    speaker |> press("k")
    wait_for_step(speaker, "Slide 1 of 2, step 2 of 3")
    assert List.last(notes(speaker)) == "Ask the room."
  end

  test "the speaker view leaves out a note of an earlier step", %{speaker: speaker} do
    speaker |> keys(["j", "j", "j", "j"])
    wait_for_step(speaker, "Slide 2 of 2, step 2 of 2")

    assert notes(speaker) == ["At step two."]
    assert count(speaker, "#speaker-notes [data-covered]") == 0
  end

  test "a key in the present view changes the note of the speaker view", %{
    audience: audience,
    speaker: speaker
  } do
    audience |> press("j")
    wait_for_step(speaker, "Slide 1 of 2, step 2 of 3")

    assert List.last(notes(speaker)) == "Ask the room."
  end

  test "a page of the handout view shows the notes of its step", %{audience: audience} do
    audience |> press("p")

    assert shown(audience, 1, 1) == ["Start slow.\n\nSay hello\nGive your name"]
    assert List.last(shown(audience, 1, 2)) == "Ask the room."
    assert List.last(shown(audience, 1, 3)) == "Show 42 and the book."
  end

  test "a page of the handout view shows the notes of the steps with no page, with a label", %{
    audience: audience
  } do
    audience |> press("p")

    assert shown(audience, 2, 1) == []
    assert shown(audience, 2, 2) == ["Step 1\n\nAt step one.", "At step two."]
  end

  test "with each page in view, a note shows only on the page of its step", %{audience: audience} do
    audience |> keys(["p", "a"])

    assert shown(audience, 2, 1) == ["At step one."]
    assert shown(audience, 2, 2) == ["At step two."]
  end
end
