defmodule Expresso.Slide do
  @moduledoc """
  A slide
  """

  @type t :: %__MODULE__{:name => String.t() | nil, :metadata => map(), :data => Keyword.t()}

  defstruct [:name, :metadata, :data]

  @doc """
  Create a new slide
  """
  @spec new(name :: String.t() | nil, metadata :: map(), data :: Keyword.t()) :: t()
  def new(name, metadata \\ %{}, data \\ []) do
    %__MODULE__{name: name, metadata: metadata, data: data}
  end
end
