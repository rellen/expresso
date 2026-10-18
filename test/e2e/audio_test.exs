defmodule Expresso.E2E.AudioTest do
  use Expresso.E2E, async: false

  # Slide 2 plays a chime again and again from step 1. Slide 3 has no sound.
  # Slide 4 plays a chime one time, and its list has three steps. Slide 5
  # plays a chime with the controls of the browser, and its list has three
  # steps.
  defmodule Deck do
    use Expresso

    slide "start" do
      text_box do
        text_area(text: "Start")
      end
    end

    slide "chime" do
      audio "test/fixtures/chime.wav" do
        title "A chime"
        loop true
      end
    end

    slide "quiet" do
      text_box do
        text_area(text: "No sound")
      end
    end

    slide "once" do
      audio "test/fixtures/chime.wav" do
        title "A chime one time"
      end

      list do
        reveal true
        item "One"
        item "Two"
        item "Three"
      end
    end

    slide "controls" do
      audio "test/fixtures/chime.wav" do
        title "A chime with controls"
        loop true
        controls true
      end

      list do
        reveal true
        item "One"
        item "Two"
        item "Three"
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  @sound ~s|document.querySelector("#slide-2 audio")|

  test "a sound plays while its slide shows, after a key, and pauses on the next slide", %{
    page: page
  } do
    assert js(page, "#{@sound}.paused")

    page |> press("j")
    wait_for(page, "!#{@sound}.paused && #{@sound}.currentTime > 0")

    page |> press("b")
    wait_for(page, "#{@sound}.paused")
    page |> press("b")
    wait_for(page, "!#{@sound}.paused")

    page |> press("j")
    wait_for(page, "#{@sound}.paused")
  end

  test "the present view shows nothing in the place of a sound, and the handout view shows its title",
       %{page: page} do
    page |> press("j")
    refute js(page, "#{@sound}.checkVisibility()")
    refute js(page, ~s|document.querySelector("#slide-2 figcaption").checkVisibility()|)

    page |> press("p")

    assert js(
             page,
             ~s|[...document.querySelectorAll(".handout-page figcaption")].some((c) => c.checkVisibility() && c.innerText === "♪ A chime")|
           )

    # The handout view plays no sound.
    wait_for(page, "#{@sound}.paused")
  end

  defp sound(slide), do: ~s|document.querySelector("#slide-#{slide} audio")|

  # Count each start of the sound of a slide in `window.plays`.
  defp count_plays(page, slide) do
    js(page, """
    (() => {
      window.plays = 0;
      #{sound(slide)}.addEventListener("play", () => { window.plays += 1; });
      return true;
    })()
    """)

    page
  end

  test "a sound without loop plays one time, and a later step or key does not play it again",
       %{page: page} do
    count_plays(page, 4)
    page |> keys(["j", "j", "j"])
    assert position(page) == "4.1"
    wait_for(page, "!#{sound(4)}.paused")

    # Go near the end, so the test does not wait for the whole sound.
    js(page, "#{sound(4)}.currentTime = #{sound(4)}.duration - 0.05")
    wait_for(page, "#{sound(4)}.ended")

    page |> keys(["j", "g", "j"])
    assert position(page) == "4.3"
    assert js(page, "#{sound(4)}.paused")
    assert js(page, "window.plays") == 1

    # A new visit to the slide plays it again from the start.
    page |> keys(["k", "k", "k", "j"])
    assert position(page) == "4.1"
    wait_for(page, "!#{sound(4)}.paused")
    assert js(page, "window.plays") == 2
  end

  test "a pause from the controls stays after a step and after a cover", %{page: page} do
    page |> keys(["j", "j", "j", "j", "j", "j"])
    assert position(page) == "5.1"
    wait_for(page, "!#{sound(5)}.paused")

    js(page, "#{sound(5)}.pause()")
    page |> keys(["j", "b", "b", "j"])
    assert position(page) == "5.3"
    assert js(page, "#{sound(5)}.paused")
  end
end
