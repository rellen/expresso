defmodule Expresso.E2E.EmbedTest do
  use Expresso.E2E, async: false

  # Slide 1 holds a local page that counts, with a fallback image. Slide 2
  # holds an address. The test makes no request to the network: it reads the
  # attribute of the frame of slide 2, and the page of slide 2 does not need
  # to load.
  defmodule Deck do
    use Expresso

    slide "local" do
      embed "test/fixtures/page.html" do
        title "A page that counts"
        fallback("test/fixtures/dot.png")
      end
    end

    slide "address" do
      embed "https://example.com/" do
        title "An example page"
      end
    end
  end

  # A deck with a name and a heading on two lines. At 1280 × 720, the slide
  # has less height for the embed than the window less the room for one
  # heading.
  defmodule NamedDeck do
    use Expresso

    name "named deck"

    slide "local" do
      heading "Line 4: a factory in one file"

      embed "test/fixtures/page.html" do
        title "A page that counts"
        fallback("test/fixtures/dot.png")
      end
    end
  end

  # A callout holds an embed and a video. A callout is a flex column with an
  # automatic height, so the embed cannot take its height from the callout.
  defmodule CalloutDeck do
    use Expresso

    slide "callout" do
      callout :note do
        text_area(text: "The demo:")

        embed "https://example.com/" do
          title "Demo"
        end

        video "examples/animations/clip.webm" do
          title "A clip"
          poster "examples/animations/clip.png"
        end
      end
    end
  end

  defp frames(page) do
    js(page, """
    Array.from(document.querySelectorAll("iframe.embed-frame")).map((frame) => ({
      present: frame.closest(".screen") !== null,
      src: frame.getAttribute("src"),
      srcdoc: frame.hasAttribute("srcdoc")
    }))
    """)
  end

  test "the present view loads each page one time, when its slide shows", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    wait_for(
      page,
      ~s|document.querySelector(".screen iframe[data-embed='0']").hasAttribute("srcdoc")|
    )

    loaded = page |> frames() |> Enum.filter(&(&1["src"] || &1["srcdoc"]))
    assert loaded == [%{"present" => true, "src" => nil, "srcdoc" => true}]

    # The page runs its script, and the fallback hides after the load. The
    # sandbox does not let the deck read the page, so the page sends its count.
    js(page, """
    window.addEventListener("message", (event) => {
      if (typeof event.data?.ticks === "number") window.ticks = event.data.ticks;
    })
    """)

    wait_for(page, "(window.ticks ?? 0) > 2")

    assert js(page, ~s|document.querySelector(".screen iframe[data-embed='0']").contentDocument|) ==
             nil

    assert js(page, ~s|document.querySelector(".screen #slide-1 .embed-fallback").hidden|) == true

    press(page, "j")

    wait_for(
      page,
      ~s|document.querySelector(".screen iframe[data-embed='1']").getAttribute("src") === "https://example.com/"|
    )

    # The handout pages hold no source.
    assert page
           |> frames()
           |> Enum.reject(& &1["present"])
           |> Enum.all?(&(&1["src"] == nil and not &1["srcdoc"]))
  end

  test "a frame that is not interactive leaves the click to the presenter", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))

    assert js(
             page,
             ~s|getComputedStyle(document.querySelector(".screen .embed-frame")).pointerEvents|
           ) ==
             "none"

    click(page, 1000, 360)
    assert position(page) == "2.1"
  end

  test "the box takes the height that is left under the heading and the name of the deck", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(NamedDeck, tmp_dir))

    [heading, box] =
      js(page, """
      [".screen #slide-1 h1", ".screen #slide-1 .embed-box"].map((selector) => {
        const box = document.querySelector(selector).getBoundingClientRect();
        return {top: box.top, bottom: box.bottom, height: box.height};
      })
      """)

    assert heading["height"] > 150
    assert box["top"] >= heading["bottom"]
    assert box["bottom"] <= 720
  end

  test "the speaker view loads no page", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir) <> "?speaker")

    js(page, "new Promise((resolve) => setTimeout(resolve, 300))")
    assert page |> frames() |> Enum.all?(&(&1["src"] == nil and not &1["srcdoc"]))
  end

  test "the handout view shows the fallback, and hides the frame", %{page: page, tmp_dir: tmp_dir} do
    page = page |> open(render(Deck, tmp_dir)) |> press("p")

    assert js(page, """
           Array.from(document.querySelectorAll(".handout-page:not([data-omit]) .embed-frame"))
             .every((frame) => getComputedStyle(frame).display === "none")
           """)

    assert js(page, """
           getComputedStyle(document.querySelector(".handout-page .embed-fallback")).display
           """) != "none"
  end

  # The pattern of "Show a video" in docs/how-to/show-a-web-page.md: a local
  # page holds the video as a data URI. The page of the test also sends the
  # time of the video, because the sandbox does not let the deck read it.
  test "a local page plays a video from a data URI", %{page: page, tmp_dir: tmp_dir} do
    video = "test/fixtures/clip.webm" |> File.read!() |> Base.encode64()
    html = Path.join(tmp_dir, "video.html")

    File.write!(html, """
    <!doctype html>
    <video src="data:video/webm;base64,#{video}" autoplay loop muted playsinline></video>
    <script>
      const video = document.querySelector("video");
      setInterval(() => parent.postMessage({ time: video.currentTime }, "*"), 100);
    </script>
    """)

    embed = Expresso.Builder.embed(html, title: "A video", fallback: "test/fixtures/dot.png")
    deck = Expresso.Builder.deck([Expresso.Builder.slide("video", elements: [embed])])
    page = open(page, render(deck, tmp_dir))

    js(page, """
    window.addEventListener("message", (event) => {
      if (typeof event.data?.time === "number") window.videoTime = event.data.time;
    })
    """)

    wait_for(page, "(window.videoTime ?? 0) > 0.3")
  end

  # The width and the height of each embed box in the callout, in a part of
  # the document.
  defp callout_boxes(page, selector) do
    js(page, """
    Array.from(document.querySelectorAll("#{selector} .callout .embed-box")).map((box) => {
      const rect = box.getBoundingClientRect();
      return [Math.round(rect.width), Math.round(rect.height)];
    })
    """)
  end

  test "an embed and a video in a callout have a size in each view and on paper", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    url = render(CalloutDeck, tmp_dir)
    present = page |> open(url) |> callout_boxes(".screen")
    speaker = page |> open(url <> "?speaker") |> callout_boxes("[data-speaker='current']")
    printed = page |> open(url) |> emulate("print") |> callout_boxes(".handout-page")

    for boxes <- [present, speaker, printed] do
      assert [_embed, _video] = boxes
      assert Enum.all?(boxes, fn [width, height] -> width > 100 and height > 50 end)
    end
  end
end
