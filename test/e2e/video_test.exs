defmodule Expresso.E2E.VideoTest do
  use Expresso.E2E, async: false

  # Slide 1 plays a video at each step. Slide 2 has two steps, and its video
  # shows from step 2. Slide 3 has no video.
  defmodule Deck do
    use Expresso

    slide "video" do
      video "examples/animations/clip.webm" do
        title "A clip"
        poster "examples/animations/clip.png"
      end
    end

    slide "later" do
      steps 2

      video "examples/animations/clip.webm" do
        at 2
        title "The same clip at step 2"
        poster "examples/animations/clip.png"
      end
    end

    slide "none" do
      text_box do
        text_area(text: "No video")
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  defp video(slide), do: ~s|document.querySelector("#slide-#{slide} video")|

  defp time(page, slide), do: js(page, "#{video(slide)}.currentTime")

  test "the document holds each video one time, and each copy has no source", %{page: page} do
    # The two elements have the same file, so the list holds it one time.
    assert js(page, "JSON.parse(document.getElementById('expresso-videos').textContent).length") ==
             1

    assert js(page, "[...document.querySelectorAll('video')].map((v) => v.dataset.video)")
           |> Enum.uniq() ==
             ["0"]

    copies =
      js(page, """
      [...document.querySelectorAll("video[data-video]")]
        .filter((video) => !video.closest(".screen"))
        .map((video) => video.getAttribute("src"))
      """)

    assert copies != []
    assert Enum.uniq(copies) == [nil]
  end

  test "the video of the present view plays, and the poster is under it", %{page: page} do
    wait_for(page, "!#{video(1)}.paused && #{video(1)}.currentTime > 0")

    assert js(page, "#{video(1)}.muted")
    assert js(page, ~s|document.querySelector("#slide-1 .embed-fallback").alt|) == "A clip"
  end

  test "a black screen, the menu and the overview pause the video, and it goes on after", %{
    page: page
  } do
    wait_for(page, "#{video(1)}.currentTime > 0.2")

    for {open, close} <- [{"b", "b"}, {"m", "m"}, {"o", "o"}] do
      page |> press(open)
      assert js(page, "#{video(1)}.paused"), open
      paused_at = time(page, 1)

      page |> press(close)
      wait_for(page, "!#{video(1)}.paused")
      assert time(page, 1) >= paused_at, close
    end
  end

  test "a move to another slide pauses the video, and a move back starts it again", %{
    page: page
  } do
    wait_for(page, "#{video(1)}.currentTime > 0.3")

    page |> keys(["j", "j", "j"])
    assert position(page) == "3.1"
    assert js(page, "#{video(1)}.paused")
    assert js(page, "#{video(2)}.paused")

    page |> keys(["Home"])
    wait_for(page, "!#{video(1)}.paused")
    assert time(page, 1) < 0.3
  end

  test "a video with at plays only from its step", %{page: page} do
    page |> press("j")
    assert position(page) == "2.1"
    assert js(page, "#{video(2)}.getAttribute('src')") == nil

    page |> press("j")
    wait_for(page, "!#{video(2)}.paused && #{video(2)}.currentTime > 0")
    assert js(page, "#{video(1)}.paused")
  end

  test "the handout view pauses the video and shows the poster", %{page: page} do
    wait_for(page, "!#{video(1)}.paused")
    page |> press("p")

    assert js(page, "#{video(1)}.paused")

    assert js(page, """
           getComputedStyle(document.querySelector(".handout-page .video-frame")).display
           """) == "none"
  end

  test "the speaker view plays no video", %{page: audience, context: context} do
    speaker = popup(context, fn -> press(audience, "s") end)
    wait_for(audience, "!#{video(1)}.paused")

    assert js(speaker, """
           [...document.querySelectorAll("video[data-video]")].every((video) => !video.getAttribute("src"))
           """)
  end
end
