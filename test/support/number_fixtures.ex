defmodule Expresso.Test.NumberFixtures do
  @moduledoc """
  Makes the fixture of the number formats for the tests of the script

  `format` and `formatStat` in `assets/src/chart.ts` write the number of a
  count at each frame. They copy `Expresso.Element.Chart.Plot.label/1` and
  `Expresso.Element.Stat.format/3`. Node cannot run Elixir, so Git holds
  numbers and their texts from Elixir in `assets/test/fixtures/numbers.json`,
  and `assets/test/chart.test.ts` compares the script with them. The test
  `Expresso.NumberFixturesTest` fails when the file does not agree with
  `json/0`. This command writes the file again:

      EXPRESSO_FIXTURES=write mix test test/expresso/number_fixtures_test.exs

  The file holds two keys:

    * `"charts"` - the numbers of the frames of a chart, the decimals that the
      renderer writes in `data-decimals`, and the label of each number.
    * `"stats"` - a value of a stat, its decimals, its `group` option, and its
      text.
  """

  alias Expresso.Element.Chart.Plot
  alias Expresso.Element.Stat

  @path "assets/test/fixtures/numbers.json"

  # The numbers of the frames of each chart: integers, decimals, negative
  # numbers, numbers with more than six digits, halves and very small numbers.
  @charts [
    [10, 20],
    [30, 15.5],
    [12.25, 3],
    [-5, 2.5],
    [0.1, 0.2, 0.3],
    [1250, 1250.75],
    [1_234_567, 7_654_321],
    [1_234_567.5, 2],
    [99.999, 100],
    [1.005, 2.675],
    [-0.5, 0.25],
    [0.1234567, 1],
    [0.0001, 0.00025],
    [1.0e-7, 2.0e-7]
  ]

  # A value of a stat, its decimals and its `group` option. The values
  # between two whole numbers are frames of a count.
  @stats [
    {1250, 0, true},
    {1249.6, 0, true},
    {1249.5, 0, true},
    {1250, 0, false},
    {-1_234_567.5, 2, true},
    {1_234_567, 0, false},
    {999.999, 2, true},
    {-0.001, 2, true},
    {-0.5, 0, true},
    {12, 0, true},
    {12, 2, true},
    {12_345.675, 2, true},
    {0.125, 2, true},
    {4.2, 1, false},
    {1.5e-5, 6, true},
    {2.5e15, 0, true}
  ]

  @doc "Return the path of the file"
  @spec path() :: Path.t()
  def path, do: @path

  @doc "Return the text of the file, with one case on each line"
  @spec json() :: String.t()
  def json do
    charts =
      for numbers <- @charts do
        %{
          "numbers" => numbers,
          "decimals" => Plot.decimals(numbers),
          "labels" => Enum.map(numbers, &Plot.label/1)
        }
      end

    stats =
      for {value, decimals, group} <- @stats do
        %{
          "value" => value,
          "decimals" => decimals,
          "group" => group,
          "text" => Stat.format(value, decimals, group)
        }
      end

    """
    {
      "charts": [
    #{lines(charts)}
      ],
      "stats": [
    #{lines(stats)}
      ]
    }
    """
  end

  defp lines(cases), do: Enum.map_join(cases, ",\n", &("    " <> JSON.encode!(&1)))
end
