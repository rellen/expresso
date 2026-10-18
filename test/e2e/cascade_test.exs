defmodule Expresso.E2E.CascadeTest do
  use Expresso.E2E, async: false

  # Each test reads the computed styles of a rule of the style sheet that a
  # later rule or a more specific rule replaced. Issue #318 gives each defect.

  # Slide 1 has a list that shows its items one at a time, and an image that
  # shows from step 1. The deck has a dark theme, so a revealed text is light.
  defmodule BlankDeck do
    use Expresso

    name "blank deck"
    theme :dracula

    slide "one" do
      list do
        reveal true
        item "First point"
        item "Second point"
      end

      image "test/fixtures/dot.png", alt: "A dot", at: [from: 1]
    end
  end

  # Each slide holds the input of one item of issue #318.
  defmodule Deck do
    use Expresso

    name "cascade deck"

    slide "icon" do
      steps 3

      icon "rocket" do
        label "With on"
        color :success
        on 2, state: :alert
        on 3, state: :dim
      end
    end

    slide "code" do
      code "elixir" do
        reveal [1, 2]
        dim true
        text "def a, do: :ok\ndef b, do: \"x\"\n"
      end
    end

    slide "embed" do
      steps 3

      embed "test/fixtures/page.html" do
        title "Demo"
        at from: 2
        effect :fly_up
        on 3, state: :alert
        on 3, set: [x: "100px"]
      end

      video "examples/animations/clip.webm" do
        title "A clip"
        poster "examples/animations/clip.png"
        on 2, state: :dim
      end
    end

    slide "graphics" do
      steps 3

      list do
        reveal true
        dim true
        item ":icon:check: The tests pass"
        item "Second point"
      end

      shape :line do
        from ["10%", "10%"]
        to ["20%", "20%"]
        effect :blur
        on 2, set: [opacity: 0.3]
        on 3, state: :dim
      end
    end

    slide "image" do
      steps 2

      image "test/fixtures/dot.png" do
        alt "A dot"
        on 2, state: :dim
      end
    end

    slide "muted" do
      steps 2

      audio "test/fixtures/chime.wav" do
        title "A chime"
        on 2, state: :dim
      end

      footnote "A source." do
        on 2, state: :dim
      end
    end

    slide "highlight" do
      code "elixir" do
        highlight [2, 3..4]
        text "a\nb\nc\nd\n"
      end
    end

    slide "chart" do
      chart :bar do
        title "Orders and returns"
        categories ["2023", "2024"]
        reveal true
        dim true
        series "Orders", [180, 240]
        series "Returns", [22, 19]
      end
    end
  end

  setup %{page: page, tmp_dir: tmp_dir} do
    url = render(Deck, tmp_dir)
    %{page: open(page, url), url: url}
  end

  # The computed value of a color property of the theme, as `rgb(r, g, b)`.
  defp theme_color(page, property) do
    js(page, """
    (() => {
      const probe = document.createElement("div");
      probe.style.color = "var(#{property})";
      document.querySelector(".screen").append(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    })()
    """)
    |> rgb()
  end

  defp style(page, selector, property) do
    js(
      page,
      "getComputedStyle(document.querySelector(#{JSON.encode!(selector)}))[#{JSON.encode!(property)}]"
    )
  end

  defp color(page, selector), do: page |> style(selector, "color") |> rgb()

  defp transitions(page, selector),
    do: page |> style(selector, "transitionProperty") |> String.split(", ")

  test "the black screen shows no element of the slide, also a revealed element",
       %{page: page, tmp_dir: tmp_dir} do
    page = page |> open(render(BlankDeck, tmp_dir, "blank")) |> press("j") |> press("b")
    assert position(page) == "1.2"

    # Each item and the image have `visibility: visible` from the reveal rule.
    assert js(page, """
           [...document.querySelectorAll("#slide-1 li, #slide-1 img")]
             .every((element) => getComputedStyle(element).visibility === "visible")
           """)

    shown =
      js(page, """
      [...document.querySelectorAll(".screen *")]
        .filter((element) =>
          element.checkVisibility({ opacityProperty: true, visibilityProperty: true }))
        .map((element) => element.tagName)
      """)

    assert shown == []
    assert style(page, ".screen", "pointerEvents") == "none"

    page |> press("b")
    assert style(page, ".screen", "opacity") == "1"

    assert js(
             page,
             "document.querySelector('#slide-1 li').checkVisibility({ opacityProperty: true })"
           )
  end

  test "an icon with an on entity keeps the color of its role, and dims to the dimmed color of its role",
       %{page: page} do
    success = theme_color(page, "--success")
    success_dim = theme_color(page, "--success-dim")
    refute success == theme_color(page, "--text")

    assert color(page, "#slide-1 .icon") == success
    assert color(page, "#slide-1 .icon-label") == success

    page |> keys(["j", "j"])
    assert position(page) == "1.3"
    assert color(page, "#slide-1 .icon") == success_dim
    assert color(page, "#slide-1 .icon-label") == success_dim
  end

  test "an element with an on entity and an overlay has a transition of --dimmed and of --highlight",
       %{page: page} do
    line = transitions(page, "#slide-2 .line[data-on][data-el]")
    assert "--dimmed" in line
    assert "--highlight" in line
    assert "visibility" in line

    # A line of the option `highlight` has an `on` entity and no overlay.
    assert "--highlight" in transitions(page, "#slide-7 .line[data-el]")
  end

  test "a series of a chart keeps the transitions of an overlay and of --chart-dim",
       %{page: page} do
    first = transitions(page, "#slide-8 .chart-series[data-on][data-el]")
    assert "--chart-dim" in first
    assert "--dimmed" in first
    assert "visibility" in first

    second = transitions(page, "#slide-8 .chart-series[data-on]:not([data-el])")
    assert "--chart-dim" in second
    assert "visibility" in second
    assert "clip-path" in second
  end

  test "an embed and a video take the effect, set and the state alert", %{page: page, url: url} do
    page = open(page, url <> "#3")
    assert position(page) == "3.1"

    # The hidden embed is 1rem below its place, so it flies up at step 2.
    assert style(page, "#slide-3 .embed:not(.video)", "transform") =~
             ~r/^matrix\(1, 0, 0, 1, 0, [1-9]/

    page |> keys(["j", "j"])
    assert position(page) == "3.3"
    assert style(page, "#slide-3 .embed:not(.video)", "transform") == "matrix(1, 0, 0, 1, 100, 0)"
    assert style(page, "#slide-3 .embed:not(.video)", "outlineWidth") == "4px"
    assert "transform" in transitions(page, "#slide-3 .embed.video")
  end

  test "a graphic in a dimmed element dims one time, and a line takes the filter of its element",
       %{page: page, url: url} do
    # Slide 4, step 2: the first item dims, and the line has the opacity 0.3.
    page = page |> open(url <> "#4") |> press("j")
    assert position(page) == "4.2"
    assert style(page, "#slide-4 .icon-inline", "filter") == "none"
    assert color(page, "#slide-4 .item") == theme_color(page, "--text-dim")
    assert style(page, "#slide-4 .shape-line", "filter") == "blur(0px) opacity(0.3)"

    page |> press("j")
    assert position(page) == "4.3"
    assert style(page, "#slide-4 .shape-line", "filter") == "blur(0px) opacity(1)"
    assert color(page, "#slide-4 .shape-line") == theme_color(page, "--text-dim")
  end

  test "a video dims, and a copy of a slide in the menu dims", %{page: page, url: url} do
    %{dim_opacity: opacity} = Expresso.Palette.Builtin.fetch!(:default)
    page = page |> open(url <> "#3") |> press("j")
    assert position(page) == "3.2"
    assert style(page, "#slide-3 video", "filter") == "opacity(#{opacity})"

    # The copy of slide 5 in the menu shows its last step, at which the image dims.
    page |> press("m")
    assert style(page, ".menu-thumb img[alt='A dot']", "filter") == "opacity(#{opacity})"
  end

  test "muted text dims to the dimmed color of its role", %{page: page} do
    muted_dim = theme_color(page, "--muted-dim")
    refute muted_dim == theme_color(page, "--text-dim")

    page |> press("p")

    assert color(page, ~s(.handout-page[data-slide="6"][data-step="2"] .audio figcaption)) ==
             muted_dim

    assert color(page, ~s(.handout-page[data-slide="6"][data-step="2"] .footnote)) == muted_dim

    assert color(page, ~s(.handout-page[data-slide="6"][data-step="1"] .footnote)) ==
             theme_color(page, "--muted")
  end
end
