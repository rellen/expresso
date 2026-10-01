defmodule Expresso.Slide do
  @moduledoc """
  A slide
  """

  @type t :: %__MODULE__{
          :name => String.t() | nil,
          :heading => String.t() | nil,
          :template => module() | {:builtins, atom()} | nil,
          :notes => String.t() | nil,
          :steps => pos_integer() | nil,
          :handout => Expresso.Handout.t() | nil,
          :auto_reveal => boolean() | nil,
          :transition => :none | :fade | :slide | :zoom | nil,
          :effect => atom() | nil,
          :speed => atom() | pos_integer() | nil,
          :easing => atom() | nil,
          :metadata => map() | nil,
          :elements => list()
        }

  defstruct [
    :name,
    :heading,
    :template,
    :notes,
    :steps,
    :handout,
    :auto_reveal,
    :transition,
    :effect,
    :speed,
    :easing,
    :metadata,
    :elements,
    __spark_metadata__: nil
  ]

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
  @metadata_options [:heading, :template, :notes, :handout, :transition, :effect, :speed, :easing]

  @doc """
  Write the options of the DSL into the metadata of the slide

  The `slide` entity puts the `heading` option into the `heading` field, and
  the `notes` option into the `notes` field. The templates and the renderer
  read each from the metadata. This function puts each option that is not
  `nil` into the metadata, and it gives the metadata an empty map when the
  field is `nil`.
  """
  @spec put_options_in_metadata(t()) :: t()
  def put_options_in_metadata(%__MODULE__{} = slide) do
    metadata =
      Enum.reduce(@metadata_options, slide.metadata || %{}, fn key, metadata ->
        Shoddy.Maps.put_present(metadata, key, Map.fetch!(slide, key))
      end)

    %__MODULE__{slide | metadata: metadata}
  end
end
