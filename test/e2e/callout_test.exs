defmodule Expresso.E2E.CalloutTest do
  use Expresso.E2E, async: false

  # A warning dims at step 2, and a tip stays.
  defmodule Deck do
    use Expresso

    name "callout deck"
    theme :dracula

    slide "callouts" do
      callout :warning do
        on 2, state: :dim
        text_area(text: "A risk.")
      end

      callout :tip do
        text_area(text: "A better way.")
      end
    end
  end

  defp colors(page) do
    js(page, """
    Array.from(
      document.querySelectorAll(".screen .callout-title"),
      (title) => getComputedStyle(title).color
    )
    """)
    |> Enum.map(&rgb/1)
  end

  # The color of a custom property of the root, as the browser gives it.
  defp property(page, name) do
    js(page, """
    (() => {
      const probe = document.createElement("span");
      probe.style.color = "var(#{name})";
      document.body.append(probe);
      const color = getComputedStyle(probe).color;
      probe.remove();
      return color;
    })()
    """)
    |> rgb()
  end

  test "the header takes the color of the role of its kind, and the dimmed color when it dims",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))
    warning = property(page, "--warning")
    success = property(page, "--success")

    assert colors(page) == [warning, success]

    press(page, "j")
    assert colors(page) == [property(page, "--warning-dim"), success]
  end

  test "the icon of a header is in the color of the header, and the body text is not",
       %{page: page, tmp_dir: tmp_dir} do
    page = open(page, render(Deck, tmp_dir))

    [icon, body, text] =
      js(page, """
      (() => {
        const callout = document.querySelector(".screen .callout-tip");
        return [
          getComputedStyle(callout.querySelector(".callout-icon")).stroke,
          getComputedStyle(callout.querySelector(".callout-body .text-area")).color,
          getComputedStyle(document.body).color
        ];
      })()
      """)

    assert rgb(icon) == property(page, "--success")
    assert body == text
  end
end
