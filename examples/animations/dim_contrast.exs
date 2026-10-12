defmodule Examples.DimContrast do
  use Expresso

  theme :dracula
  dim_contrast 4.5

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      text """
      # Add one to the count, and reply with the new count.
      def handle_call(:increment, _from, count) do
        {:reply, count + 1, count + 1}
      end
      """

      highlight [2..2, 3..3]
    end
  end
end

Examples.DimContrast
