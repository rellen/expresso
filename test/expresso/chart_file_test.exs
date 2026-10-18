defmodule Expresso.ChartFileTest do
  use ExUnit.Case, async: true

  import Expresso.Test.HTML

  alias Expresso.Builder
  alias Expresso.Element.Chart.Csv

  # The categories and the values of the one series of a chart with src.
  defp read(tmp_dir, name, text, opts \\ []) do
    path = Path.join(tmp_dir, name)
    File.write!(path, text)
    chart = Builder.chart(:bar, Keyword.merge([title: "Orders", src: path], opts))

    [%{elements: [chart]}] =
      one_slide(chart).slides

    {chart.categories, Enum.map(chart.elements, & &1.values)}
  end

  describe "the cells in quotes" do
    test "a cell in quotes holds the delimiter, a quote and a line break" do
      text = ~s(Plant,Orders\n"Leeds, Line 4",12\n"The ""new"" line",3\n"Two\nlines",4\n)

      assert {:ok, ["Leeds, Line 4", ~s(The "new" line), "Two\nlines"], [series]} =
               Csv.table(text, "a.csv")

      assert series.values == [12, 3, 4]
    end

    test "a row keeps the number of its first line, after a cell with a line break" do
      text = ~s(Plant,Orders\n"Two\nlines",4\nLeeds,x\n)

      assert Csv.table(text, "a.csv") ==
               {:error, "line 4 of the chart file \"a.csv\" needs 1 numbers"}
    end

    test "a number in quotes can have a comma between each group of three digits" do
      text = ~s(Plant,Orders,Hours\nLeeds,"1,250","12,500.5"\nYork,"-2,000,000",7\n)

      assert {:ok, ["Leeds", "York"], [orders, hours]} = Csv.table(text, "a.csv")
      assert orders.values == [1250, -2_000_000]
      assert hours.values == [12_500.5, 7]
    end

    test "a comma that does not divide groups of three digits is not a number" do
      for cell <- ["1,25", "1,2500", ",125", "3,5"] do
        assert {:error, message} = Csv.table(~s(Plant,Orders\nLeeds,"#{cell}"\n), "a.csv")
        assert message =~ "line 2 of the chart file"
      end
    end

    test "the spaces around a cell in quotes do not count, and the spaces in it do" do
      assert Csv.rows(~s(a , " b " , c\n), "a.csv") == {:ok, [{1, ["a", " b ", "c"]}]}
    end

    test "a quote with no closing quote and text after a closing quote are errors" do
      assert Csv.table(~s(Plant,Orders\n"Leeds,1\nYork,2\n), "a.csv") ==
               {:error, "line 2 of the chart file \"a.csv\" has a quote with no closing quote"}

      assert Csv.table(~s(Plant,Orders\n"Leeds"x,1\n), "a.csv") ==
               {:error,
                "line 2 of the chart file \"a.csv\" has text after the closing quote of a cell"}
    end

    test "a space as the delimiter divides the cells, also after a cell in quotes" do
      assert Csv.rows(~s(Plant Orders\n"Leeds, Line 4" 12\n), "a.csv", delimiter: " ") ==
               {:ok, [{1, ["Plant", "Orders"]}, {2, ["Leeds, Line 4", "12"]}]}
    end

    test "a quote in a cell without quotes is a part of the text" do
      assert Csv.rows(~s(Screen,Orders\n5" screen,3\n), "a.csv") ==
               {:ok, [{1, ["Screen", "Orders"]}, {2, [~s(5" screen), "3"]}]}
    end

    test "a file with Windows line ends gives the same rows" do
      assert Csv.rows("a,b\r\n\r\n\"x\r\ny\",2\r\n", "a.csv") ==
               {:ok, [{1, ["a", "b"]}, {3, ["x\ny", "2"]}]}
    end
  end

  describe "the byte order mark" do
    @describetag :tmp_dir

    # The format "CSV UTF-8" of Excel starts the file with the bytes EF BB BF.
    @mark <<0xEF, 0xBB, 0xBF>>

    test "the first column keeps its name for the frames", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "orders.csv")
      File.write!(path, @mark <> "year,region,Orders\n2024,North,3\n2025,North,5\n")

      [%{elements: [chart]}] =
        one_slide(Builder.chart(:bar, title: "Orders", src: path, frames: "year")).slides

      assert chart.categories == ["North"]
      assert Enum.map(chart.timeline, &hd(&1.elements).values) == [[3], [5]]
    end

    test "the first column keeps its name for the levels", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "hours.csv")
      File.write!(path, @mark <> "Division,Team,Hours\nOffice,Sales,15\n")

      [%{elements: [chart]}] =
        one_slide(
          Builder.chart(:treemap, title: "Hours", src: path, levels: ["Division", "Team"])
        ).slides

      assert chart.categories == [["Office", "Sales"]]
    end

    test "a first cell in quotes loses its quotes", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "months.csv")
      File.write!(path, @mark <> ~s("Month",Orders\nMay,3\n))

      [%{elements: [chart]}] =
        one_slide(Builder.chart(:bar, title: "Orders", src: path)).slides

      assert chart.category_label == "Month"
      assert chart.categories == ["May"]
    end
  end

  describe "the delimiter" do
    @describetag :tmp_dir

    test "a file that ends in .tsv has a tab between two cells", %{tmp_dir: tmp_dir} do
      text = "Plant\tOrders\nLeeds, Line 4\t1,250\nYork\t300\n"

      assert read(tmp_dir, "orders.tsv", text) == {["Leeds, Line 4", "York"], [[1250, 300]]}
      assert read(tmp_dir, "ORDERS.TSV", text) == {["Leeds, Line 4", "York"], [[1250, 300]]}
    end

    test "a tab in a file with tabs is not a space", %{tmp_dir: tmp_dir} do
      text = "Plant\tOrders\tReturns\nLeeds\t\t2\n"

      assert_raise Spark.Error.DslError, ~r/line 2 of the chart file .* needs 2 numbers/, fn ->
        read(tmp_dir, "orders.tsv", text)
      end
    end

    test "the delimiter option gives a different character", %{tmp_dir: tmp_dir} do
      assert read(tmp_dir, "orders.csv", "Plant;Orders\nLeeds; 12\nYork;3\n", delimiter: ";") ==
               {["Leeds", "York"], [[12, 3]]}

      assert read(tmp_dir, "orders.psv", "Plant|Orders\n\"A|B\"|12\n", delimiter: "|") ==
               {["A|B"], [[12]]}

      assert read(tmp_dir, "orders.txt", "Plant\tOrders\nLeeds\t12\n", delimiter: "\t") ==
               {["Leeds"], [[12]]}
    end

    test "the delimiter option works with frames and levels", %{tmp_dir: tmp_dir} do
      path = Path.join(tmp_dir, "hours.tsv")
      File.write!(path, "year\tDivision\tTeam\tHours\n2024\tOffice\t\t15\n2025\tOffice\t\t30\n")

      chart =
        Builder.chart(:treemap,
          title: "Hours",
          src: path,
          frames: "year",
          levels: ["Division", "Team"]
        )

      [%{elements: [chart]}] =
        one_slide(chart).slides

      assert chart.categories == [["Office"]]
      assert Enum.map(chart.timeline, &hd(&1.elements).values) == [[15], [30]]
    end

    test "the delimiter option is one character, not a quote or a line break, with src" do
      for delimiter <- ["", ";;", "\"", "\n"] do
        assert_raise ArgumentError, ~r/the delimiter option is one character/, fn ->
          Builder.chart(:bar, title: "x", src: "a.csv", delimiter: delimiter)
        end
      end

      assert_raise ArgumentError, ~r/the delimiter option .* needs the src option/, fn ->
        Builder.chart(:bar,
          title: "x",
          categories: ["a"],
          elements: [Builder.series("A", [1])],
          delimiter: ";"
        )
      end
    end
  end
end
