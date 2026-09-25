defmodule Expresso.E2E.DurationTest do
  use Expresso.E2E, async: false

  # Three slides of one step each, and a talk of 20 minutes.
  defmodule TimedDeck do
    use Expresso

    name "timed deck"
    duration 20

    slide "one" do
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
  end

  defmodule UntimedDeck do
    use Expresso

    name "untimed deck"

    slide "one" do
      text_box do
        text_area(text: "One")
      end
    end
  end

  defp left(page), do: js(page, "document.getElementById('speaker-left').textContent")

  defp style(page, property) do
    js(page, "getComputedStyle(document.getElementById('speaker-left')).#{property}")
  end

  test "the speaker view shows the time of the deck option", %{
    page: page,
    context: context,
    tmp_dir: tmp_dir
  } do
    audience = open(page, render(TimedDeck, tmp_dir))
    speaker = popup(context, fn -> press(audience, "s") end)

    assert left(speaker) == "20:00 left"
    assert style(speaker, "display") == "block"
    refute js(audience, "document.getElementById('speaker-left')")
  end

  test "?duration= replaces the deck option, and the speaker view gets it from the present view",
       %{page: page, context: context, tmp_dir: tmp_dir} do
    audience = open(page, render(TimedDeck, tmp_dir) <> "?duration=0.05")
    speaker = popup(context, fn -> press(audience, "s") end)

    assert js(speaker, "location.search") =~ "duration=0.05"
    assert left(speaker) == "0:03 left"

    # The first change of the step starts the timer. After 3 seconds the time
    # is up, and the time left turns red.
    speaker |> press("j")
    wait_for(speaker, "document.getElementById('speaker-left').dataset.pace === 'over'")

    assert left(speaker) =~ ~r/^\+0:0\d over$/
    assert style(speaker, "color") == "rgb(201, 42, 42)"
  end

  test "a deck with no duration shows no time left", %{
    page: page,
    context: context,
    tmp_dir: tmp_dir
  } do
    audience = open(page, render(UntimedDeck, tmp_dir))
    speaker = popup(context, fn -> press(audience, "s") end)

    assert left(speaker) == ""
    assert style(speaker, "display") == "none"
  end
end
