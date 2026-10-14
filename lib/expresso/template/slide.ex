defmodule Expresso.Template.Slide do
  @moduledoc """
  The behaviour of a slide template

  A slide template makes the body of a slide. `use Expresso.Template`
  declares this behaviour, so a module without `render/1` gets a warning from
  the compiler.
  """

  @doc """
  Make the body of a slide

  The assigns hold `@name`, `@metadata` and `@elements` of the slide.
  """
  @callback render(assigns :: map()) :: term()
end
