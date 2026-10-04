defmodule Expresso.E2E.DimTest do
  use Expresso.E2E, async: false

  # An image and a part of a diagram dim at step 2. Their colors come from
  # their files, so they dim with the shared opacity of the theme.
  defmodule Deck do
    use Expresso

    name "dim deck"
    theme :dracula

    slide "graphics" do
      image "test/fixtures/dot.png" do
        alt "A dot"
        on 2, state: :dim
      end

      diagram "test/fixtures/flow.svg" do
        part "output" do
          on 2, state: :dim
        end
      end
    end
  end

  # The filter of the picture of the image, and of the wrapper of the part.
  defp filters(page) do
    js(page, """
    [
      getComputedStyle(document.querySelector(".screen .image img")).filter,
      getComputedStyle(document.querySelector(".screen .diagram-part")).filter,
      getComputedStyle(document.querySelector(".screen .diagram svg")).filter
    ]
    """)
  end

  test "an image and a part of a diagram dim with the shared opacity, and the SVG does not dim",
       %{page: page, tmp_dir: tmp_dir} do
    %{dim_opacity: opacity} = Expresso.Palette.Builtin.fetch!(:dracula)
    page = open(page, render(Deck, tmp_dir))

    assert filters(page) == ["opacity(1)", "blur(0px) opacity(1)", "opacity(1)"]

    press(page, "j")

    assert filters(page) == [
             "opacity(#{opacity})",
             "blur(0px) opacity(#{opacity})",
             "opacity(1)"
           ]
  end
end
