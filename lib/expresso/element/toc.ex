defmodule Expresso.Element.Toc do
  @moduledoc """
  A table of contents: one entry for each section of the deck

  A slide with the `section` option starts a section, and the section runs to
  the next slide with a `section` option. `Expresso.SectionTransformer` puts
  one `Expresso.Element.TocEntry` into the toc for each section, with a link
  to the first slide of the section. The entries are the children of the toc,
  so the `reveal` option gives each entry its own step, and the `dim` option
  dims each entry when a later entry shows, as for the series of a chart.

  The section of the slide of the toc is the current section. Its entry takes
  the accent color. The `progress` option tells how the other entries look:

  | Value | The other entries |
  | --- | --- |
  | `:dim_rest` | Each other entry dims. This is the default. |
  | `:dim_earlier` | Each earlier entry dims. |
  | `:check_earlier` | Each earlier entry gets a check mark. |
  | `:strike_earlier` | A line goes through each earlier entry. |

  A toc on a slide before the first section has no current section, and each
  entry looks the same.
  """

  use Expresso.Element

  @typedoc "The struct of a table of contents"
  @type t :: %__MODULE__{}

  @progress [:dim_rest, :dim_earlier, :check_earlier, :strike_earlier]

  defstruct [
              :class,
              reveal: false,
              dim: false,
              progress: :dim_rest,
              elements: [],
              __spark_metadata__: nil
            ] ++ Expresso.Overlay.fields()

  @doc """
  Return the values of the `progress` option

      iex> Expresso.Element.Toc.progress_values()
      [:dim_rest, :dim_earlier, :check_earlier, :strike_earlier]
  """
  @spec progress_values() :: [atom()]
  def progress_values, do: @progress

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`. The key `entries` holds the
  entries, each with its own attributes.
  """
  @spec get_assigns(t()) :: map()
  @impl Expresso.Element
  def get_assigns(%__MODULE__{} = toc) do
    %{
      progress: toc.progress |> Atom.to_string() |> String.replace("_", "-"),
      entries: toc.elements || [],
      overlay: Expresso.Overlay.Render.attributes(toc)
    }
  end

  @doc """
  Make the HTML of a table of contents

  The toc is a `nav` with an ordered list. The entry of the current section
  has `aria-current="location"`, so a screen reader names it. Each entry is a
  link of the `goto` option to the first slide of its section.
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  @impl Expresso.Element
  def render(assigns) do
    temple do
      nav class: Expresso.Element.classes("toc toc-#{@progress}", assigns[:class]),
          "aria-label": "Contents",
          rest!: @overlay do
        ol class: "toc-list" do
          for entry <- @entries do
            li class: Expresso.Element.classes("toc-entry toc-#{entry.place}", entry.class),
               "aria-current": entry.place == :current && "location",
               rest!: Expresso.Overlay.Render.attributes(entry) do
              a class: "goto toc-link",
                href: Expresso.Goto.href(entry.goto),
                data_link: entry.goto.index do
                entry.text
              end
            end
          end
        end
      end
    end
  end
end
