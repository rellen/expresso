defmodule Expresso.Presenter.Dsl do
  @moduledoc """
  The module that a presenter definition uses

  `use Expresso.Presenter.Dsl` gives a module the DSL of
  `Expresso.Presenter.Extension`. `Expresso.Presenter.Default` uses it.
  """

  use Spark.Dsl,
    default_extensions: [extensions: [Expresso.Presenter.Extension]]
end
