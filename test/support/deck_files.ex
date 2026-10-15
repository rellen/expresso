defmodule Expresso.Test.DeckFiles do
  @moduledoc """
  Evaluates each deck file one time in the VM of the tests

  Several tests read the same example deck, such as
  `examples/line4/line4.exs`, and each evaluation compiles the modules of the
  deck again. `eval/1` evaluates a file the first time that a test asks for
  it, and it returns the same value to each later test. A later run of
  `mix test --repeat-until-failure` in the same VM gets the same value too.
  """

  @doc """
  Return the value of a deck file, as `Code.eval_file/1` returns it

  A lock for the path makes a second test wait for the first evaluation, so
  two async tests do not evaluate the same file at the same time.
  """
  @spec eval(Path.t()) :: term()
  def eval(path) do
    key = {__MODULE__, Path.expand(path)}

    :global.trans({key, self()}, fn ->
      case :persistent_term.get(key, :none) do
        :none ->
          {value, _bindings} = Code.eval_file(path)
          :persistent_term.put(key, value)
          value

        value ->
          value
      end
    end)
  end
end
