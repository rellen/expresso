defmodule Expresso.E2E.CopyTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext}

  # At step 2, a copy of the token goes to the circle and a copy goes to the
  # station. The token stays at its place.
  defmodule Deck do
    use Expresso

    slide "copy" do
      diagram "test/fixtures/move.svg" do
        width "80%"

        part "token" do
          copy("target", at: [from: 2])

          copy "station" do
            at from: 2
            on [from: 3], state: :dim
          end
        end
      end
    end
  end

  # The short form: at step 2, a copy goes to each target.
  defmodule ShortDeck do
    use Expresso

    slide "copy_to" do
      diagram "test/fixtures/move.svg" do
        width "80%"

        part "token" do
          on 2, copy_to: ["target", "station"]
        end
      end
    end
  end

  # The center of an element of the diagram on the screen.
  defp center(page, id) do
    js(page, """
    (() => {
      const box = document.querySelector('.screen [id^="#{id}-"]').getBoundingClientRect();
      return [Math.round(box.left + box.width / 2), Math.round(box.top + box.height / 2)];
    })()
    """)
  end

  defp opacity(page, id) do
    js(page, """
    Number(getComputedStyle(document.querySelector('.screen [id^="#{id}-"]').closest('[data-el]')).opacity)
    """)
  end

  defp near?([x1, y1], [x2, y2]), do: abs(x1 - x2) <= 1 and abs(y1 - y2) <= 1

  test "a copy shows at its step at its target, and the part stays", %{
    page: page,
    tmp_dir: tmp_dir
  } do
    page = open(page, render(Deck, tmp_dir))
    token = center(page, "token")

    assert opacity(page, "token@target") == 0

    assert js(
             page,
             ~s{document.querySelector('.screen [id^="token@target-"]').getAttribute("aria-hidden")}
           ) == "true"

    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '2'")
    assert opacity(page, "token@target") == 1
    assert near?(center(page, "token@target"), center(page, "target"))
    assert near?(center(page, "token@station"), center(page, "station"))
    assert center(page, "token") == token

    press(page, "k")
    assert opacity(page, "token@target") == 0
  end

  test "a copy fades in at its source, and then it moves", %{browser: browser, tmp_dir: tmp_dir} do
    {:ok, context} =
      Browser.new_context(browser.guid,
        timeout: 10_000,
        viewport: %{width: 1280, height: 720},
        reduced_motion: "no-preference"
      )

    on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
    {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
    page = open(page, render(Deck, tmp_dir))
    js(page, "document.documentElement.style.setProperty('--dur', '1s')")
    token = center(page, "token")

    press(page, "j")

    wait_for(page, """
    (() => {
      const o = Number(getComputedStyle(document.querySelector('.screen [id^="token@target-"]').closest('[data-el]')).opacity);
      return o > 0.3 && o < 0.7;
    })()
    """)

    assert near?(center(page, "token@target"), token)

    wait_for(page, """
    (() => {
      const box = (s) => document.querySelector('.screen [id^="' + s + '-"]').getBoundingClientRect();
      const [a, b] = [box("token@target"), box("target")];
      return Math.abs(a.left + a.width / 2 - b.left - b.width / 2) < 1;
    })()
    """)
  end

  test "copy_to sends a copy to each target", %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(ShortDeck, tmp_dir, "short"))
    token = center(page, "token")
    assert opacity(page, "token@station") == 0

    press(page, "j")
    wait_for(page, "document.querySelector('.screen .slide').dataset.step === '2'")
    assert near?(center(page, "token@target"), center(page, "target"))
    assert near?(center(page, "token@station"), center(page, "station"))
    assert center(page, "token") == token
  end
end
