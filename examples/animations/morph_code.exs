defmodule Examples.MorphCode do
  use Expresso

  slide "first" do
    heading "A greeting"

    code "elixir" do
      text """
      def greet(name) do
        "Hello, " <> name
      end
      """
    end
  end

  slide "second" do
    heading "A greeting"

    code "elixir" do
      text """
      def greet(name, greeting \\\\ "Hello") do
        greeting <> ", " <> name
      end
      """
    end
  end
end

Examples.MorphCode
