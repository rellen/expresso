defmodule Expresso.E2E.BackgroundTest do
  use Expresso.E2E, async: false

  # Slide 1 has an image with a dim layer and notes. Slide 2 has an image that
  # the slide contains, at the right and the bottom. Slide 3 takes the color
  # of the deck. Slide 4 has a gradient, and slide 5 has no background.
  defmodule Deck do
    use Expresso

    name "background deck"
    background color: :code_background

    slide "photo" do
      background image: "test/fixtures/dark.png", dim: 0.4
      heading "A photo"
      notes "The notes of the photo."

      text_box do
        text_area(text: "The text")
      end
    end

    slide "contain" do
      background image: "test/fixtures/halves.png", fit: :contain, position: "right bottom"
      heading "Contain"
    end

    slide "deck" do
      heading "The color of the deck"
    end

    slide "gradient" do
      background gradient: [:accent, :background], angle: 135
      heading "A gradient"
    end

    slide "none" do
      background :none
      heading "No background"
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    %{page: open(page, render(Deck, tmp_dir))}
  end

  # The box of an element, as a list of four whole numbers.
  defp box(page, selector) do
    js(page, """
    (() => {
      const box = document.querySelector(#{JSON.encode!(selector)}).getBoundingClientRect();
      return [box.left, box.top, box.width, box.height].map(Math.round);
    })()
    """)
  end

  defp style(page, selector, property) do
    js(
      page,
      "getComputedStyle(document.querySelector(#{JSON.encode!(selector)}))[#{JSON.encode!(property)}]"
    )
  end

  test "the image covers the slide, behind its content", %{page: page} do
    assert box(page, "#slide-1 > .slide-background") == box(page, "#slide-1")
    assert box(page, "#slide-1 .slide-background-image") == [0, 0, 1280, 720]

    # The slide is a stacking context, and the background is under its content.
    assert style(page, "#slide-1", "isolation") == "isolate"
    assert style(page, "#slide-1 > .slide-background", "zIndex") == "-1"
    assert style(page, "#slide-1 .slide-background-image", "objectFit") == "cover"

    # The text is the top element at its place, so a click goes to the slide.
    assert js(page, """
           (() => {
             const text = document.querySelector("#slide-1 .text-area");
             const box = text.getBoundingClientRect();
             const top = document.elementFromPoint(box.x + box.width / 2, box.y + box.height / 2);
             return text.contains(top);
           })()
           """)
  end

  test "the dim layer has the background color of the theme and the opacity of the option", %{
    page: page
  } do
    theme =
      js(page, "getComputedStyle(document.documentElement).getPropertyValue('--background')")

    assert style(page, "#slide-1 .slide-background-dim", "opacity") == "0.4"

    assert page |> style("#slide-1 .slide-background-dim", "backgroundColor") |> rgb() ==
             js(page, """
             (() => {
               const probe = document.createElement("div");
               probe.style.color = #{JSON.encode!(theme)};
               document.body.append(probe);
               const color = getComputedStyle(probe).color;
               probe.remove();
               return color;
             })()
             """)
             |> rgb()
  end

  test "an image with the fit contain keeps its place", %{page: page} do
    page |> press("j")

    assert style(page, "#slide-2 .slide-background-image", "objectFit") == "contain"
    assert style(page, "#slide-2 .slide-background-image", "objectPosition") == "100% 100%"
  end

  test "the color of the deck, a gradient, and a slide with no background", %{page: page} do
    code =
      js(page, "getComputedStyle(document.documentElement).getPropertyValue('--code-background')")

    page |> keys(["j", "j"])
    assert position(page) == "3.1"

    assert page |> style("#slide-3 .slide-background-fill", "backgroundColor") |> rgb() ==
             js(page, """
             (() => {
               const probe = document.createElement("div");
               probe.style.color = #{JSON.encode!(code)};
               document.body.append(probe);
               const color = getComputedStyle(probe).color;
               probe.remove();
               return color;
             })()
             """)
             |> rgb()

    assert style(page, "#slide-4 .slide-background-fill", "backgroundImage") =~
             ~r/^linear-gradient\(135deg, /

    assert js(page, "document.querySelector('#slide-5 .slide-background')") == nil
  end

  test "the handout view shows the background, and the notes have a color of their own", %{
    page: page
  } do
    page |> press("p")

    assert js(page, """
           getComputedStyle(document.querySelector(
             '.handout-page[data-slide="1"] .slide-background-image')).display
           """) == "block"

    transparent = ["rgba(0, 0, 0, 0)", "transparent"]

    refute js(page, """
           getComputedStyle(document.querySelector('.handout-page[data-slide="1"] .notes'))
             .backgroundColor
           """) in transparent
  end

  test "paper gets one page for each slide, with the background", %{page: page} do
    assert pdf_pages(page) == 5
  end
end

defmodule Expresso.E2E.BackgroundCheckTest do
  # The check starts its own headless browser, as in `Expresso.E2E.CheckTest`.
  use ExUnit.Case, async: false

  import ExUnit.CaptureIO

  @moduletag :e2e
  @moduletag :tmp_dir
  @moduletag timeout: 300_000

  setup_all do
    shell = Expresso.Check.Browser.playwright()

    if System.get_env("EXPRESSO_CHROMIUM") == nil and shell != nil do
      System.put_env("EXPRESSO_CHROMIUM", shell)
      on_exit(fn -> System.delete_env("EXPRESSO_CHROMIUM") end)
    end

    :ok
  end

  @fixtures Path.expand("../fixtures", __DIR__)

  # The default theme gives dark text. Slide 1 puts it on a dark image, and
  # slide 2 puts it on the same image with a strong dim layer. Slide 3 has a
  # light image. Slide 4 has an image with a dark half at the left, and its
  # heading is on the two halves. Slide 5 has a dark color with a strong dim
  # layer. Slide 6 shows a text on a dark gradient at step 2 only. Slide 7
  # has a text with a background of its own on the dark image.
  @deck """
  defmodule BackgroundCheckDeck do
    use Expresso

    name "background check deck"
    root #{inspect(@fixtures)}
    css ".own { background: #ffffff; }"

    slide "dark" do
      background "dark.png"
      heading "On a dark photo"
    end

    slide "dimmed" do
      background image: "dark.png", dim: 0.85
      heading "With a dim layer"
    end

    slide "light" do
      background "light.png"
      heading "On a light photo"
    end

    slide "halves" do
      background "halves.png"
      heading "On the two halves of a photo"
    end

    slide "later" do
      background color: "#101828", dim: 0.9

      text_box do
        text_area(text: "First")
      end
    end

    slide "steps" do
      background gradient: ["#101828", "#202838"], angle: 90
      steps 2

      text_box do
        at 2
        text_area(text: "At step 2")
      end
    end

    slide "own" do
      background "dark.png"
      sr_heading false

      text_box do
        text_area(text: "On white", class: "own")
      end
    end
  end
  """

  defp check(dir, source, level) do
    input = Path.join(dir, "deck.exs")
    name = "Deck#{System.unique_integer([:positive])}"
    File.write!(input, String.replace(source, ~r/defmodule \w+/, "defmodule #{name}"))

    output =
      capture_io(fn ->
        send(self(), {:status, Expresso.Check.run(input, nil, level, [])})
      end)

    assert_received {:status, status}
    {status, output}
  end

  test "--check=a11y names each text with a low contrast on the background of its slide", %{
    tmp_dir: dir
  } do
    {status, output} = check(dir, @deck, :a11y)

    assert status == 1

    problems =
      for line <- String.split(output, "\n"), line =~ "background-contrast" do
        [where, rest] = String.split(line, ": background-contrast, ", parts: 2)
        [_help, elements] = String.split(rest, "a higher dim: ", parts: 2)
        {String.replace_prefix(where, "  - ", ""), elements}
      end

    assert problems == [
             {"Slide 1 “dark”, step 1",
              "the text “background check deck”, the heading “On a dark photo”"},
             {"Slide 4 “halves”, step 1", "the heading “On the two halves of a photo”"},
             {"Slide 6 “steps”, step 2", "the text area “At step 2”"}
           ]

    assert output =~
             "background-contrast, Text must have a contrast of 4.5:1 on the background of " <>
               "its slide, or 3:1 for large text. Give the background option a higher dim: "
  end

  test "--check=layout does not measure the background", %{tmp_dir: dir} do
    {status, output} = check(dir, @deck, :layout)

    assert {status, output} == {0, output}
    refute output =~ "background-contrast"
    refute output =~ "no alt text"
  end
end
