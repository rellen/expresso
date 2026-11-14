defmodule Examples.Typewriter do
  use Expresso

  slide "type" do
    heading "A function"
    pause()

    text_box do
      at from: :next
      effect :type
      text_area(text: "Give the function a name, then call it.")
    end

    code "elixir" do
      reveal [1..3, 5]
      effect :type

      text ~S"""
      def greet(name) do
        "Hello, #{name}!"
      end

      greet("world")
      """
    end
  end
end

Examples.Typewriter
