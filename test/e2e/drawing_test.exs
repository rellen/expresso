defmodule Expresso.E2E.DrawingTest do
  use Expresso.E2E, async: false

  alias PlaywrightEx.Page

  # Slide 1 has two steps, and slide 2 has one step.
  defmodule Deck do
    use Expresso

    name "drawing deck"

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

  @screen ".screen"
  @current ~s(.handout-page[data-speaker="current"])

  # Drag the mouse through points of the box of the slide, with the main
  # button. Each point is a part of the width and of the height of the box.
  defp drag(page, selector, [first | rest]) do
    [left, top, width, height] =
      js(page, """
      (() => {
        const box = document.querySelector(#{JSON.encode!(selector)}).getBoundingClientRect();
        return [box.left, box.top, box.width, box.height];
      })()
      """)

    move = fn {x, y} ->
      {:ok, _result} =
        Page.mouse_move(page.guid, timeout: 10_000, x: left + x * width, y: top + y * height)
    end

    move.(first)
    {:ok, _result} = Page.mouse_down(page.guid, timeout: 10_000)
    Enum.each(rest, move)
    {:ok, _result} = Page.mouse_up(page.guid, timeout: 10_000)
    page
  end

  # The class and the path of each line that a window shows, or an empty
  # list while the layer of the drawing does not show.
  defp lines(page) do
    js(page, """
    (() => {
      const layer = document.getElementById("drawing");
      if (getComputedStyle(layer).display === "none") return [];
      return [...layer.querySelectorAll("path")]
        .map((path) => [path.getAttribute("class"), path.getAttribute("d")]);
    })()
    """)
  end

  defp count_js(count),
    do: ~s|document.querySelectorAll("#drawing path").length === #{count}|

  test "a drag draws no line while the drawing is off", %{audience: audience} do
    audience |> drag(@screen, [{0.5, 0.3}, {0.9, 0.3}])

    # The release of the mouse is a click, which changes the step as before.
    assert lines(audience) == []
    assert position(audience) == "1.2"
  end

  test "a line of the speaker view shows in the present view on the same part of the slide", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("x") |> drag(@current, [{0.25, 0.5}, {0.5, 0.5}, {0.5, 0.75}])

    wait_for(audience, count_js(1))
    line = [["drawing-pen", "M0.25 0.5L0.5 0.5L0.5 0.75"]]
    assert lines(speaker) == line
    assert lines(audience) == line

    # The line is on the same part of the slide in each window.
    [width, height] =
      js(audience, """
      (() => {
        const box = document.querySelector("#drawing path").getBoundingClientRect();
        return [Math.round(box.width), Math.round(box.height)];
      })()
      """)

    assert [width, height] == [320, 180]
    assert position(audience) == "1.1"
  end

  test "a line of the present view shows in the speaker view", %{
    audience: audience,
    speaker: speaker
  } do
    audience |> press("x") |> drag(@screen, [{0.1, 0.1}, {0.9, 0.9}])

    wait_for(speaker, count_js(1))
    assert lines(speaker) == [["drawing-pen", "M0.1 0.1L0.9 0.9"]]
  end

  test "h changes the pen to the highlighter, which is a wide line", %{
    audience: audience,
    speaker: speaker
  } do
    speaker
    |> press("x")
    |> drag(@current, [{0.2, 0.2}, {0.4, 0.2}])
    |> press("h")
    |> drag(@current, [{0.2, 0.6}, {0.8, 0.6}])

    wait_for(audience, count_js(2))

    assert lines(audience) == [
             ["drawing-pen", "M0.2 0.2L0.4 0.2"],
             ["drawing-highlighter", "M0.2 0.6L0.8 0.6"]
           ]

    [pen, highlighter] =
      js(audience, """
      [...document.querySelectorAll("#drawing path")]
        .map((path) => parseFloat(getComputedStyle(path).strokeWidth))
      """)

    assert highlighter > pen * 3

    # A line of the speaker view is as thin as its slide is small.
    [small | _rest] =
      js(speaker, """
      [...document.querySelectorAll("#drawing path")]
        .map((path) => parseFloat(getComputedStyle(path).strokeWidth))
      """)

    assert small < pen
  end

  test "the next step keeps the drawing, and the next slide removes it", %{
    audience: audience,
    speaker: speaker
  } do
    speaker |> press("x") |> drag(@current, [{0.2, 0.2}, {0.4, 0.2}])
    wait_for(audience, count_js(1))

    speaker |> press("j")
    wait_for(audience, "location.hash === '#1.2'")
    assert length(lines(audience)) == 1
    assert length(lines(speaker)) == 1

    speaker |> press("j")
    wait_for(audience, "location.hash === '#2.1'")
    wait_for(audience, count_js(0))
    assert lines(speaker) == []

    # The drawing does not come back with the slide.
    speaker |> press("k")
    wait_for(audience, "location.hash === '#1.2'")
    assert lines(audience) == []
  end

  test "c removes the drawing in the two windows", %{audience: audience, speaker: speaker} do
    speaker |> press("x") |> drag(@current, [{0.2, 0.2}, {0.4, 0.2}])
    wait_for(audience, count_js(1))

    speaker |> press("c")

    wait_for(audience, count_js(0))
    assert lines(speaker) == []
  end

  test "a click does not change the step while the drawing is on", %{
    audience: audience,
    speaker: speaker
  } do
    audience |> press("x") |> click(1000, 360)

    assert position(audience) == "1.1"
    wait_for(speaker, count_js(1))

    audience |> press("x") |> click(1000, 360)
    assert position(audience) == "1.2"
  end

  test "a drag over a text draws a line, and it does not select the text", %{audience: audience} do
    [left, top, width, height] =
      js(audience, """
      (() => {
        const box = document.querySelector(".screen .text-area").getBoundingClientRect();
        return [box.left / innerWidth, box.top / innerHeight, box.width / innerWidth, box.height / innerHeight];
      })()
      """)

    middle = top + height / 2
    audience |> press("x") |> drag(@screen, [{left, middle}, {left + width, middle}])

    assert length(lines(audience)) == 1
    assert js(audience, "getSelection().toString()") == ""
  end

  test "the slide shows a cross while the drawing is on", %{audience: audience} do
    cursor = fn -> js(audience, "getComputedStyle(document.querySelector('.screen')).cursor") end

    assert cursor.() == "auto"
    audience |> press("x")
    assert cursor.() == "crosshair"
  end

  test "the overview, the menu, the black screen, the handout view and paper show no drawing", %{
    audience: audience
  } do
    audience |> press("x") |> drag(@screen, [{0.2, 0.2}, {0.4, 0.2}])
    assert length(lines(audience)) == 1

    for {open, close} <- [{"o", "Escape"}, {"m", "Escape"}, {"b", "b"}] do
      audience |> press(open)
      assert lines(audience) == [], "the drawing shows after #{open}"
      audience |> press(close)
      assert length(lines(audience)) == 1
    end

    audience |> press("p")
    assert lines(audience) == []
    audience |> press("p")

    emulate(audience, "print")
    assert lines(audience) == []
  end

  test "a speaker view that opens after a line gets the drawing", %{
    audience: audience,
    speaker: speaker
  } do
    audience |> press("x") |> drag(@screen, [{0.3, 0.3}, {0.6, 0.3}])
    wait_for(speaker, count_js(1))

    reload(speaker)

    wait_for(speaker, count_js(1))
    assert lines(speaker) == [["drawing-pen", "M0.3 0.3L0.6 0.3"]]
  end

  test "the colors of the tools are the roles danger and warning, and a deck can change them", %{
    audience: audience
  } do
    audience
    |> press("x")
    |> drag(@screen, [{0.2, 0.2}, {0.4, 0.2}])
    |> press("h")
    |> drag(@screen, [{0.2, 0.6}, {0.4, 0.6}])

    colors = fn ->
      js(audience, """
      [...document.querySelectorAll("#drawing path")].map((path) => getComputedStyle(path).stroke)
      """)
    end

    role = fn name ->
      js(audience, """
      (() => {
        const probe = document.createElement("div");
        probe.style.color = "var(--#{name})";
        document.body.append(probe);
        const color = getComputedStyle(probe).color;
        probe.remove();
        return color;
      })()
      """)
    end

    assert colors.() == [role.("danger"), role.("warning")]

    js(audience, """
    (() => {
      const style = document.documentElement.style;
      style.setProperty("--draw-pen-color", "rgb(0, 0, 255)");
      style.setProperty("--draw-highlighter-color", "rgb(0, 255, 0)");
    })()
    """)

    assert colors.() == ["rgb(0, 0, 255)", "rgb(0, 255, 0)"]
  end
end
