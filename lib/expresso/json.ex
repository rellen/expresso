defmodule Expresso.Json do
  @moduledoc """
  The JSON of a `script` element of the document

  The document holds data for the presenter in `script` elements of the type
  `application/json`: the list of the steps, the program of the presenter,
  and the sources of the embeds, the videos and the sounds. A text of the
  deck can hold `</script>`, and that text would close the element. Therefore
  `for_script/1` writes each `<` as `\\u003c`, which JSON reads as the same
  character.
  """

  @doc """
  Write a value as JSON for a `script` element

      iex> Expresso.Json.for_script(%{"text" => "</script>"})
      ~S({"text":"\\u003c/script>"})
  """
  @spec for_script(term()) :: String.t()
  def for_script(value), do: value |> JSON.encode!() |> String.replace("<", "\\u003c")
end
