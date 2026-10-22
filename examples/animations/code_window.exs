defmodule Examples.CodeWindow do
  use Expresso

  root __DIR__
  window(:macos)

  slide "the counter" do
    heading "The counter"

    code "elixir" do
      src "counter.ex"
      lines 8..15
      highlight [[from: "def init"], [from: "def handle_call", to: :block]]
    end
  end

  slide "the tests" do
    heading "The tests"

    code do
      window(:terminal)
      window_title("~/counter — zsh")

      text """
      $ mix test
      ...
      Finished in 0.02 seconds (0.00s async, 0.02s sync)
      3 tests, 0 failures
      """
    end
  end
end

Examples.CodeWindow
