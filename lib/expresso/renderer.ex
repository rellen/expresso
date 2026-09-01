defmodule Expresso.Renderer do
  @moduledoc """
  The renderer

  It makes one HTML document from a deck. The document holds each slide, the styles
  and the script of the presenter.
  """

  import Temple

  use Temple.Component

  @external_resource "./assets/fonts.css"
  @external_resource "./assets/style.css"
  @external_resource "./assets/main.js"

  @fonts File.read!("./assets/fonts.css")
  @style File.read!("./assets/style.css")
  @main_js File.read!("./assets/main.js")

  defp fonts do
    @fonts
  end

  defp style do
    @style
  end

  defp main_js do
    @main_js
  end

  # `Expresso.Deck.render/1` writes the doctype. Floki drops a doctype node, and the
  # deck function formats this tree with Floki. Therefore the doctype cannot come
  # from this function.
  #
  # The three assets are files of this repository. The renderer reads them at compile
  # time, and no input of a user can change them.
  # sobelow_skip ["XSS.Raw"]
  def render(assigns) do
    temple do
      html do
        head do
          title(do: @deck.name)

          style do
            Phoenix.HTML.raw(fonts())
          end

          style do
            Phoenix.HTML.raw(style())
          end
        end

        body style: "min-height: 100vh; width: 100%; margin: 0px;" do
          div style:
                "height: 100vh; width: 100%; display: flex; flex-direction: row; align-items: center; justify-content: center;" do
            for {slide, index} <- Enum.with_index(@deck.slides) do
              section id: "slide-#{slide.metadata.slide_number}",
                      class: "slide",
                      style:
                        "height: 100%; display: #{if index == 0, do: "flex", else: "none"}; flex-direction: column; justify-content: stretch" do
                div style: "width: 100%; flex-grow: 0; display: flex;justify-content: center;" do
                  c(&Expresso.Template.render_deck_template(:header, &1),
                    deck: @deck,
                    slide: slide
                  )
                end

                div style: "width: 100%; flex-grow: 1; display: flex; justify-content: center;" do
                  c(&Expresso.Template.render_slide_template/1, slide: slide)
                end

                div style:
                      "width: 100%; flex-grow: 0; flex-shrink: 0; display: flex;justify-content: center;" do
                  c(&Expresso.Template.render_deck_template(:footer, &1),
                    deck: @deck,
                    slide: slide
                  )
                end
              end
            end
          end

          script do
            Phoenix.HTML.raw(main_js())
          end
        end
      end
    end
  end
end
