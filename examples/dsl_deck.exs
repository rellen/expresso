defmodule DslDeck do
  use Expresso

  name "dsl deck"

  slide "intro" do
    heading "An intro"

    text_box do
      text_area do
        text "A deck from the DSL. Text accepts <b>raw HTML</b>."
      end
    end
  end

  slide do
    text_box do
      text_area do
        text "A slide without a name."
      end
    end
  end

  slide "overlays" do
    heading "Overlays"

    pause()

    text_box do
      at from: :next
      on :next, state: :alert

      text_area do
        text "This box appears at step 2. It gets the alert state at step 3."
      end
    end

    text_box do
      at from: :next
      on [from: :next], set: [x: "-200px"]

      text_area do
        text "It moves left at step 5."
      end
    end
  end

  slide "an image" do
    heading "An image"

    image "examples/logo.png" do
      alt "A square with a gradient"
      width "60%"
    end
  end

  slide "auto reveal" do
    heading "Auto reveal"
    auto_reveal true

    text_box do
      text_area do
        text "This box shows at step 1."
      end
    end

    text_box do
      text_area do
        text "This box shows at step 2."
      end
    end

    text_box do
      text_area do
        text "This box shows at step 3."
      end
    end
  end
end
