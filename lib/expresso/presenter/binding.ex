defmodule Expresso.Presenter.Binding do
  @moduledoc """
  The target of the `key` and `event` entities of the presenter DSL

  A binding holds one or more events, a list of commands and its row in the
  list of keys. `Expresso.Presenter.Definition.from/1` makes a map of
  `t:Expresso.Presenter.Definition.binding/0` from it.
  """

  alias Expresso.Presenter.Definition

  @typedoc "A binding of the DSL"
  @type t :: %__MODULE__{
          keys: [String.t()] | nil,
          on: [Definition.event()],
          commands: [Definition.command()],
          text: String.t(),
          label: String.t() | nil,
          each: boolean()
        }

  defstruct [:keys, :commands, :text, :label, on: [], each: true, __spark_metadata__: nil]

  @doc """
  Make the events of a `key` entity from its keys

  Spark calls this function after it builds the entity.
  """
  @spec keys(t()) :: {:ok, t()}
  def keys(%__MODULE__{keys: keys} = binding),
    do: {:ok, %__MODULE__{binding | on: Enum.map(keys, &{:key, &1})}}
end
