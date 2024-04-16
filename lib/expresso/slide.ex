defmodule Expresso.Slide do
  @moduledoc """
  A slide
  """

  @type t :: %__MODULE__{:name => String.t() | nil, :metadata => map(), :elements => Keyword.t()}

  defstruct [:name, :metadata, :elements]

  @doc """
  Create a new slide
  """
  @spec new(name :: String.t() | nil, metadata :: map(), elements :: Keyword.t()) :: t()
  def new(name, metadata \\ %{}, elements \\ []) do
    %__MODULE__{name: name, metadata: metadata, elements: elements}
  end

  def get_assigns(slide) do
    %__MODULE__{name: name, metadata: metadata, elements: elements} = slide
    %{name: name, metadata: metadata, elements: elements}
  end

  @doc """
  Add an element to a slide
  """
  @spec add_element(t(), term()) :: t()
  def add_element(slide, element) do
    %__MODULE__{elements: elements} = slide
    updated_elements = elements ++ [element]

    %__MODULE__{slide | elements: updated_elements}
  end
end
