defmodule Expresso.Template.Deck do
  use Expresso.Template

  @callback header(assigns :: map() | Keyword.t()) :: term()
  @callback footer(assigns :: map() | Keyword.t()) :: term()

  defmacro __using__(_) do
    quote do
      import Temple
      import unquote(__MODULE__)

      @behaviour Expresso.Template.Deck
    end
  end
end
