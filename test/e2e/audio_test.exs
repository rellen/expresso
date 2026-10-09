defmodule Expresso.E2E.AudioTest do
  use Expresso.E2E, async: false

  # Slide 2 plays a chime again and again from step 1. Slide 3 has no sound.
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
end
