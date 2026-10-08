defmodule Examples.CodeUndim do
  use Expresso

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      src "examples/animations/counter.ex"
      lines from: "def handle_call(", to: "\n  end"
      line_numbers true
      highlight [13, 14]
    end
  end
end

Examples.CodeUndim
