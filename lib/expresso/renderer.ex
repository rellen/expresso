defmodule Expresso.Renderer do
  import Temple

  use Temple.Component

  @fonts File.read!("./assets/fonts.css")
  @style File.read!("./assets/style.css")

  defp fonts() do
    @fonts
  end

  defp style() do
    @style
  end

  def render(assigns) do
    temple do
      "<!DOCTYPE html>"

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
                "height: 100%; width: 100%; display: flex, flex-direction: row; align-items: center; justify-content: center;" do
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
            Phoenix.HTML.raw("""
            let slide_number = 0;

            const slides = document.getElementsByClassName("slide");
            const max_slide_number = slides.length - 1;

            document.addEventListener("keydown", (e) => {
              if (e.key === "k" && slide_number > 0) {
                slide_number--;
                update_slide_visibility();
              } else if (e.key === "j" && slide_number < max_slide_number){
                slide_number++;
                update_slide_visibility();
              } else if (e.key === "p"){
                update_slides_for_print();
              }

            });

            function update_slide_visibility() {
              for(i=0;i<=max_slide_number;i++) {
                const element = document.getElementById("slide-"+i);
                element.style.display = "none";
              }

              const element = document.getElementById("slide-"+slide_number);
              element.style.display = "flex";
            };

            function update_slides_for_print() {
              for(i=0;i<=max_slide_number;i++) {
                const element = document.getElementById("slide-"+i);
                element.style.display = "flex";
              }
            };
            """)
          end
        end
      end
    end
  end
end
