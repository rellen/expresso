defmodule Expresso.GotoTest do
  use ExUnit.Case, async: true

  import Spark.Test, only: [dsl_errors: 1]

  alias Expresso.Element.TextArea
  alias Expresso.Goto
  alias Expresso.Presenter.{Definition, Help, Program}

  doctest Goto

  # Three slides. Slide 2 has two steps, so step 2 of slide 2 has the index 2
  # and step 1 of slide 3 has the index 3.
  defmodule LinkDeck do
    use Expresso

    name "link deck"

    slide "contents" do
      text_area(text: "The summary", goto: [slide: 3])
      image "test/fixtures/dot.png", alt: "A red dot", goto: [slide: 2, step: 2]

      list do
        item "Details" do
          goto slide: 2

          list do
            item "Inside"
          end
        end

        item "No link"
      end
    end

    slide "details" do
      text_area(text: "First")
      text_area(text: "Second", at: 2)
    end

    slide "summary" do
      text_area(text: "The end")
    end
  end

  defp document,
    do: LinkDeck |> Expresso.parse() |> Expresso.Deck.render() |> Floki.parse_document!()

  defp links(selector), do: Floki.find(document(), ".screen " <> selector)

  describe "new/1" do
    test "takes a slide, and a step with the default 1" do
      assert Goto.new(slide: 3) == {:ok, %Goto{slide: 3, step: 1}}
    end

    test "refuses a value that is not a slide and a step" do
      for value <- [3, [step: 2], [slide: 1, page: 2], [slide: "3"], [slide: 1, step: 0], "x"] do
        assert {:error, _message} = Goto.new(value), inspect(value)
      end
    end
  end

  describe "the document" do
    test "puts the text of a text area into a link with the address and the commands of its step" do
      [link] = links(".text-area a.goto")

      assert Floki.attribute(link, "href") == ["#3.1"]
      assert Floki.attribute(link, "data-commands") == [~s([["goto",3]])]
      assert Floki.text(link) =~ "The summary"
    end

    test "puts an image into a link, and the alt text names the link" do
      [link] = links(".image a.goto")

      assert Floki.attribute(link, "href") == ["#2.2"]
      assert Floki.attribute(link, "data-commands") == [~s([["goto",2]])]
      assert link |> Floki.find("img") |> Floki.attribute("alt") == ["A red dot"]
    end

    test "puts the text of an item into a link, and the nested list stays outside the link" do
      [link] = links(".item a.goto")

      assert Floki.attribute(link, "href") == ["#2.1"]
      assert Floki.text(link) =~ "Details"
      refute Floki.text(link) =~ "Inside"
      assert links(".item .item") |> Floki.text() =~ "Inside"
    end

    test "gives no link to an element without the option" do
      assert length(links("a.goto")) == 3
      assert length(Floki.find(document(), ".handout a.goto")) == 3
    end
  end

  describe "the verifier" do
    test "refuses a link to a slide that the deck does not have" do
      errors =
        dsl_errors do
          defmodule Elixir.Expresso.GotoTest.NoSlide do
            use Expresso

            slide "one" do
              text_area(text: "Next", goto: [slide: 2])
            end
          end
        end

      assert [{Expresso.GotoTest.NoSlide, [error]}] = errors
      assert Exception.message(error) =~ "goto names the slide 2, and the deck has 1 slides"
      assert Exception.message(error) =~ "deck -> slide -> one"
    end

    test "refuses a link to a step that the slide does not have" do
      errors =
        dsl_errors do
          defmodule Elixir.Expresso.GotoTest.NoStep do
            use Expresso

            slide "one" do
              list do
                item "Two", goto: [slide: 2, step: 3]
              end
            end

            slide "two" do
              text_area(text: "a", at: 2)
            end
          end
        end

      assert [{Expresso.GotoTest.NoStep, [error]}] = errors

      assert Exception.message(error) =~
               "goto names the step 3 of the slide 2, and it has 2 steps"
    end
  end

  describe "resolve/1" do
    test "raises for a link of a deck from the imperative API to a slide that it does not have" do
      deck =
        Expresso.Deck.new("imperative")
        |> Expresso.Deck.add_slide("one", %{}, [
          %TextArea{TextArea.new("Next") | goto: %Goto{slide: 2}}
        ])

      assert_raise ArgumentError, "goto names the slide 2, and the deck has 1 slides", fn ->
        Expresso.Deck.render(deck)
      end
    end
  end

  describe "the presenter" do
    test "the present view runs the commands of a link after the each commands" do
      present =
        Enum.find(
          Program.compile(Definition.presenter(), Expresso.parse(LinkDeck)).modes,
          &(&1.name == :present)
        )

      assert present.element == [{:clear, :digits}]
    end

    test "the list of keys of the present view has a row for a link" do
      rows = Definition.presenter() |> Help.rows() |> Keyword.fetch!(:present)

      assert {"Click or tap a link", "The slide and the step of the link"} in rows
    end
  end
end
