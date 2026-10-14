defmodule Expresso.Element.Icon do
  @moduledoc """
  An icon on its own, with a label under it

  The first argument names a Lucide icon, such as `"rocket"`, or a name of the
  `icons` option of the deck. `Expresso.IconTransformer` puts the SVG of the
  icon into the `svg` field at compile time. The icon takes the color of a
  role of the theme, and its size is a CSS length.

  Without a label, the icon is a decoration, and a screen reader skips it.
  With a label, the label is the caption of the icon, and a screen reader
  reads the label.
  """

  use Expresso.Element

  @typedoc "The struct of an icon"
  @type t :: %__MODULE__{}

  @colors [:text, :muted, :accent, :success, :emphasis, :warning, :danger]

  defstruct [
              :name,
              :label,
              :svg,
              :class,
              size: "3em",
              color: :text,
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Return the roles that the `color` option takes

      iex> Expresso.Element.Icon.colors()
      [:text, :muted, :accent, :success, :emphasis, :warning, :danger]
  """
  @spec colors() :: [atom()]
  def colors, do: @colors

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(%__MODULE__{} = icon) do
    %{
      svg: icon.svg,
      label: icon.label,
      color: icon.color |> Atom.to_string() |> String.replace("_", "-"),
      size: icon.size,
      overlay: Expresso.Overlay.Render.attributes(icon)
    }
  end

  @doc """
  Make the HTML of an icon

  The icon is a `figure` with the SVG and, with a label, a `figcaption`.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      figure class: Expresso.Element.classes("icon icon-#{@color}", assigns[:class]),
             style: "--icon-size: #{@size};",
             rest!: @overlay do
        Phoenix.HTML.raw(@svg)
        if @label, do: figcaption(class: "icon-label", do: @label)
      end
    end
  end
end
