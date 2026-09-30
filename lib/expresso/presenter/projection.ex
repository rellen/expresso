defmodule Expresso.Presenter.Projection do
  @moduledoc """
  Tells how the script writes a state to the document

  A **projection** is a rule that writes one part of the state to the document.
  `Expresso.Presenter.Default` declares the projections with three entities of
  the presenter DSL, and the script applies them after each change of the
  state:

    * `attribute` - writes a field of the state into an attribute of the
      `body`. `attribute :view, "data-view"` writes `data-view="present"`. With
      `flag: true`, the attribute is `"true"` while the field is true, and the
      script removes it while the field is false.
    * `property` - writes a value of the current entry of the list of the steps
      into a custom property of the `body`. `property "--fraction", :fraction`
      writes `--fraction: 0.5` at the middle of the deck.
    * `mark` - writes an attribute on each element that a selector finds, when
      a number of the element agrees with a field of the state.
      `mark "data-selected", ".handout-page[data-thumbnail]", :slide,
      [{"", :selected, 0}]` marks the page whose `data-slide` is the selected
      slide. The script removes the attribute from each other element that the
      selector finds.

  A mark can have more than one value. The script writes on an element the
  first value whose field, plus the offset, agrees with the number of the
  element.
  """

  defmodule Attribute do
    @moduledoc "The target of the `attribute` entity of the presenter DSL"

    @typedoc "A field of the state in an attribute of the `body`"
    @type t :: %__MODULE__{field: atom(), name: String.t(), flag: boolean()}

    defstruct [:field, :name, flag: false, __spark_metadata__: nil]
  end

  defmodule Property do
    @moduledoc "The target of the `property` entity of the presenter DSL"

    @typedoc "A value of the current entry in a custom property of the `body`"
    @type t :: %__MODULE__{name: String.t(), entry: :fraction | :done}

    defstruct [:name, :entry, __spark_metadata__: nil]
  end

  defmodule Mark do
    @moduledoc "The target of the `mark` entity of the presenter DSL"

    @typedoc """
    An attribute on the elements whose number agrees with a field of the state

    `key` names the number of an element: `:slide` reads `data-slide`, and
    `:index` reads `data-index`. Each value holds the text of the attribute, a
    field of the state and an offset.
    """
    @type t :: %__MODULE__{
            attribute: String.t(),
            selector: String.t(),
            key: :slide | :index,
            values: [{String.t(), atom(), integer()}]
          }

    defstruct [:attribute, :selector, :key, values: [], __spark_metadata__: nil]
  end

  @typedoc "The projections of a definition"
  @type t :: %{
          attributes: [Attribute.t()],
          properties: [Property.t()],
          marks: [Mark.t()]
        }

  @doc """
  Return the projections of the entities of a presenter module, in their order
  """
  @spec from([struct()]) :: t()
  def from(entities) do
    %{
      attributes: for(%Attribute{} = each <- entities, do: each),
      properties: for(%Property{} = each <- entities, do: each),
      marks: for(%Mark{} = each <- entities, do: each)
    }
  end

  @doc """
  Return the projections as the map that `Expresso.Presenter.Program.json/1`
  writes

      iex> alias Expresso.Presenter.Projection
      iex> Projection.json(%{
      ...>   attributes: [%Projection.Attribute{field: :blank, name: "data-blank", flag: true}],
      ...>   properties: [%Projection.Property{name: "--fraction", entry: :fraction}],
      ...>   marks: []
      ...> })
      %{
        "attributes" => [["blank", "data-blank", true]],
        "properties" => [["--fraction", "fraction"]],
        "marks" => []
      }
  """
  @spec json(t()) :: map()
  def json(projections) do
    %{
      "attributes" =>
        Enum.map(projections.attributes, &[Atom.to_string(&1.field), &1.name, &1.flag]),
      "properties" => Enum.map(projections.properties, &[&1.name, Atom.to_string(&1.entry)]),
      "marks" =>
        Enum.map(projections.marks, fn mark ->
          [
            mark.attribute,
            mark.selector,
            Atom.to_string(mark.key),
            Enum.map(mark.values, fn {text, field, offset} ->
              [text, Atom.to_string(field), offset]
            end)
          ]
        end)
    }
  end
end
