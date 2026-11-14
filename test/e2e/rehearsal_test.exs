defmodule Expresso.E2E.RehearsalTest do
  use Expresso.E2E, async: false

  # Three slides. The slide "intro" has two steps, and each step has a time
  # of 5 seconds from the `advance` option.
  defmodule Deck do
    use Expresso

    name "rehearsal deck"
    advance 5_000

    slide "intro" do
      steps 2

      text_box do
        text_area(text: "Intro")
      end
    end

    slide "body" do
      text_box do
        text_area(text: "Body")
      end
    end

    slide "end" do
      text_box do
        text_area(text: "End")
      end
    end
  end

  # The clock of each page at the start of a test, in milliseconds.
  @start 1_767_258_000_000

  # The time of two looks of the present view at the clock.
  @looks 600

  setup %{context: context} do
    fix_clock(context, @start)
    :ok
  end

  defp windows(%{page: page, context: context, tmp_dir: tmp_dir}, parameters) do
    audience = open(page, render(Deck, tmp_dir) <> parameters)
    speaker = popup(context, fn -> press(audience, "s") end)
    {audience, speaker}
  end

  @open "document.getElementById('times').open"

  defp text(page, id), do: js(page, "document.getElementById(#{JSON.encode!(id)}).textContent")

  # The text of each cell of each row of the table.
  defp table(page) do
    js(page, """
    [...document.querySelectorAll("#times-rows tr")]
      .map((row) => [...row.children].map((cell) => cell.textContent))
    """)
  end

  # Press the key of the next step in the speaker view after a time of the
  # clock.
  defp next_after(speaker, context, time, position) do
    fix_clock(context, @start + time)
    speaker |> press("j")
    wait_for_position(speaker, position)
    speaker
  end

  test "the rehearsal records the time of each slide and gives the lines of the option",
       context do
    {audience, speaker} = windows(context, "?rehearse")

    assert text(speaker, "speaker-advance") == "Rehearsal. Press e for the time of each slide."

    # The timer starts at the first change of the step, so step 1 of the
    # slide "intro" has no time.
    speaker
    |> next_after(context.context, 4_000, "1.2")
    |> next_after(context.context, 16_300, "2.1")
    |> next_after(context.context, 91_300, "3.1")

    fix_clock(context.context, @start + 100_300)
    speaker |> press("e")
    wait_for(speaker, @open)

    assert text(speaker, "times-total") == "The talk used 1:36."

    assert table(speaker) == [
             [~s(slide "intro"), "2", "0:12"],
             [~s(slide "body"), "1", "1:15"],
             [~s(slide "end"), "1", "0:09"]
           ]

    assert text(speaker, "times-code") == """
           # The time of each slide of a talk of 1:36.
           # Put each line into its slide.

           # slide "intro"
           # Step 1 has no time in the record, and 1 second here.
           advance [1_000, 12_000]

           # slide "body"
           advance 75_000

           # slide "end"
           advance 9_000
           """

    # The present view shows no table.
    assert js(audience, @open) == false
  end

  test "the clock of the steps does not run in a rehearsal", context do
    {audience, speaker} = windows(context, "?rehearse")

    speaker |> press("j")
    wait_for_position(audience, "1.2")

    # Each step has a time of 5 seconds.
    fix_clock(context.context, @start + 60_000)
    Process.sleep(@looks)
    assert position(audience) == "1.2"
    assert position(speaker) == "1.2"
  end

  test "Escape closes the table, and a key in the table does not change the step", context do
    {_audience, speaker} = windows(context, "?rehearse")

    speaker |> press("j") |> press("e")
    wait_for(speaker, @open)

    # The focus is in the dialog, so the key goes to the browser.
    assert js(speaker, "document.getElementById('times').contains(document.activeElement)")
    speaker |> press_focused("j")
    assert position(speaker) == "1.2"
    assert js(speaker, @open)

    speaker |> press_focused("Escape")
    wait_for(speaker, "!#{@open}")
    assert position(speaker) == "1.2"

    # The keys move again after the table.
    speaker |> press("j")
    wait_for_position(speaker, "2.1")
  end

  test "a click outside the table closes it, and the step stays", context do
    {_audience, speaker} = windows(context, "?rehearse")

    speaker |> press("j") |> press("e")
    wait_for(speaker, @open)

    speaker |> click(5, 5)
    wait_for(speaker, "!#{@open}")
    assert position(speaker) == "1.2"
  end

  test "one click on the lines selects each of them", context do
    {_audience, speaker} = windows(context, "?rehearse")

    speaker
    |> next_after(context.context, 1_000, "1.2")
    |> next_after(context.context, 9_000, "2.1")

    speaker |> press("e")
    wait_for(speaker, @open)

    [left, top, width, height] =
      js(speaker, """
      (() => {
        const box = document.querySelector("#times pre").getBoundingClientRect();
        return [box.left, box.top, box.width, box.height];
      })()
      """)

    speaker |> click(left + width / 2, top + height / 2)

    assert js(speaker, "getSelection().toString().trim()") ==
             String.trim(text(speaker, "times-code"))

    assert js(speaker, @open)
  end

  test "r starts a new record", context do
    {_audience, speaker} = windows(context, "?rehearse")

    speaker
    |> next_after(context.context, 1_000, "1.2")
    |> next_after(context.context, 9_000, "2.1")

    speaker |> press("r") |> press("e")
    wait_for(speaker, @open)

    assert text(speaker, "times-total") ==
             "No time yet. The timer starts at the first change of the step."

    assert Enum.map(table(speaker), &List.last/1) == ["No time", "No time", "No time"]
  end

  test "the speaker view of a talk with no rehearsal also records the times", context do
    {audience, speaker} = windows(context, "?paused")

    assert text(speaker, "speaker-advance") == "Clock stopped, 0:05 to the next step"

    speaker
    |> next_after(context.context, 1_000, "1.2")
    |> next_after(context.context, 9_000, "2.1")

    fix_clock(context.context, @start + 12_000)
    speaker |> press("e")
    wait_for(speaker, @open)

    assert table(speaker) == [
             [~s(slide "intro"), "2", "0:08"],
             [~s(slide "body"), "1", "0:03"],
             [~s(slide "end"), "1", "No time"]
           ]

    # The key has no function in the present view.
    audience |> press("e")
    assert js(audience, @open) == false
  end
end
