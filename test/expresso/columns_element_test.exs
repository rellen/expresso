defmodule Expresso.Element.ColumnsTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML
  import Expresso.Test.Decks

  alias Expresso.Builder
  alias Expresso.Element.{Column, Columns, Image, TextBox}

  defmodule ColumnsDeck do
    use Expresso

    name "columns deck"

    slide "two" do
      columns do
        column do
          width "30%"
          text_area(text: "Left")
        end

        column do
          at from: :next
          image "test/fixtures/dot.png"

          list do
            item "Right"
          end
        end
      end
    end

    slide "in a box" do
      text_box do
        columns do
          column do
            text_area(text: "a")
          end

          column do
            text_area(text: "b")
          end
        end
      end
    end
  end

  describe "Expresso.Builder.columns/1" do
    test "makes columns from columns, with an optional width" do
      box = Builder.text_box(elements: [Builder.text_area(text: "a")])

      columns =
        Builder.columns(
          elements: [Builder.column(elements: [box], width: "40%"), Builder.column()]
        )

      assert [%Column{width: "40%"}, %Column{width: nil, elements: []}] = columns.elements
    end
  end

  describe "the DSL entity" do
    test "holds columns, and a column holds the elements of a text box" do
      [columns] = find_slide(ColumnsDeck, "two").elements

      assert %Columns{steps: nil} = columns
      assert [%Column{width: "30%"} = left, %Column{width: nil} = right] = columns.elements
      assert [%Expresso.Element.TextArea{text: "Left"}] = left.elements
      assert [%Image{}, %Expresso.Element.List{}] = right.elements
    end

    test "gives a column the overlays" do
      [columns] = find_slide(ColumnsDeck, "two").elements
      [_left, right] = columns.elements

      assert right.steps == [1]
    end

    test "goes inside a text box" do
      [%TextBox{elements: [%Columns{elements: [_, _]}]}] =
        find_slide(ColumnsDeck, "in a box").elements
    end
  end

  describe "render/1" do
    setup do
      {:ok, document: document(ColumnsDeck)}
    end

    test "writes a div with one div for each column", %{document: document} do
      assert count(document, "#slide-1 .slide-main > .columns") == 1
      assert count(document, "#slide-1 .slide-main > .columns > .column") == 2
      assert texts(document, "#slide-1 .column .text-area") == ["Left"]
    end

    test "writes the width option as custom properties on the column", %{document: document} do
      assert document |> LazyHTML.query("#slide-1 .column") |> LazyHTML.attribute("style") ==
               ["--column-width: 30%; --column-grow: 0"]
    end

    test "writes the overlay attributes on a column", %{document: document} do
      assert document |> LazyHTML.query("#slide-1 .column") |> LazyHTML.attribute("data-on") ==
               ["1"]
    end
  end
end
