defmodule Expresso.Element do
  @moduledoc """
  An element of a slide
  """

  defmacro __using__(_opts) do
    quote do
      import Temple
      use Temple.Component
    end
  end
end
