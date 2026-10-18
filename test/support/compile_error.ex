defmodule Expresso.Test.CompileError do
  @moduledoc """
  Compiles a deck module that has an error, and returns the error

  Put `import Expresso.Test.CompileError` in the test module. A check that
  gives only errors runs in `Expresso.VerifierTransformer`, so its error stops
  the compile. `Spark.Test.dsl_errors/1` collects only the errors of a
  verifier, so it does not see these errors.
  """

  @doc """
  Compile the code of the block, make sure that the compile raises a `Spark.Error.DslError`, and return the error

  The block must not define a module that has no error, because the macro
  does not remove a module that the compile makes.
  """
  defmacro compile_error(do: block) do
    quote do
      ExUnit.Assertions.assert_raise(Spark.Error.DslError, fn ->
        Code.eval_quoted(unquote(Macro.escape(block)))
      end)
    end
  end
end
