defmodule Expresso.Element.ColumnsTest do
  use ExUnit.Case, async: true

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

  defp slide(name) do
    Enum.find(Expresso.parse(ColumnsDeck).slides, &(&1.name == name))
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  describe "new/1 and new/2" do
    test "make columns from columns, with an optional width" do
      columns = Columns.new([Column.new([TextBox.new("a")], "40%"), Column.new([])])

      assert [%Column{width: "40%"}, %Column{width: nil, elements: []}] = columns.elements
    end
  end

  describe "the DSL entity" do
    test "holds columns, and a column holds the elements of a text box" do
      [columns] = slide("two").elements

      assert %Columns{steps: nil} = columns
      assert [%Column{width: "30%"} = left, %Column{width: nil} = right] = columns.elements
      assert [%Expresso.Element.TextArea{text: "Left"}] = left.elements
      assert [%Image{}, %Expresso.Element.List{}] = right.elements
    end

    test "gives a column the overlays" do
      [columns] = slide("two").elements
      [_left, right] = columns.elements

      assert right.steps == [1]
    end

    test "goes inside a text box" do
      [%TextBox{elements: [%Columns{elements: [_, _]}]}] = slide("in a box").elements
    end
  end

  describe "render/1" do
    setup do
      {:ok, document: ColumnsDeck |> document() |> Floki.parse_document!()}
    end

    test "writes a div with one div for each column", %{document: document} do
      [columns] = Floki.find(document, "#slide-1 .slide-main > .columns")

      assert [_, _] = Floki.find([columns], ":root > .column")
      assert document |> Floki.find("#slide-1 .column .text-area") |> Floki.text() == "Left"
    end

    test "writes the width option as custom properties on the column", %{document: document} do
      assert document |> Floki.find("#slide-1 .column") |> Floki.attribute("style") ==
               ["--column-width: 30%; --column-grow: 0"]
    end

    test "writes the overlay attributes on a column", %{document: document} do
      assert document |> Floki.find("#slide-1 .column") |> Floki.attribute("data-on") == ["1"]
    end
  end
end
