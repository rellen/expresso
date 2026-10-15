defmodule Expresso.Presenter.Schema.Record do
  @moduledoc """
  Writes a value as the array of a record form of `Expresso.Presenter.Schema`

  A record form gives the order of the values in the array.
  `Expresso.Test.SchemaWriter` makes the converter of the script from the
  same form, so the renderer and the script use one order.
  """

  alias Expresso.Presenter.Schema

  # The keys of each record form, in order. A union of records has the keys of
  # its first record, and the schema test makes sure that each record of the
  # union has the same keys.
  @keys (for {name, _doc, form} <- Schema.types(),
             {:record, fields} <-
               (case form do
                  {:union, [first | _others]} -> [first]
                  form -> [form]
                end),
             into: %{} do
           {name, Keyword.keys(fields)}
         end)

  @doc """
  Return the array of a value for a record form: the value of each field, in
  the order of the form

  `value` is a map or a struct with a key for each field.

      iex> Expresso.Presenter.Schema.Record.write(:written_property, %{
      ...>   entry: "fraction",
      ...>   name: "--fraction"
      ...> })
      ["--fraction", "fraction"]
  """
  @spec write(atom(), map()) :: list()
  def write(name, value), do: Enum.map(Map.fetch!(@keys, name), &Map.fetch!(value, &1))

  @doc "Return the name of each record form"
  @spec names() :: [atom()]
  def names, do: Map.keys(@keys)
end
