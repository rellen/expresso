defmodule Expresso.Test.Warnings do
  @moduledoc """
  Reads the warnings that a check of a slide returns

  A check such as `Expresso.Overlay.Size.slide/1` returns each warning as its
  text, or as a tuple of its text and its annotation.
  """

  @doc """
  Return the text of each warning
  """
  @spec texts([String.t() | {String.t(), term()}]) :: [String.t()]
  def texts(warnings), do: Enum.map(warnings, &text/1)

  defp text({text, _anno}), do: text
  defp text(text), do: text
end
