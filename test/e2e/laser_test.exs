defmodule Expresso.E2E.LaserTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.{Browser, BrowserContext, Page}

  # Slide 1 has two steps, and slide 2 has one step.
  defmodule Deck do
    use Expresso

    name "laser deck"

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

  setup %{page: page, context: context, tmp_dir: tmp_dir} do
    audience = open(page, render(Deck, tmp_dir))
    speaker = popup(context, fn -> press(audience, "s") end)
    %{audience: audience, speaker: speaker}
  end

  defp move(page, x, y) do
    {:ok, _result} = Page.mouse_move(page.guid, timeout: 10_000, x: x, y: y)
    page
  end

  # The box of the slide in a window: the present view, or the page of the
  # current step of the speaker view.
  defp box(page, selector) do
    js(page, """
    (() => {
      const box = document.querySelector(#{JSON.encode!(selector)}).getBoundingClientRect();
      return [box.left, box.top, box.width, box.height];
    })()
    """)
  end

  # The center of the dot as a part of the box of the slide, with two
  # decimal places, or nil while the dot does not show.
  defp dot(page, selector) do
    js(page, """
    (() => {
      const dot = document.getElementById("laser");
      if (getComputedStyle(dot).display === "none") return null;
      const box = document.querySelector(#{JSON.encode!(selector)}).getBoundingClientRect();
      const place = dot.getBoundingClientRect();
      const round = (value) => Math.round(value * 100) / 100;
      return [
        round((place.left + place.width / 2 - box.left) / box.width),
        round((place.top + place.height / 2 - box.top) / box.height)
      ];
    })()
    """)
  end

  @screen ".screen"
  @current ~s(.handout-page[data-speaker="current"])

  defp shown(page, selector), do: wait_for(page, dot_js(selector) <> " !== null")
  defp hidden(page, selector), do: wait_for(page, dot_js(selector) <> " === null")

  defp dot_js(_selector),
    do: ~s|(getComputedStyle(document.getElementById("laser")).display === "none" ? null : true)|

  # Move the mouse of the speaker view to a part of the page of the current
  # step.
  defp point(speaker, x, y) do
    [left, top, width, height] = box(speaker, @current)
    move(speaker, left + x * width, top + y * height)
  end

  test "l turns the pointer on in the two windows, with no dot before a move", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("l")

    wait_for(audience, ~s|document.body.dataset.laser === "true"|)
    assert js(speaker, "document.body.dataset.laser") == "true"
    assert dot(speaker, @current) == nil
    assert dot(audience, @screen) == nil
  end

  test "the dot of the speaker view moves the dot of the present view to the same part of the slide",
       %{audience: audience, speaker: speaker} do
    speaker |> press("l") |> point(0.25, 0.5)

    shown(audience, @screen)
    assert dot(speaker, @current) == [0.25, 0.5]
    assert dot(audience, @screen) == [0.25, 0.5]

    speaker |> point(0.8, 0.1)
    wait_for(audience, "document.getElementById('laser').style.left !== '320px'")

    assert dot(speaker, @current) == [0.8, 0.1]
    assert dot(audience, @screen) == [0.8, 0.1]
  end

  test "the dot of the present view moves the dot of the speaker view", %{
    audience: audience,
    speaker: speaker
  } do
    audience |> press("l") |> move(960, 180)

    shown(speaker, @current)
    assert dot(audience, @screen) == [0.75, 0.25]
    assert dot(speaker, @current) == [0.75, 0.25]
  end

  test "a click moves the dot, and it does not change the step", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("l")
    [left, top, width, height] = box(speaker, @current)
    speaker |> click(left + width * 0.9, top + height * 0.5)

    shown(audience, @screen)
    assert dot(audience, @screen) == [0.9, 0.5]
    assert position(audience) == "1.1"
    assert js(speaker, "location.hash") == "#1.1"
  end

  test "the mouse outside the slide hides the dot in the two windows", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("l") |> point(0.5, 0.5)
    shown(audience, @screen)

    [left, top, width, height] = box(speaker, @current)
    speaker |> move(left + width + 40, top + height + 40)

    hidden(audience, @screen)
    assert dot(speaker, @current) == nil
  end

  test "the next step turns the pointer off in the two windows", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("l") |> point(0.5, 0.5)
    shown(audience, @screen)

    speaker |> press("j")
    wait_for(audience, "location.hash === '#1.2'")

    hidden(audience, @screen)
    assert js(audience, "document.body.dataset.laser") == nil
    assert js(speaker, "document.body.dataset.laser") == nil
    assert dot(speaker, @current) == nil

    # A move of the mouse shows no dot, and a click changes the step again.
    speaker |> point(0.6, 0.6)
    assert dot(speaker, @current) == nil

    [left, top, width, height] = box(speaker, @current)
    speaker |> click(left + width * 0.9, top + height * 0.5)
    wait_for(audience, "location.hash === '#2.1'")
  end

  test "a second l turns the pointer off", %{audience: audience, speaker: speaker} do
    speaker |> press("l") |> point(0.5, 0.5)
    shown(audience, @screen)

    speaker |> press("l")

    hidden(audience, @screen)
    assert dot(speaker, @current) == nil
    assert position(audience) == "1.1"
  end

  test "the slide does not show the cursor of the system while the pointer is on", %{
    audience: audience
  } do
    cursor = fn -> js(audience, "getComputedStyle(document.querySelector('.screen')).cursor") end

    assert cursor.() == "auto"
    audience |> press("l")
    assert cursor.() == "none"
  end

  test "the dot has the color of the role danger, and a deck can change it", %{audience: audience} do
    audience |> press("l") |> move(640, 360)
    shown(audience, @screen)

    color = fn ->
      js(audience, "getComputedStyle(document.getElementById('laser')).backgroundColor")
    end

    danger =
      js(audience, """
      (() => {
        const probe = document.createElement("div");
        probe.style.color = "var(--danger)";
        document.body.append(probe);
        const color = getComputedStyle(probe).color;
        probe.remove();
        return color;
      })()
      """)

    assert color.() == danger

    js(audience, "document.documentElement.style.setProperty('--laser-color', 'rgb(0, 128, 0)')")
    assert color.() == "rgb(0, 128, 0)"
  end

  test "the overview, the menu, the black screen and the handout view show no dot", %{
    audience: audience
  } do
    audience |> press("l") |> move(640, 360)
    shown(audience, @screen)

    for {open, close} <- [{"o", "Escape"}, {"m", "Escape"}, {"b", "b"}] do
      audience |> press(open)
      assert dot(audience, @screen) == nil, "the dot shows after #{open}"
      audience |> press(close) |> move(641, 361)
      shown(audience, @screen)
    end

    audience |> press("p")
    assert js(audience, "getComputedStyle(document.getElementById('laser')).display") == "none"
  end

  test "paper shows no dot", %{audience: audience} do
    audience |> press("l") |> move(640, 360)
    shown(audience, @screen)

    emulate(audience, "print")
    assert js(audience, "getComputedStyle(document.getElementById('laser')).display") == "none"
  end

  describe "with a touch screen" do
    setup %{browser: browser, tmp_dir: tmp_dir} do
      {:ok, context} =
        Browser.new_context(browser.guid,
          timeout: 10_000,
          viewport: %{width: 1280, height: 720},
          has_touch: true
        )

      on_exit(fn -> BrowserContext.close(context.guid, timeout: 10_000) end)
      {:ok, page} = BrowserContext.new_page(context.guid, timeout: 10_000)
      %{touch: open(page, render(Deck, tmp_dir))}
    end

    test "a tap moves the dot, and it does not change the step", %{touch: page} do
      page |> press("l") |> tap(960, 540)

      shown(page, @screen)
      assert dot(page, @screen) == [0.75, 0.75]
      assert position(page) == "1.1"
    end

    test "a swipe does not change the step while the pointer is on", %{touch: page} do
      page |> press("l") |> swipe({900, 360}, {300, 360})

      assert position(page) == "1.1"

      page |> press("l") |> swipe({900, 360}, {300, 360})
      assert position(page) == "1.2"
    end
  end
end
