defmodule Expresso.BackgroundTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.{Background, Builder}

  doctest Expresso.Background

  @dark "test/fixtures/dark.png"

  defp slide(name, opts \\ []), do: Builder.slide(name, [elements: []] ++ opts)

  # The class and the style of each layer of the background of each slide of
  # the present view, in sequence. A slide with no background gives `nil`.
  defp layers(html) do
    for section <- LazyHTML.query(html, ".screen > .slide") do
      case section |> LazyHTML.query(".slide-background > *") |> Enum.to_list() do
        [] -> nil
        layers -> Enum.map(layers, &layer/1)
      end
    end
  end

  defp layer(layer) do
    {layer |> LazyHTML.attribute("class") |> hd(), layer |> LazyHTML.attribute("style") |> hd()}
  end

  describe "option/1" do
    test "takes a path, a keyword list of an image, a color and a gradient, and :none" do
      assert Background.option("photo.jpg") ==
               {:ok, %Background{kind: :image, image: "photo.jpg"}}

      assert Background.option(image: "a.png", fit: :contain, position: "left 20%", dim: 1) ==
               {:ok,
                %Background{
                  kind: :image,
                  image: "a.png",
                  fit: :contain,
                  position: "left 20%",
                  dim: 1
                }}

      assert {:ok, %Background{kind: :color, color: "#abc"}} = Background.option(color: "#abc")

      assert {:ok, %Background{kind: :gradient, gradient: [:accent, :text, "#000000"]}} =
               Background.option(gradient: [:accent, :text, "#000000"])

      assert Background.option(:none) == {:ok, :none}
    end

    test "refuses a value that is not one of the forms" do
      for value <- [nil, 5, "", [], :photo, [1, 2], %{image: "a.png"}] do
        assert {:error, message} = Background.option(value)
        assert message =~ "must be the path of an image, :none, or a keyword list", inspect(value)
      end
    end

    test "refuses a key that it does not know, and no kind or two kinds" do
      assert {:error, message} = Background.option(image: "a.png", blur: 2)
      assert message =~ "does not know the key :blur"

      assert {:error, message} = Background.option(dim: 0.5)
      assert message =~ "needs exactly one of image, color and gradient"

      assert {:error, message} = Background.option(image: "a.png", color: :accent)
      assert message =~ "needs exactly one of image, color and gradient"
    end

    test "refuses fit and position without an image, and angle without a gradient" do
      assert {:error, message} = Background.option(color: :accent, fit: :contain)

      assert message ==
               "the key fit of the background option is for a background with image, and this background has color"

      assert {:error, message} = Background.option(gradient: [:accent, :text], position: "top")
      assert message =~ "the key position of the background option is for a background with image"

      assert {:error, message} = Background.option(image: "a.png", angle: 90)
      assert message =~ "the key angle of the background option is for a background with gradient"
    end

    test "refuses a wrong value of each key" do
      errors = [
        {[image: :photo], "must be a path"},
        {[color: "red"], "is not a role of the theme or a hex color"},
        {[color: "#12"], "is not a role of the theme or a hex color"},
        {[color: "#fff; background: url(x)"], "is not a role of the theme or a hex color"},
        {[gradient: [:accent]], "must be a list of two colors or more"},
        {[gradient: [:accent, :pink]], "the color :pink"},
        {[image: "a.png", fit: :fill], "must be :cover or :contain"},
        {[image: "a.png", position: "middle"], "must be one or two of left, center, right"},
        {[image: "a.png", position: "top; x"], "must be one or two of left, center, right"},
        {[image: "a.png", dim: 1.5], "must be a number from 0 to 1"},
        {[image: "a.png", dim: "0.4"], "must be a number from 0 to 1"},
        {[gradient: [:accent, :text], angle: "90deg"], "must be a number of degrees"}
      ]

      for {value, text} <- errors do
        assert {:error, message} = Background.option(value)
        assert message =~ text, inspect(value)
      end
    end
  end

  describe "the document" do
    test "a slide with an image gets the image as the first element, behind a screen reader" do
      html = document(Builder.deck([slide("s", background: @dark)], name: "deck"))

      assert [first | _rest] =
               html |> LazyHTML.query(".screen > .slide > *") |> Enum.to_list()

      assert LazyHTML.attribute(first, "class") == ["slide-background"]
      assert LazyHTML.attribute(first, "aria-hidden") == ["true"]
      assert LazyHTML.attribute(first, "data-background") == ["image"]

      [image] = html |> LazyHTML.query(".screen .slide-background-image") |> Enum.to_list()
      assert ["data:image/png;base64," <> _data] = LazyHTML.attribute(image, "src")
      assert LazyHTML.attribute(image, "alt") == [""]
      assert LazyHTML.attribute(image, "style") == ["object-fit: cover; object-position: center;"]

      # No dim layer without the key `dim`.
      assert count(html, ".screen .slide-background-dim") == 0
    end

    test "the fit, the position and the dim layer go into the style" do
      background = [image: @dark, fit: :contain, position: "right bottom", dim: 0.4]
      html = document(Builder.deck([slide("s", background: background)], name: "deck"))

      assert layers(html) == [
               [
                 {"slide-background-image",
                  "object-fit: contain; object-position: right bottom;"},
                 {"slide-background-dim", "opacity: 0.4;"}
               ]
             ]
    end

    test "a color and a gradient are a layer with the custom property of each role" do
      slides = [
        slide("color", background: [color: :code_background]),
        slide("hex", background: [color: "#102030", dim: 0.5]),
        slide("gradient", background: [gradient: [:accent, :background], angle: 135])
      ]

      assert layers(document(Builder.deck(slides, name: "deck"))) == [
               [{"slide-background-fill", "background-color: var(--code-background);"}],
               [
                 {"slide-background-fill", "background-color: #102030;"},
                 {"slide-background-dim", "opacity: 0.5;"}
               ],
               [
                 {"slide-background-fill",
                  "background-image: linear-gradient(135deg, var(--accent), var(--background));"}
               ]
             ]
    end

    test "the option of the deck is the default, and a slide replaces it or turns it off" do
      slides = [
        slide("default"),
        slide("own", background: [color: "#102030"]),
        slide("none", background: :none)
      ]

      html = document(Builder.deck(slides, name: "deck", background: [color: :accent]))

      assert layers(html) == [
               [{"slide-background-fill", "background-color: var(--accent);"}],
               [{"slide-background-fill", "background-color: #102030;"}],
               nil
             ]
    end

    test "a deck with no background option has no background element" do
      html = document(Builder.deck([slide("s")], name: "deck"))

      assert count(html, ".slide-background") == 0
    end

    test "each copy of the slide has the background: the handout view and the menu" do
      html = document(Builder.deck([slide("s", background: @dark, steps: 2)], name: "deck"))

      assert count(html, ".screen .slide > .slide-background") == 1
      assert count(html, ".handout-page > .slide-background") == 2
      assert count(html, ".menu-thumb > .slide-background") == 1
    end

    test "the document holds a large image one time" do
      image = "examples/animations/demo.png"
      html = Expresso.Deck.render(Builder.deck([slide("s", background: image)], name: "deck"))
      [_head, data] = image |> Expresso.Image.data_uri!() |> String.split(",", parts: 2)

      assert length(String.split(html, data)) == 2
      assert html =~ ~s(data-asset-src="0")
    end

    test "the root option gives the directory of a relative path, for the deck and for a slide" do
      deck =
        Builder.deck(
          [slide("default"), slide("own", background: "light.png")],
          name: "deck",
          root: "test/fixtures",
          background: "dark.png"
        )

      assert deck.metadata.background.image == Path.expand("test/fixtures/dark.png")

      assert Enum.map(deck.slides, &(&1.metadata[:background] && &1.metadata.background.image)) ==
               [nil, Path.expand("test/fixtures/light.png")]

      assert count(document(deck), ".screen .slide-background-image") == 2
    end

    test "a file that the render cannot read stops the render with its path" do
      deck = Builder.deck([slide("s", background: "test/fixtures/none.png")], name: "deck")

      assert_raise ArgumentError, ~r{test/fixtures/none\.png}, fn ->
        Expresso.Deck.render(deck)
      end
    end

    test "the check gives no note for the image of a background" do
      html = Expresso.Deck.render(Builder.deck([slide("s", background: @dark)], name: "deck"))

      refute Enum.any?(Expresso.Check.Document.slides(html).notes, &(&1 =~ "no alt text"))
    end
  end

  describe "the option" do
    test "the DSL takes it in the deck and in a slide" do
      defmodule PhotoDeck do
        use Expresso

        background color: :code_background

        slide "photo" do
          background image: "test/fixtures/dark.png", dim: 0.4
          heading "A photo"
        end

        slide "plain" do
          background :none
          heading "Plain"
        end
      end

      {:ok, deck} = Expresso.to_deck(PhotoDeck)

      assert %Background{kind: :color, color: :code_background} = deck.metadata.background

      assert [%Background{kind: :image, dim: 0.4}, :none] =
               Enum.map(deck.slides, & &1.metadata.background)
    end

    test "the compiler refuses a wrong value with the message of the option" do
      assert_raise ArgumentError,
                   ~r/the dim of the background option must be a number from 0 to 1/,
                   fn ->
                     Builder.deck([slide("s", background: [color: :accent, dim: 2])],
                       name: "deck"
                     )
                   end
    end
  end
end
