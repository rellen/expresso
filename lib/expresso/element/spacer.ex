defmodule Expresso.Element.Spacer do
  @moduledoc """
  An element that takes the free space of its container

  A spacer has no content. The theme gives it `flex-grow: 1`, so it pushes the
  elements after it to the end of the container. Two spacers around an element
  put the element in the middle.
  """

  use Expresso.Element

  @typedoc "The struct of a spacer"
  @type t :: %__MODULE__{}

  defstruct [:at, :steps, :el, :effect, :speed, :easing, on: [], __spark_metadata__: nil]

  @doc """
  Make a spacer
  """
  @spec new() :: t()
  def new, do: %__MODULE__{}

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(spacer) do
    %{overlay: Expresso.Overlay.Render.attributes(spacer)}
  end

  @doc """
  Make the HTML of a spacer
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      div class: "spacer", rest!: @overlay
    end
  end
end
