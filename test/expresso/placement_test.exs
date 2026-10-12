defmodule Expresso.PlacementTest do
  use ExUnit.Case, async: true

  alias Expresso.Builder

  doctest Expresso.Placement

  # Compile a deck with one slide that holds the body.
  defp compile(body) do
    name = "Expresso.PlacementTest.D#{System.unique_integer([:positive])}"

    Code.compile_string("""
    defmodule #{name} do
      use Expresso

      slide "s" do
    #{body}
      end
    end
    """)

    Module.concat([name])
  end

  @refused [
    {"callout in callout", "a callout is inside a callout",
     ~s{callout :note do\n callout :tip do\n text_area(text: "x")\n end\n end}},
    {"columns in callout", "a columns is inside a callout",
     ~s{callout :note do\n columns do\n column do\n text_area(text: "x")\n end\n end\n end}},
    {"text box in text box", "a text_box is inside a text_box",
     ~s{text_box do\n text_box do\n text_area(text: "x")\n end\n end}},
    {"text box in column", "a text_box is inside a column",
     ~s{columns do\n column do\n text_box do\n text_area(text: "x")\n end\n end\n end}},
    {"columns in column", "a columns is inside a column",
     ~s{columns do\n column do\n columns do\n column do\n text_area(text: "x")\n end\n end\n end\n end}},
    {"column in column", "a column is inside a column",
     ~s{columns do\n column do\n column do\n text_area(text: "x")\n end\n end\n end}},
    {"footnote in text box", "a footnote is inside a text_box",
     ~s{text_box do\n footnote "x"\n end}},
    {"shape in callout", "a shape is inside a callout",
     ~s{callout :note do\n shape :line, from: ["0%", "0%"], to: ["10%", "10%"]\n end}},
    {"text area in item", "a text_area is inside a item",
     ~s{list do\n item "a" do\n text_area(text: "x")\n end\n end}}
  ]

  for {name, message, body} <- @refused do
    test "the compiler refuses #{name}" do
      error = assert_raise Spark.Error.DslError, fn -> compile(unquote(body)) end
      assert Exception.message(error) =~ unquote(message)
      assert Exception.message(error) =~ "deck -> slide -> s"
    end
  end

  test "the compiler accepts each place of the rules" do
    module =
      compile("""
      text_box do
        columns do
          column do
            callout :tip do
              list do
                item "a" do
                  list do
                    item "b" do
                      list do
                        item "c" do
                          list do
                            item "d"
                          end
                        end
                      end
                    end
                  end
                end
              end
            end
          end
        end

        callout :note do
          text_area(text: "x")
        end
      end

      footnote "A source"
      shape :line, from: ["0%", "0%"], to: ["10%", "10%"]
      """)

    assert {:ok, _deck} = Expresso.to_deck(module)
  end

  test "the children that a transformer adds are in their place" do
    slide =
      Builder.slide("s",
        elements: [Builder.code("elixir", text: "x = 1\ny = 2", reveal: [1, 2])]
      )

    assert Expresso.Placement.slide(slide) == :ok
  end

  test "the builder raises the same error" do
    slides = [
      Builder.slide("s", elements: [Builder.callout(:tip, elements: [Builder.columns()])])
    ]

    error = assert_raise Spark.Error.DslError, fn -> Builder.deck(slides, name: "x") end
    assert Exception.message(error) =~ "a columns is inside a callout"
  end

  test "an element at the level of the slide that only a parent holds is refused" do
    slide = Builder.slide("s", elements: [Builder.column()])

    assert Expresso.Placement.slide(slide) ==
             {:error,
              "a column is at the level of the slide, and a slide holds text_box, columns, " <>
                "callout, toc, text_area, image, list, table, quotation, spacer, code, math, " <>
                "diagram, embed, video, audio, qr_code, chart, stat, icon, footnote, shape"}
  end

  test "a pause inside an element is the check of the overlays, and not of the places" do
    slide = Builder.slide("s", elements: [Builder.text_box(elements: [Builder.pause()])])

    assert Expresso.Placement.slide(slide) == :ok
    assert {:error, message} = Expresso.Overlay.Check.slide(slide)
    assert message =~ "a pause entity is inside a text_box"
  end
end
