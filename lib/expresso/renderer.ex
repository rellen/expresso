defmodule Expresso.Renderer do
  @moduledoc """
  The renderer

  It makes one HTML document from a deck. The document holds the present view, the
  handout view, the styles, the generated rules of the overlays and the script of
  the presenter.

  The present view holds one `section` for each slide. The handout view holds one
  `section` for each step of each slide. `docs/overlays.md` gives the reason for
  the second view.
  """

  import Temple

  use Temple.Component

  @external_resource "./assets/style.css"

  # `Mix.Tasks.Compile.Presenter` makes the bundle from these sources before
  # this module compiles. A change to a source starts a new compile here.
  for source <- Path.wildcard("./assets/src/**/*.ts") do
    @external_resource source
  end

  @style File.read!("./assets/style.css")
  @presenter File.read!("./priv/static/presenter.js")

  defp fonts do
    Expresso.Font.css()
  end

  defp style do
    @style
  end

  defp presenter do
    @presenter
  end

  # `Expresso.Deck.render/1` writes the doctype. Floki drops a doctype node, and the
  # deck function writes this tree with Floki. Therefore the doctype cannot come
  # from this function.
  #
  # The two style sheets are files of this repository, and the presenter bundle
  # comes from files of this repository. The renderer reads them at compile time,
  # and no input of a user can change them. The generated style block comes from
  # the deck, and `Expresso.Overlay.Render.style/1` escapes each value of it.
  # The three parts of a slide. The present view and the handout view show the
  # same parts, and each view gives its own container.
  defp slide_parts(assigns) do
    temple do
      div style: "width: 100%; flex-grow: 0; display: flex;justify-content: center;" do
        c(&Expresso.Template.render_deck_template(:header, &1), deck: @deck, slide: @slide)
      end

      div style: "width: 100%; flex-grow: 1; display: flex; justify-content: center;" do
        c(&Expresso.Template.render_slide_template/1, slide: @slide)
      end

      div style:
            "width: 100%; flex-grow: 0; flex-shrink: 0; display: flex;justify-content: center;" do
        c(&Expresso.Template.render_deck_template(:footer, &1), deck: @deck, slide: @slide)
      end
    end
  end

  @doc """
  Make the HTML tree of a deck

  The assigns hold the deck under the key `deck`. `Expresso.Deck.render/1` calls
  this function, and it writes the tree and adds the doctype. The function
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
          # The encoding goes in front of each other element of the head. A
          # browser reads the first 1024 bytes of a document for it. Without
          # this element the browser makes a guess, and the guess comes from
          # the locale of the person. Elixir writes UTF-8 only.
          meta charset: "utf-8"

          # A deck has no name when the DSL gives no `name` option, or when
          # `Expresso.Deck.new/3` takes `nil`. The `title` element is necessary,
          # so the renderer writes it with no text.
          title(do: @deck.name || "")

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

        body style: "min-height: 100vh; width: 100%; margin: 0px;", data_view: "present" do
          div class: "screen" do
            for {slide, index} <- Enum.with_index(@deck.slides) do
              section id: "slide-#{slide.metadata.slide_number}",
                      class: "slide",
                      data_step: 1,
                      data_max_step: Expresso.Overlay.Render.max_step(slide),
                      style:
                        "height: 100%; display: #{if index == 0, do: "flex", else: "none"}; flex-direction: column; justify-content: stretch" do
                c(&slide_parts/1, deck: @deck, slide: slide)
              end
            end
          end

          div class: "handout" do
            for slide <- @deck.slides,
                step <- 1..Expresso.Overlay.Render.max_step(slide)//1 do
              section class: "handout-page",
                      data_step: step,
                      data_slide: slide.metadata.slide_number do
                c(&slide_parts/1, deck: @deck, slide: slide)
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
