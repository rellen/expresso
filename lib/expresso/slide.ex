defmodule Expresso.Slide do
  @moduledoc """
  A slide
  """

  @type t :: %__MODULE__{
          :name => String.t() | nil,
          :heading => String.t() | nil,
          :notes => String.t() | nil,
          :steps => pos_integer() | nil,
          :handout => Expresso.Handout.t() | nil,
          :auto_reveal => boolean() | nil,
          :transition => :none | :fade | :slide | :zoom | nil,
          :metadata => map() | nil,
          :elements => list()
        }

  defstruct [
    :name,
    :heading,
    :notes,
    :steps,
    :handout,
    :auto_reveal,
    :transition,
    :metadata,
    :elements,
    __spark_metadata__: nil
  ]

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

  # The options of a slide that the metadata holds, for the templates, the
  # handout view and the renderer.
  @metadata_options [:heading, :notes, :handout, :transition]

  @doc """
  Write the options of the DSL into the metadata of the slide

  The `slide` entity puts the `heading` option into the `heading` field, and
  the `notes` option into the `notes` field. The templates and the renderer
  read each from the metadata, as they do for a slide from
  `Expresso.Deck.add_slide/4`. This function puts each option that is not
  `nil` into the metadata, and it gives the metadata an empty map when the
  field is `nil`.
  """
  @spec put_options_in_metadata(t()) :: t()
  def put_options_in_metadata(%__MODULE__{} = slide) do
    metadata =
      Enum.reduce(@metadata_options, slide.metadata || %{}, fn key, metadata ->
        case Map.fetch!(slide, key) do
          nil -> metadata
          value -> Map.put(metadata, key, value)
        end
      end)

    %__MODULE__{slide | metadata: metadata}
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
