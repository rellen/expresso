defmodule Examples.OverlayCode do
  use Expresso

  slide "code" do
    heading "Code"

    code "elixir" do
      reveal [1..3, 5..6]

      text ~S"""
      defmodule Greeter do
        def greet(name), do: "Hello, #{name}!"
      end

      Greeter.greet("world")
      |> IO.puts()
      """
    end
  end
end

Examples.OverlayCode
