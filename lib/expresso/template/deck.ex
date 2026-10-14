defmodule Expresso.Template.Deck do
  @moduledoc """
  The behaviour of a deck template

  A deck template gives a header and a footer. `use Expresso.Template.Deck`
  imports Temple and `Expresso.Template`, so a template can call `c/2` with a
  component. It also declares this behaviour, so a module without `header/1`
  or `footer/1` gets a warning from the compiler.
  """

  @callback header(assigns :: map() | Keyword.t()) :: term()
  @callback footer(assigns :: map() | Keyword.t()) :: term()

  defmacro __using__(_) do
    quote do
      import Temple
      import Expresso.Template

      @behaviour Expresso.Template.Deck
    end
  end
end
