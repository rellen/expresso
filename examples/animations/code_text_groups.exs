defmodule Examples.CodeTextGroups do
  use Expresso

  root __DIR__

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      src "counter.ex"
      lines from: "def handle_call(", to: :block
      line_numbers true
      highlight [[from: "def handle_call("], [from: "next = ", to: "{:reply"]]
    end
  end
end

Examples.CodeTextGroups
