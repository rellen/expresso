defmodule Expresso.Example do
  @moduledoc """
  An example deck that uses the DSL
  """

  use Expresso

  name("my presso")

  slide do
    text_box do
      text_area do
        text "hello, world!!!"
      end
    end
  end
end
