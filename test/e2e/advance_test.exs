defmodule Expresso.E2E.AdvanceTest do
  use Expresso.E2E, async: false

  # Each step has 4 seconds. Slide 1 waits for a key, slide 2 has two steps,
  # and the one step of slide 3 has 2 seconds. The step after the last step
  # is the first step.
  defmodule Deck do
    use Expresso

    name "timed deck"
    advance 4_000
    loop true

    slide "title" do
      advance false

      text_box do
        text_area(text: "Title")
      end
    end

    slide "one" do
      steps 2

      text_box do
        text_area(text: "One")
      end
    end

    slide "two" do
      advance 2_000

      text_box do
        text_area(text: "Two")
      end
    end
  end

  # Each step has 1 millisecond, so a clock that runs moves at once.
  defmodule FastDeck do
    use Expresso

    name "fast deck"
    advance 1

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
  end

  # Slide 1 shows a clip of two seconds one time, and its step has a time of
  # 100 milliseconds.
  defmodule ClipDeck do
    use Expresso

    name "clip deck"
    advance 100

    slide "clip" do
      video "examples/animations/clip.webm" do
        title "A clip of two seconds"
        poster "examples/animations/clip.png"
        loop false
      end
    end

    slide "after" do
      text_box do
        text_area(text: "After the clip")
      end
    end
  end

  # The clock of each page at the start of a test, in milliseconds.
  @start 1_767_258_000_000

  # The time of two looks of the present view at the clock. The present view
  # looks at the clock four times each second.
  @looks 600

  setup %{context: context} do
    fix_clock(context, @start)
    :ok
  end

  defp windows(%{page: page, context: context, tmp_dir: tmp_dir}) do
    audience = open(page, render(Deck, tmp_dir))
    speaker = popup(context, fn -> press(audience, "s") end)
    {audience, speaker}
  end

  defp left(page), do: js(page, "document.getElementById('speaker-advance').textContent")

  defp left_js(text),
    do: "document.getElementById('speaker-advance').textContent === #{JSON.encode!(text)}"

  test "a step with a time goes to the next step when its time ends", context do
    {audience, speaker} = windows(context)

    # Slide 1 has `advance false`, so it waits for a key.
    fix_clock(context.context, @start + 60_000)
    Process.sleep(@looks)
    assert position(audience) == "1.1"

    audience |> press("j")
    assert position(audience) == "2.1"

    fix_clock(context.context, @start + 63_900)
    Process.sleep(@looks)
    assert position(audience) == "2.1"

    fix_clock(context.context, @start + 64_000)
    wait_for_position(audience, "2.2")
    wait_for_position(speaker, "2.2")
  end

  test "the step after the last step is the first step, with the option loop", context do
    {audience, speaker} = windows(context)

    audience |> press("End")
    assert position(audience) == "3.1"

    # Slide 3 has 2 seconds.
    fix_clock(context.context, @start + 1_900)
    Process.sleep(@looks)
    assert position(audience) == "3.1"

    fix_clock(context.context, @start + 2_000)
    wait_for_position(audience, "1.1")
    wait_for_position(speaker, "1.1")

    # The key of the next step does the same.
    audience |> press("End") |> press("j")
    assert position(audience) == "1.1"
  end

  test "the speaker view shows the time left of the step", context do
    {audience, speaker} = windows(context)

    # A step that waits for a key shows no text, and the element does not
    # show.
    wait_for(speaker, left_js(""))

    assert js(speaker, "getComputedStyle(document.getElementById('speaker-advance')).display") ==
             "none"

    speaker |> press("j")
    wait_for_position(audience, "2.1")
    wait_for(speaker, left_js("Next step in 0:04"))

    fix_clock(context.context, @start + 1_500)
    wait_for(speaker, left_js("Next step in 0:03"))

    assert js(speaker, "getComputedStyle(document.getElementById('speaker-advance')).display") ==
             "block"

    # The present view does not show the element.
    assert js(audience, "getComputedStyle(document.getElementById('speaker-advance')).display") ==
             "none"
  end

  test "a stops and starts the clock in the two windows", context do
    {audience, speaker} = windows(context)

    speaker |> press("j")
    wait_for_position(audience, "2.1")
    fix_clock(context.context, @start + 1_000)
    wait_for(speaker, left_js("Next step in 0:03"))

    speaker |> press("a")
    wait_for(audience, "document.body.dataset.paused === 'true'")
    wait_for(speaker, left_js("Clock stopped, 0:03 to the next step"))

    # The step waits while the clock is stopped.
    fix_clock(context.context, @start + 60_000)
    Process.sleep(@looks)
    assert position(audience) == "2.1"
    assert left(speaker) == "Clock stopped, 0:03 to the next step"

    # The step continues its time after the start of the clock.
    audience |> press("a")
    wait_for(speaker, "document.body.dataset.paused === undefined")
    wait_for(speaker, left_js("Next step in 0:03"))

    fix_clock(context.context, @start + 62_900)
    Process.sleep(@looks)
    assert position(audience) == "2.1"

    fix_clock(context.context, @start + 63_000)
    wait_for_position(audience, "2.2")
  end

  test "a step does not end while a video of its slide plays", %{
    page: page,
    context: context,
    tmp_dir: tmp_dir
  } do
    audience = open(page, render(ClipDeck, tmp_dir, "clip"))
    wait_for(audience, "document.querySelector('.screen video').paused === false")

    # The time of the step ended, and the clip of two seconds plays.
    fix_clock(context, @start + 10_000)
    Process.sleep(@looks)
    assert position(audience) == "1.1"
    assert js(audience, "document.querySelector('.screen video').ended") == false

    # The step ends after the end of the clip.
    wait_for_position(audience, "2.1")
    assert js(audience, "document.querySelector('.screen video').ended") == true
  end

  test "?paused in the address stops the clock at the load", %{
    page: page,
    context: context,
    tmp_dir: tmp_dir
  } do
    audience = open(page, render(FastDeck, tmp_dir, "fast") <> "?paused#1.1")
    assert js(audience, "document.body.dataset.paused") == "true"

    # The time of a step is 1 millisecond.
    fix_clock(context, @start + 60_000)
    Process.sleep(@looks)
    assert position(audience) == "1.1"

    # The time of the step starts at the start of the clock.
    audience |> press("a")
    assert js(audience, "document.body.dataset.paused") == nil
    Process.sleep(@looks)
    assert position(audience) == "1.1"

    fix_clock(context, @start + 60_010)
    wait_for_position(audience, "1.2")
  end

  test "the layout check shows each step with no clock", %{
    page: page,
    context: context,
    tmp_dir: tmp_dir
  } do
    audience = open(page, render(FastDeck, tmp_dir, "fast") <> "?check")
    wait_for(audience, "document.body.dataset.check === 'done'")

    fix_clock(context, @start + 60_000)
    Process.sleep(@looks)
    assert position(audience) == "1.1"
  end

  test "the export makes a picture of each step of a deck with a time", %{
    tmp_dir: tmp_dir
  } do
    input = Path.join(tmp_dir, "fast.exs")
    target = Path.join(tmp_dir, "slides")

    File.write!(input, """
    import Expresso.Builder

    box = fn text -> text_box(elements: [text_area(text: text)]) end

    deck(
      [
        slide("one", steps: 2, elements: [box.("One")]),
        slide("two", elements: [box.("Two, with more text than slide one")])
      ],
      name: "fast",
      advance: 1,
      loop: true
    )
    """)

    options = %{Expresso.Export.defaults() | png: target, png_steps: :all}
    assert {:ok, [line]} = Expresso.Export.export(input, nil, options)
    assert line =~ "Wrote 3 PNG files"

    # The picture of step 1 of slide 1 does not show the text of slide 2. Its
    # size in bytes is therefore the size of the picture of step 2 of slide 1,
    # which shows the same text, and not the size of the picture of slide 2.
    size = fn name -> File.stat!(Path.join(target, name)).size end
    assert size.("slide-1-step-1.png") == size.("slide-1-step-2.png")
    assert size.("slide-1-step-1.png") != size.("slide-2-step-1.png")
  end
end
