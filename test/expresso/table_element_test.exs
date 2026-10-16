defmodule Expresso.Element.TableTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
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

    slide "names" do
      table do
        caption "Orders each year"
        header true
        row_header true
        row [" ", "2024", "2025"]
        row ["Coffee", "120", "180"]
        row ["", "40", "60"]
      end

      table do
        caption "A hidden name"
        caption_hidden true
        row ["a", "1"]
      end
    end
  end

  defp slide(name) do
    Enum.find(Expresso.parse(TableDeck).slides, &(&1.name == name))
  end

  defp document(deck), do: deck |> Expresso.parse() |> Expresso.Deck.render()

  describe "Expresso.Builder.table/1" do
    test "makes a table from rows" do
      rows = [Builder.row(["a", "b"]), Builder.row(["c", "d"])]
      table = Builder.table(elements: rows, header: true)

      assert [%Row{cells: ["a", "b"]}, %Row{cells: ["c", "d"]}] = table.elements
      assert table.header == true
      assert table.reveal == false
      assert table.caption == nil
      assert table.caption_hidden == false
      assert table.row_header == false
    end

    test "takes a caption, a hidden caption and a row header" do
      table =
        Builder.table(
          elements: [Builder.row(["a", "b"])],
          caption: "Names",
          caption_hidden: true,
          row_header: true
        )

      assert %Table{caption: "Names", caption_hidden: true, row_header: true} = table
    end

    test "gives an error for caption_hidden without caption" do
      assert_raise ArgumentError,
                   "table: the caption_hidden option of a table needs the caption option",
                   fn -> Builder.table(elements: [Builder.row(["a"])], caption_hidden: true) end
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

    test "holds the caption and the row header options" do
      [table, hidden] = slide("names").elements

      assert %Table{caption: "Orders each year", caption_hidden: false, row_header: true} =
               table

      assert %Table{caption: "A hidden name", caption_hidden: true, row_header: false} = hidden
    end

    test "reports caption_hidden without caption" do
      source = """
      defmodule Expresso.Element.TableTest.HiddenNothing do
        use Expresso

        slide do
          table do
            caption_hidden true
            row ["a"]
          end
        end
      end
      """

      error = assert_raise Spark.Error.DslError, fn -> Code.compile_string(source) end

      assert Exception.message(error) =~
               "the caption_hidden option of a table needs the caption option"
    end
  end

  # LazyHTML parses the document as a browser does, and it takes each CSS
  # selector of a browser. A test that asserts that a table has no part finds
  # the table with `:not(:has(...))`. Thus a wrong selector finds no table, and
  # the test fails.
  describe "render/1" do
    setup do
      {:ok, document: TableDeck |> document() |> LazyHTML.from_document()}
    end

    test "writes the header row in a thead element with th cells", %{document: document} do
      assert count(document, "#slide-1 table.table > thead > tr.row") == 1
      assert texts(document, "#slide-1 thead th") == ["Name", "Value"]

      assert document |> LazyHTML.query("#slide-1 thead th") |> LazyHTML.attribute("scope") ==
               ["col", "col"]
    end

    test "writes the other rows in a tbody element with td cells", %{document: document} do
      assert count(document, "#slide-1 table.table > tbody > tr.row") == 2
      assert texts(document, "#slide-1 tbody td") == ["one", "1", "two", "2"]
    end

    test "writes a cell with raw HTML", %{document: document} do
      assert count(document, "#slide-1 tbody td > b") == 1
    end

    test "writes no thead without the header option", %{document: document} do
      assert count(document, "#slide-3 table.table:not(:has(thead))") == 1
      assert count(document, "#slide-3 tbody tr.row") == 2
    end

    test "writes the overlay attributes on each row", %{document: document} do
      rows = LazyHTML.query(document, "#slide-2 tr.row")

      assert LazyHTML.attribute(rows, "data-on") == ["1 2 3", "2 3"]
    end

    test "writes no caption and no row header without their options", %{document: document} do
      assert count(document, "#slide-1 table.table:not(:has(caption, tbody th))") == 1
    end

    test "writes the caption as the first child of the table", %{document: document} do
      captions = LazyHTML.query(document, "#slide-4 table.table > caption:first-child")

      assert Enum.map(captions, &LazyHTML.text/1) == ["Orders each year", "A hidden name"]
    end

    test "writes a hidden caption with the class table-caption-hidden", %{document: document} do
      assert document |> LazyHTML.query("#slide-4 caption") |> LazyHTML.attribute("class") == [
               "table-caption",
               "table-caption table-caption-hidden"
             ]

      assert texts(document, "#slide-4 caption.table-caption-hidden") == ["A hidden name"]
    end

    test "writes the first cell of each body row as the header of its row", %{
      document: document
    } do
      [names, hidden] = document |> LazyHTML.query("#slide-4 table.table") |> Enum.to_list()

      assert texts(names, "tbody th[scope=row]") == ["Coffee"]
      # The first cell of the last row has no text, so it is a td cell.
      assert texts(names, "tbody td") == ["120", "180", "", "40", "60"]
      assert count(hidden, "th") == 0
    end

    test "writes a cell with no text as a td cell", %{document: document} do
      [names, _hidden] = document |> LazyHTML.query("#slide-4 table.table") |> Enum.to_list()

      # `Expresso.Deck.render/1` passes the document through Floki, and Floki
      # drops a text node that is only white space. Thus the cell " " is empty.
      assert names |> LazyHTML.query("thead tr > td") |> LazyHTML.to_tree() == [{"td", [], []}]
      assert texts(names, "thead th") == ["2024", "2025"]
    end

    test "writes the caption as text and not as HTML" do
      html =
        [Builder.row(["a"])]
        |> then(&Builder.table(elements: &1, caption: "Tea & <b>coffee</b>"))
        |> Expresso.Element.assigns()
        |> Table.render()
        |> Phoenix.HTML.safe_to_string()

      assert html =~
               "<caption class=\"table-caption\">Tea &amp; &lt;b&gt;coffee&lt;/b&gt;</caption>"
    end
  end
end
