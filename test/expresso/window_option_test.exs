defmodule Expresso.WindowOptionTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder

  doctest Expresso.Element.Window

  defp window(elements, deck_opts \\ []),
    do: elements |> one_slide([], deck_opts) |> document() |> screen(".window")

  defp classes(nodes), do: LazyHTML.attribute(nodes, "class")

  describe "the window option of an element" do
    test "each style gives its class, and a bar with the title before the content" do
      for style <- [:macos, :terminal, :plain] do
        frame = window(Builder.code("elixir", text: "x", window: style, window_title: "a.ex"))

        assert classes(frame) == ["window window-#{style}"]
        assert texts(frame, ".window-bar .window-title") == ["a.ex"]
        assert count(frame, ".window-bar + pre code.highlight") == 1
      end
    end

    test ":macos and :terminal have three dots that a screen reader does not read, and :plain has none" do
      for style <- [:macos, :terminal] do
        frame = window(Builder.code(text: "x", window: style))
        assert count(frame, ~s(.window-dots[aria-hidden="true"] > span)) == 3
      end

      assert count(window(Builder.code(text: "x", window: :plain)), ".window-dots") == 0
    end

    test "an image and an embed go into the frame too" do
      frame = window(Builder.image("test/fixtures/dot.png", window: :macos, window_title: "Shot"))
      assert classes(frame) == ["window window-macos"]
      assert count(frame, ".window-bar + img") == 1

      frame =
        window(Builder.embed("test/fixtures/page.html", title: "Page", window: :plain))

      assert count(frame, ".window-bar + .embed-box iframe") == 1
    end

    test "a code element with src shows the name of its file, and window_title replaces it" do
      assert window(Builder.code(src: "test/fixtures/code.js", window: :macos))
             |> texts(".window-title") == ["code.js"]

      assert window(
               Builder.code(src: "test/fixtures/code.js", window: :macos, window_title: "app")
             )
             |> texts(".window-title") == ["app"]

      assert window(Builder.code(text: "x", window: :macos)) |> texts(".window-title") == [""]
    end

    test "an element without the option has no frame" do
      assert window(Builder.code(text: "x")) |> Enum.count() == 0
    end

    test "the option takes only the styles" do
      assert_raise ArgumentError, ~r/invalid value for :window option/, fn ->
        Builder.code(text: "x", window: :windows)
      end
    end
  end

  describe "the window option of the deck" do
    test "gives its style to each code element, image and embed without the option" do
      elements = [
        Builder.code(text: "x"),
        Builder.image("test/fixtures/dot.png"),
        Builder.embed("test/fixtures/page.html", title: "Page")
      ]

      assert window(elements, window: :terminal) |> classes() ==
               List.duplicate("window window-terminal", 3)
    end

    test "an element replaces it, and :none turns it off" do
      elements = [Builder.code(text: "a", window: :plain), Builder.code(text: "b", window: :none)]

      assert window(elements, window: :macos) |> classes() == ["window window-plain"]
    end

    test "the deck has no frame without the option" do
      assert window(Builder.code(text: "x"), []) |> Enum.count() == 0
    end
  end
end
