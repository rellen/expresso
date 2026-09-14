defmodule Expresso.Renderer do
  @moduledoc """
  The renderer

  It makes one HTML document from a deck. The document holds each slide, the styles,
  the generated rules of the overlays and the script of the presenter.
  """

  import Temple

  use Temple.Component

  @external_resource "./assets/fonts.css"
  @external_resource "./assets/style.css"

  # `Mix.Tasks.Compile.Presenter` makes the bundle from these sources before
  # this module compiles. A change to a source starts a new compile here.
  for source <- Path.wildcard("./assets/src/**/*.ts") do
    @external_resource source
  end

  @fonts File.read!("./assets/fonts.css")
  @style File.read!("./assets/style.css")
  @presenter File.read!("./priv/static/presenter.js")

  defp fonts do
    @fonts
  end

  defp style do
    @style
  end

  defp presenter do
    @presenter
  end

  # `Expresso.Deck.render/1` writes the doctype. Floki drops a doctype node, and the
  # deck function formats this tree with Floki. Therefore the doctype cannot come
  # from this function.
  #
  # The two style sheets are files of this repository, and the presenter bundle
  # comes from files of this repository. The renderer reads them at compile time,
  # and no input of a user can change them. The generated style block comes from
  # the deck, and `Expresso.Overlay.Render.style/1` escapes each value of it.
  @doc """
  Make the HTML tree of a deck

  The assigns hold the deck under the key `deck`. `Expresso.Deck.render/1` calls
  this function, and it formats the tree and adds the doctype. The function
  gives each element its identity with `Expresso.Overlay.Render.identify/1`
  first.
  """
  @spec render(map() | keyword()) :: Phoenix.HTML.safe()
  # sobelow_skip ["XSS.Raw"]
  def render(assigns) do
    assigns = assigns |> Map.new() |> Map.update!(:deck, &Expresso.Overlay.Render.identify/1)

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

          style do
            Phoenix.HTML.raw(Expresso.Overlay.Render.style(@deck))
          end
        end

        body style: "min-height: 100vh; width: 100%; margin: 0px;" do
          div style:
                "height: 100vh; width: 100%; display: flex; flex-direction: row; align-items: center; justify-content: center;" do
            for {slide, index} <- Enum.with_index(@deck.slides) do
              section id: "slide-#{slide.metadata.slide_number}",
                      class: "slide",
                      data_step: 1,
                      data_max_step: Expresso.Overlay.Render.max_step(slide),
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
            Phoenix.HTML.raw(presenter())
          end
        end
      end
    end
  end
end
