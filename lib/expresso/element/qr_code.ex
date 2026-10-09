defmodule Expresso.Element.QrCode do
  @moduledoc """
  An element that shows a QR code of a text, such as the address of the slides

  The `qr_code` entity takes the text as its first argument. `EQRCode` makes
  the matrix of the code at render time, and the render function writes it as
  one SVG `path`, with one square for each dark module. The SVG goes into the
  document, so the code needs no file and no script, and it prints.

  A scanner reads a dark code on a light ground best. Therefore the theme
  gives the code the colors `--qr-color` and `--qr-background`, and not the
  colors of the slide. The defaults are black and white in each theme. The
  code has a quiet zone of four modules around it, as the standard asks.

  The `size` option gives the width and the height of the code, as the
  `width` option of an image does. The render function writes it into the
  custom property `--qr-size`. The `label` option gives a line of text under
  the code. The `title` option gives the name of the code for a screen
  reader, and the default is the text of the code.
  """

  use Expresso.Element

  @typedoc "The struct of a QR code element"
  @type t :: %__MODULE__{}

  # The quiet zone of the standard, in modules, on each side of the code.
  @quiet 4

  # The error correction levels of the standard. A higher level makes a
  # larger code that a scanner reads when a part of it is not clear.
  @levels [:l, :m, :q, :h]

  defstruct [
    :class,
    :text,
    :size,
    :label,
    :title,
    :at,
    :steps,
    :el,
    :effect,
    :speed,
    :easing,
    level: :m,
    on: [],
    __spark_metadata__: nil
  ]

  @doc """
  Return the error correction levels that the `level` option takes

      iex> Expresso.Element.QrCode.levels()
      [:l, :m, :q, :h]
  """
  @spec levels() :: [atom()]
  def levels, do: @levels

  @doc """
  Make the assigns of the render function from the struct

  The key `overlay` holds the attributes of the overlay contract, from
  `Expresso.Overlay.Render.attributes/1`, and the `style` attribute of the
  `size` option. The key `path` holds the SVG path of the dark modules, and
  the key `side` holds the number of modules on a side, with the quiet zone.
  """
  @spec get_assigns(t()) :: map()
  def get_assigns(qr_code) do
    %__MODULE__{text: text, size: size, label: label, title: title, level: level} = qr_code
    {path, side} = path(text, level)

    %{
      path: path,
      side: side,
      label: label,
      title: title || text,
      overlay: Expresso.Overlay.Render.attributes(qr_code) ++ size(size)
    }
  end

  defp size(nil), do: []

  defp size(size),
    do: [{"style", "--qr-size: #{Expresso.Element.Image.viewport_unit(size)}"}]

  @doc """
  Return the SVG path of the dark modules of a QR code, and the number of
  modules on a side with the quiet zone

  Each dark module is a square of one unit. The path of a row joins the dark
  modules that touch, so a code of version 5 needs approximately 300 squares
  and not 600.

      iex> {path, side} = Expresso.Element.QrCode.path("hello", :m)
      iex> side
      29
      iex> String.starts_with?(path, "M4 4h7")
      true
  """
  @spec path(String.t(), atom()) :: {String.t(), pos_integer()}
  def path(text, level) do
    rows = text |> EQRCode.encode(level) |> rows()
    side = length(rows) + 2 * @quiet

    path =
      rows
      |> Enum.with_index(@quiet)
      |> Enum.flat_map(fn {row, y} -> runs(row, y) end)
      |> Enum.join()

    {path, side}
  end

  # `EQRCode` draws a quiet zone of two modules. The function removes it, so
  # the render function can draw the quiet zone of the standard.
  defp rows(%EQRCode.Matrix{matrix: matrix}) do
    rows = for row <- Tuple.to_list(matrix), do: Tuple.to_list(row)
    rows |> trim() |> Enum.map(&trim/1)
  end

  defp trim(list), do: list |> Enum.drop(2) |> Enum.drop(-2)

  # A run is a line of dark modules that touch: one rectangle of height 1.
  defp runs(row, y) do
    row
    |> Enum.with_index(@quiet)
    |> Enum.chunk_by(fn {module, _x} -> module == 1 end)
    |> Enum.flat_map(fn
      [{1, x} | _rest] = run -> ["M#{x} #{y}h#{length(run)}v1h-#{length(run)}z"]
      _light -> []
    end)
  end

  @doc """
  Make the HTML of a QR code
  """
  @spec render(map()) :: Phoenix.HTML.safe()
  def render(assigns) do
    temple do
      figure class: Expresso.Element.classes("qr-code", assigns[:class]), rest!: @overlay do
        svg viewBox: "0 0 #{@side} #{@side}",
            role: "img",
            aria_label: @title,
            shape_rendering: "crispEdges" do
          rect width: @side, height: @side, class: "qr-background"
          path d: @path, class: "qr-modules"
        end

        if @label do
          figcaption do
            div do
              @label
            end
          end
        end
      end
    end
  end
end
