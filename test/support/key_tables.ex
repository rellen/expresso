defmodule Expresso.Test.KeyTables do
  @moduledoc """
  Makes the tables of keys in `README.md` from the definition of the presenter

  `Expresso.Presenter.Default` holds the keys of each mode. The table of a mode
  in `README.md` goes between two comments:

      <!-- keys present -->

      | Key | Action |
      ...

      <!-- /keys -->

  The test `Expresso.Presenter.KeyTablesTest` fails when a table does not agree
  with `table/1`. This command writes each table again:

      EXPRESSO_KEYS=write mix test test/expresso/presenter/key_tables_test.exs

  A table has the rows of the list of keys that `?` shows, in the same order.
  A key name goes in backticks. A label of a binding, such as `Click or tap a
  link`, does not.
  """

  alias Expresso.Presenter.{Definition, Help}

  @path "README.md"

  @table ~r/(<!-- keys (\w+) -->\n).*?(<!-- \/keys -->)/s

  @doc "Return the path of the file that holds the tables"
  @spec path() :: Path.t()
  def path, do: @path

  @doc "Return the names of the modes that have a table in a text, in their order"
  @spec modes(String.t()) :: [atom()]
  def modes(text) do
    for [_all, _open, mode, _close] <- Regex.scan(@table, text), do: String.to_atom(mode)
  end

  @doc "Return a text with each table written again"
  @spec write(String.t()) :: String.t()
  def write(text) do
    Regex.replace(@table, text, fn _all, open, mode, close ->
      open <> "\n" <> table(String.to_atom(mode)) <> "\n" <> close
    end)
  end

  @doc "Return the Markdown table of the keys of a mode"
  @spec table(atom()) :: String.t()
  def table(mode) do
    %{bindings: bindings} = Enum.find(Definition.presenter().modes, &(&1.name == mode))

    rows = for binding <- bindings, do: "| #{names(binding)} | #{binding.text} |\n"
    Enum.join(["| Key | Action |\n", "| --- | --- |\n" | rows])
  end

  defp names(%{label: label}) when is_binary(label), do: label

  defp names(binding) do
    binding |> Help.keys() |> Enum.map_join(", ", &"`#{&1}`")
  end
end
