defmodule Examples.ProjectRoot do
  use Expresso

  root __DIR__

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      src "counter.ex"
      lines from: "def handle_call(", to: "\n  end"
      line_numbers true
      reveal [12..13, 14..15]
    end
  end
end

Examples.ProjectRoot
