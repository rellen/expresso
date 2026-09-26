defmodule Examples.OverlayDimCode do
  use Expresso

  slide "dim code" do
    heading "Dim the earlier lines"

    code "elixir" do
      reveal [1..3, 5, 6]
      dim true

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

Examples.OverlayDimCode
