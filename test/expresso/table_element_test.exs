defmodule Expresso.Element.TableTest do
  use ExUnit.Case, async: true

  alias Expresso.Element.{Row, Table}

  defmodule TableDeck do
    use Expresso

    name "table deck"

    slide "plain" do
      table do
        header true
        row ["Name", "Value"]
        row ["one", "<b>1</b>"]
        row ["two", "2"]
      end
    end

    slide "reveal" do
      table do
        header true
        reveal true
        row ["Name", "Value"]
        row ["one", "1"]
        row ["two", "2"]
      end

      text_box do
        at :next
        text_area(text: "After the table")
      end
    end

    slide "no header" do
      text_box do
        table do
          reveal true
          row ["a"]
          row ["b"]
        end
      end
    end
  end

  defp slide(name) do
    Enum.find(Expresso.parse(TableDeck).slides, &(&1.name == name))
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  describe "new/2" do
    test "makes a table from rows" do
      table = Table.new([Row.new(["a", "b"]), Row.new(["c", "d"])], header: true)

      assert [%Row{cells: ["a", "b"]}, %Row{cells: ["c", "d"]}] = table.elements
      assert table.header == true
      assert table.reveal == false
    end
  end

  describe "the DSL entity" do
    test "holds rows, and a row holds its cells" do
      [table] = slide("plain").elements

      assert %Table{header: true, reveal: false} = table

      assert Enum.map(table.elements, & &1.cells) == [
               ["Name", "Value"],
               ["one", "<b>1</b>"],
               ["two", "2"]
             ]
    end

    test "reveals one row at each step, and the header shows with the table" do
      [table, box] = slide("reveal").elements

      assert Enum.map(table.elements, & &1.steps) == [nil, [1, 2, 3], [2, 3]]
      assert box.steps == [3]
    end

    test "reveals each row without the header option" do
      [%{elements: [table]}] = slide("no header").elements

      assert Enum.map(table.elements, & &1.steps) == [[1, 2], [2]]
    end
  end

  describe "render/1" do
    setup do
      {:ok, document: TableDeck |> document() |> Floki.parse_document!()}
    end

    test "writes the header row in a thead element with th cells", %{document: document} do
      assert [_] = Floki.find(document, "#slide-1 table.table > thead > tr.row")

      assert document |> Floki.find("#slide-1 thead th") |> Enum.map(&Floki.text/1) == [
               "Name",
               "Value"
             ]
    end

    test "writes the other rows in a tbody element with td cells", %{document: document} do
      assert [_, _] = Floki.find(document, "#slide-1 table.table > tbody > tr.row")

      assert document |> Floki.find("#slide-1 tbody td") |> Enum.map(&Floki.text/1) == [
               "one",
               "1",
               "two",
               "2"
             ]
    end

    test "writes a cell with raw HTML", %{document: document} do
      assert [_] = Floki.find(document, "#slide-1 tbody td > b")
    end

    test "writes no thead without the header option", %{document: document} do
      assert [] = Floki.find(document, "#slide-3 thead")
      assert [_, _] = Floki.find(document, "#slide-3 tbody tr.row")
    end

    test "writes the overlay attributes on each row", %{document: document} do
      rows = Floki.find(document, "#slide-2 tr.row")

      assert Floki.attribute(rows, "data-on") == ["1 2 3", "2 3"]
    end
  end
end
