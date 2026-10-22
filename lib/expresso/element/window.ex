defmodule Expresso.Element.Window do
  @moduledoc """
  A frame that looks like a window of an operating system, around a code
  element, an image or an embedded page

  The `window` option of the element gives the style of the frame. The
  `window` option of the deck gives the style of each such element without
  the option. These are the styles:

    * `:macos` — round corners, a bar with three colored dots at the left and
      the title at the center.
    * `:terminal` — the same dots, and the title at the left in the font of
      the code. The bar has the color of the code.
    * `:plain` — a bar with only the title.
    * `:none` — no frame. An element gives it to turn off the style of the
      deck.

  The `window_title` option gives the text of the bar. A code element with
  `src` and without the option shows the name of its file, such as
  `server.ex`.

  `apply/1` gives each element its style and its title before the render.
  `wrap/3` then puts the HTML of the element into the frame.
  """

  import Temple

  alias Expresso.Element.{Code, Embed, Image, Tree}

  @styles [:macos, :terminal, :plain, :none]

  @doc "The values of the `window` option"
  @spec styles() :: [atom()]
  def styles, do: @styles

  @doc """
  Give each code element, image and embedded page its style and its title

  An element without the `window` option takes the `:window` key of the
  metadata of the deck. The style `:none` becomes `nil`. A code element with
  `src` and without `window_title` takes the name of its file.

      iex> code = %Expresso.Element.Code{src: "lib/my_app/server.ex"}
      iex> deck = Expresso.Deck.new("d", %{window: :macos}, [%Expresso.Slide{elements: [code]}])
      iex> [%{elements: [code]}] = Expresso.Element.Window.apply(deck).slides
      iex> {code.window, code.window_title}
      {:macos, "server.ex"}
  """
  @spec apply(Expresso.Deck.t()) :: Expresso.Deck.t()
  def apply(%Expresso.Deck{metadata: metadata} = deck) do
    default = (metadata || %{})[:window]
    Tree.map_deck(deck, &element(&1, default))
  end

  defp element(%module{} = element, default) when module in [Code, Image, Embed] do
    case element.window || default do
      style when style in [nil, :none] -> %{element | window: nil}
      style -> %{element | window: style, window_title: title(element)}
    end
  end

  defp element(element, _default), do: element

  defp title(%Code{window_title: nil, src: src}) when is_binary(src), do: Path.basename(src)
  defp title(element), do: element.window_title

  @doc """
  Put the HTML of an element into the frame of its style

  The frame is a `div` with the classes `window` and `window-<style>`. It
  holds a `div` with the class `window-bar`, then the HTML of the element. A
  screen reader does not read the dots, and it reads the title. Without a
  style, the function returns the HTML as it is.
  """
  @spec wrap(atom() | nil, String.t() | nil, Phoenix.HTML.safe()) :: Phoenix.HTML.safe()
  def wrap(nil, _title, html), do: html

  def wrap(style, title, html) do
    assigns = %{style: style, title: title, html: html}

    temple do
      div class: "window window-#{@style}" do
        div class: "window-bar" do
          if @style != :plain do
            span class: "window-dots", aria_hidden: "true" do
              span()
              span()
              span()
            end
          end

          span class: "window-title", do: @title
        end

        @html
      end
    end
  end
end
