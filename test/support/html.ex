defmodule Expresso.Test.HTML do
  @moduledoc """
  Shortens the LazyHTML queries that the unit tests use most

  "The HTML in a unit test" in `docs/development.md` tells how to write a test
  with LazyHTML. Put `import Expresso.Test.HTML` in the test module.
  """

  @doc """
  Return the number of the nodes that a selector finds
  """
  @spec count(LazyHTML.t(), String.t()) :: non_neg_integer()
  def count(html, selector), do: html |> LazyHTML.query(selector) |> Enum.count()

  @doc """
  Return the text of each node that a selector finds
  """
  @spec texts(LazyHTML.t(), String.t()) :: [String.t()]
  def texts(html, selector), do: html |> LazyHTML.query(selector) |> Enum.map(&LazyHTML.text/1)
end
