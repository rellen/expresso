defmodule Expresso.ClassOptionTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  doctest Expresso.Element

  defmodule ClassDeck do
    use Expresso

    slide "dense" do
      class("dense wide")

      text_box do
        class("boxed")
        text_area(text: "A text", class: "quiet")
      end

      list do
        class("steps")
        item "One", class: "first"
      end

      table do
        class("small")
        row ["a", "b"], class: "lit"
      end

      code "elixir" do
        class("tiny")
        text "a = 1"
      end

      columns do
        class("split")

        column do
          class("left")
          math "<math><mi>x</mi></math>", class: "big"
        end
      end

      quotation "Less is more.", class: "pull"
      spacer(class: "gap")
      image "test/fixtures/dot.png", alt: "A dot", class: "framed"
      diagram "test/fixtures/flow.svg", class: "chart"
    end

    slide "plain" do
      text_area(text: "No class")
    end
  end

  defp document,
    do: ClassDeck |> Expresso.parse() |> Expresso.Deck.render() |> Floki.parse_document!()

  defp classes(selector), do: document() |> Floki.find(selector) |> Floki.attribute("class")

  test "a slide gets its classes in the present view and on each page of the handout view" do
    assert classes(".screen section.slide") == ["slide dense wide", "slide"]
    assert classes(".handout section.handout-page") == ["handout-page dense wide", "handout-page"]
  end

  test "each element gets its classes after the class of the theme" do
    expected = [
      {".text-box", "text-box boxed"},
      {".text-area", "text-area quiet"},
      {".list", "list steps"},
      {".item", "item first"},
      {".table", "table small"},
      {".row", "row lit"},
      {".code", "code tiny"},
      {".columns", "columns split"},
      {".column", "column left"},
      {".math", "math big"},
      {".quotation", "quotation pull"},
      {".spacer", "spacer gap"},
      {".image", "image framed"},
      {".diagram", "diagram chart"}
    ]

    for {selector, class} <- expected do
      assert classes("#slide-1 " <> selector) == [class], selector
    end
  end

  test "an element without the option keeps the class of the theme only" do
    assert classes("#slide-2 .text-area") == ["text-area"]
  end

  test "Expresso.Builder takes the option on a slide and on an element" do
    document =
      [
        Builder.slide("one",
          class: "dense",
          elements: [Builder.text_area(text: "a", class: "x y")]
        )
      ]
      |> Builder.deck()
      |> Expresso.Deck.render()
      |> Floki.parse_document!()

    assert document |> Floki.find(".screen section.slide") |> Floki.attribute("class") ==
             ["slide dense"]

    assert document |> Floki.find(".screen .text-area") |> Floki.attribute("class") ==
             ["text-area x y"]
  end

  test "the compiler refuses a value that is not CSS class names" do
    source = """
    defmodule Expresso.ClassOptionTest.BadClass do
      use Expresso

      slide "one" do
        text_area(text: "a", class: ~s(a" onclick="x))
      end
    end
    """

    error = assert_raise Spark.Error.DslError, fn -> Code.compile_string(source) end
    assert Exception.message(error) =~ "a class option takes CSS class names"
  end

  test "class/1 refuses an empty value, a name with a bad character, and a term that is not a string" do
    for value <- ["", "   ", "1a", "a.b", "a>b", :dense, ["a"]] do
      assert {:error, _message} = Expresso.Element.class(value), inspect(value)
    end

    assert Expresso.Element.class("_a -b c-1") == {:ok, "_a -b c-1"}
  end
end
