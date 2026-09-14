defmodule Expresso.Slide do
  @moduledoc """
  A slide
  """

  @type t :: %__MODULE__{
          :name => String.t() | nil,
          :heading => String.t() | nil,
          :steps => pos_integer() | nil,
          :metadata => map() | nil,
          :elements => list()
        }

  defstruct [:name, :heading, :steps, :metadata, :elements, __spark_metadata__: nil]

  @doc """
  Create a new slide
  """
  @spec new(name :: String.t() | nil, metadata :: map(), elements :: Keyword.t()) :: t()
  def new(name, metadata \\ %{}, elements \\ []) do
    %__MODULE__{name: name, metadata: metadata, elements: elements}
  end

  @doc """
  Make the assigns of a slide template from a slide
  """
  @spec get_assigns(t()) :: %{name: String.t() | nil, metadata: map() | nil, elements: list()}
  def get_assigns(slide) do
    %__MODULE__{name: name, metadata: metadata, elements: elements} = slide
    %{name: name, metadata: metadata, elements: elements}
  end

  @doc """
  Write the options of the DSL into the metadata of the slide

  The `slide` entity puts the `heading` option into the `heading` field. The
  templates read the heading from the metadata, as they do for a slide from
  `Expresso.Deck.add_slide/4`. This function puts the heading into the metadata,
  and it gives the metadata an empty map when the field is `nil`.
  """
  @spec put_options_in_metadata(t()) :: t()
  def put_options_in_metadata(%__MODULE__{heading: nil} = slide) do
    %__MODULE__{slide | metadata: slide.metadata || %{}}
  end

  def put_options_in_metadata(%__MODULE__{heading: heading, metadata: metadata} = slide) do
    %__MODULE__{slide | metadata: Map.put(metadata || %{}, :heading, heading)}
  end

  @doc """
  Add an element to a slide
  """
  @spec add_element(t(), term()) :: t()
  def add_element(%__MODULE__{elements: elements} = slide, element) do
    updated_elements = elements ++ [element]

    %__MODULE__{slide | elements: updated_elements}
  end
end
