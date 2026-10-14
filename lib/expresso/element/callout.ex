defmodule Expresso.Element.Callout do
  @moduledoc """
  A box with a kind, a title and other elements, such as a note or a warning

  A callout holds the elements that a text box holds. Its header shows an icon
  and the name of its kind, such as "Warning", in the color of the kind. The
  `title` option replaces the name, and `title false` removes the header. The
  icons are inline SVG, so they print and need no network.

  The color of each kind comes from a role of the theme:

  | Kind | Role |
  | --- | --- |
  | `:note` | `accent` |
  | `:tip` | `success` |
  | `:important` | `emphasis` |
  | `:warning` | `warning` |
  | `:caution` | `danger` |
  | `:definition` | `muted` |
  | `:example` | `success` |
  """

  use Expresso.Element

  @typedoc "The struct of a callout"
  @type t :: %__MODULE__{}

  @kinds [:note, :tip, :important, :warning, :caution, :definition, :example]

  # The paths of the icon of each kind, in a box of 24 units. Each icon has
  # lines of the color of the text, and no fill.
  @mark "M12 8v5 M12 16.5v.5"
  @icons %{
    note: "M12 2a10 10 0 1 0 0 20a10 10 0 1 0 0-20z M12 11v6 M12 7.5v.5",
    tip:
      "M9 18h6 M10 21h4 M12 3a6 6 0 0 0-3.6 10.8c.7.5 1.1 1.3 1.1 2.2h5c0-.9.4-1.7 1.1-2.2A6 6 0 0 0 12 3z",
    important:
      "M5 3h14a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2z " <> @mark,
    warning: "M12 3l10 18H2z " <> @mark,
    caution: "M8 2h8l6 6v8l-6 6H8l-6-6V8z " <> @mark,
    definition:
      "M3 4h6a3 3 0 0 1 3 3v14a2 2 0 0 0-2-2H3z M21 4h-6a3 3 0 0 0-3 3v14a2 2 0 0 1 2-2h7z",
    example: "M4 20h4L19 9l-4-4L4 16z M13 7l4 4"
  }

  defstruct [
              :kind,
              :class,
              title: nil,
              elements: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Return the kinds of a callout

      iex> Expresso.Element.Callout.kinds()
      [:note, :tip, :important, :warning, :caution, :definition, :example]
  """
  @spec kinds() :: [atom()]
  def kinds, do: @kinds

  @doc """
  Check the value of the `title` option: a string, or `false` for no header

      iex> Expresso.Element.Callout.title("Before you start")
      {:ok, "Before you start"}
      iex> Expresso.Element.Callout.title(false)
      {:ok, false}
      iex> Expresso.Element.Callout.title(true)
      {:error, "the title option of a callout is a string, or false for no header"}
  """
  @spec title(term()) :: {:ok, String.t() | false} | {:error, String.t()}
  def title(title) when is_binary(title) or title == false, do: {:ok, title}

  def title(_title),
    do: {:error, "the title option of a callout is a string, or false for no header"}

  @doc """
  Return the default title of a kind

      iex> Expresso.Element.Callout.default_title(:caution)
      "Caution"
  """
  @spec default_title(atom()) :: String.t()
  def default_title(kind), do: kind |> Atom.to_string() |> String.capitalize()

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `title` holds the text of
  the header, or `nil` for no header.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(%__MODULE__{} = callout) do
    title =
      case callout.title do
        false -> nil
        nil -> default_title(callout.kind)
        title -> title
      end

    %{
      kind: callout.kind,
      title: title,
      icon: Map.fetch!(@icons, callout.kind),
      elements: callout.elements,
      overlay: Expresso.Overlay.Render.attributes(callout)
    }
  end

  @doc """
  Make the HTML of a callout

  The box has the role `note`, so a screen reader names it. The header is a
  paragraph, and not a heading, so it does not change the outline of the
  slide.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      div class: Expresso.Element.classes("callout callout-#{@kind}", assigns[:class]),
          role: "note",
          rest!: @overlay do
        if @title do
          p class: "callout-title" do
            svg class: "callout-icon",
                viewBox: "0 0 24 24",
                "aria-hidden": "true",
                focusable: "false" do
              path d: @icon
            end

            span do: @title
          end
        end

        div class: "callout-body" do
          c(&Expresso.Template.render_elements(&1), elements: @elements)
        end
      end
    end
  end
end
