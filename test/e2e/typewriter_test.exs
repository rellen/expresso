defmodule Expresso.E2E.TypewriterTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # The first slide has a text of ten characters that shows at step 2 only,
  # and three texts of eight characters at step 3, each with its own speed.
  # The second slide has a code element with two groups of lines.
  defmodule Deck do
    use Expresso

    name "type deck"

    slide "text" do
      text_box do
        text_area(text: "Hello world", at: 2, effect: :type)
      end

      text_box do
        text_area(text: "Slow text", at: 3, effect: :type, speed: :slow)
      end

      text_box do
        text_area(text: "Fast text", at: 3, effect: :type, speed: :fast)
      end

      text_box do
        text_area(text: "Long text", at: 3, effect: :type, speed: 1000)
      end
    end

    slide "code" do
      pause()

      code(
        text: """
        a = 1
        b = 2
        c = 3
        """,
        lang: "elixir",
        reveal: [1..2, 3],
        effect: :type
      )
    end
  end

  # The characters of the present view that show, as one text for each
  # element with the effect, in the order of the document.
  defp shown(page) do
    js(page, """
    [...document.querySelectorAll('.screen section:not([style*="display: none"]) [data-effect="type"]')]
      .map((element) => [...element.querySelectorAll(".type-char")]
        .filter((char) => getComputedStyle(char).opacity === "1" &&
          getComputedStyle(element).visibility === "visible")
        .map((char) => char.textContent)
        .join(""))
    """)
  end

  # The text of each character of the present view that has a cursor: it
  # shows, and the color of its shadow is not clear.
  defp cursors(page) do
    js(page, """
    [...document.querySelectorAll(".screen .type-char")]
      .filter((char) => getComputedStyle(char).opacity === "1" &&
        !getComputedStyle(char).boxShadow.includes("/ 0)"))
      .map((char) => char.textContent)
    """)
  end

  # The time in milliseconds of the change of `--type` of each element of the
  # present view that types.
  defp times(page) do
    js(page, """
    [...document.querySelectorAll('.screen [data-effect="type"]')]
      .flatMap((element) => element.getAnimations())
      .filter((animation) => animation.transitionProperty === "--type")
      .map((animation) => animation.effect.getComputedTiming().duration)
    """)
  end

  defp typing(page), do: wait_for(page, "#{types_js()}.length > 0")

  defp types_js do
    ~s|document.getAnimations().filter((animation) => animation.transitionProperty === "--type")|
  end

  describe "with reduced motion" do
    setup %{page: page, tmp_dir: tmp_dir} do
      %{page: open(page, render(Deck, tmp_dir))}
    end

    test "a text shows at once at its step, and hides at once", %{page: page} do
      assert shown(page) == ["", "", "", ""]

      page |> press("j")
      assert shown(page) == ["Hello world", "", "", ""]
      assert times(page) == []
      assert cursors(page) == []

      page |> press("j")
      assert shown(page) == ["", "Slow text", "Fast text", "Long text"]
    end

    test "the whole text for a screen reader takes no space", %{page: page} do
      sizes =
        js(page, """
        [...document.querySelectorAll(".screen .type-text")].map((text) => {
          const box = text.getBoundingClientRect();
          return [box.width, box.height];
        })
        """)

      assert sizes != []
      assert Enum.all?(sizes, &(&1 == [0, 0]))
    end

    test "the text has the same place as a text with no effect", %{page: page} do
      page |> press("j")

      [typed, plain] =
        js(page, """
        (() => {
          const area = document.querySelector(".screen .text-area");
          const typed = area.getBoundingClientRect();
          area.firstElementChild.textContent = "Hello world";
          const plain = area.getBoundingClientRect();
          return [[typed.width, typed.height], [plain.width, plain.height]];
        })()
        """)

      assert typed == plain
    end
  end

  describe "with motion" do
    setup %{browser: browser, tmp_dir: tmp_dir} do
      {:ok, context} =
        Browser.new_context(browser.guid,
          timeout: 10_000,
          viewport: %{width: 1280, height: 720},
          reduced_motion: "no-preference"
        )

      on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
      {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
      %{moving: open(page, render(Deck, tmp_dir))}
    end

    test "a text shows one character at a time, with a cursor on the newest one", %{moving: page} do
      page |> press("j")
      # Ten characters take 400 ms. At 210 ms, the sixth character shows.
      pause_animations(page, ".screen .text-area", 210)

      assert shown(page) == ["Hello w", "", "", ""]
      assert cursors(page) == ["w"]

      pause_animations(page, ".screen .text-area", 370)
      assert shown(page) == ["Hello world", "", "", ""]
      assert cursors(page) == ["d"]

      finish_animations(page, ".screen .text-area")
      wait_for(page, "#{types_js()}.length === 0")
      assert shown(page) == ["Hello world", "", "", ""]
      assert cursors(page) == []
    end

    test "the speed option gives the time of the text", %{moving: page} do
      page |> press("j")
      assert typing(page)
      assert times(page) == [400]

      finish_animations(page, ".screen .text-area")
      page |> press("j")
      wait_for(page, "#{types_js()}.length === 3")

      assert times(page) == [640, 160, 1000]
    end

    test "a text hides at once", %{moving: page} do
      page |> press("j")
      finish_animations(page, ".screen .text-area")
      page |> press("j")

      assert hd(shown(page)) == ""
    end

    test "a text shows at once after a step back", %{moving: page} do
      page |> press("j")
      finish_animations(page, ".screen .text-area")
      page |> press("j")
      finish_animations(page, ".screen .text-area")

      page |> press("k")

      assert js(page, ~s|document.querySelector("#slide-1").hasAttribute("data-back")|)
      assert shown(page) == ["Hello world", "", "", ""]
      assert times(page) == []

      # The next step forward types again.
      page |> press("j")
      wait_for(page, "#{types_js()}.length === 3")
      refute js(page, ~s|document.querySelector("#slide-1").hasAttribute("data-back")|)
    end

    test "a slide that comes back shows its text at once", %{moving: page} do
      page |> press("j") |> press("j") |> press("j")
      wait_for_position(page, "2.1")
      page |> press("k")
      wait_for_position(page, "1.3")

      wait_for(page, "document.getAnimations().length === 0")
      assert shown(page) == ["", "Slow text", "Fast text", "Long text"]
      assert times(page) == []
    end

    test "the lines of a group of a code element type one after the other", %{moving: page} do
      page |> press("j") |> press("j") |> press("j")
      wait_for_position(page, "2.1")
      wait_for(page, "document.getAnimations().length === 0")
      assert shown(page) == ["", "", ""]

      page |> press("j")
      # The group has six characters, which take 240 ms. At 130 ms, the first
      # line is complete and the second line has one character.
      pause_animations(page, ".screen .code", 130)

      assert shown(page) |> Enum.map(&String.trim/1) == ["a = 1", "b", ""]
      assert times(page) == [240, 240]

      finish_animations(page, ".screen .code")
      page |> press("j")
      assert typing(page)
      assert times(page) == [120]
    end
  end
end
