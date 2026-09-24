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
    # The handout view and a printer show step 3 and the last step only.
    handout [3, :last]

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

  slide "a list" do
    heading "A list"

    list do
      reveal true
      item "The first point"

      item "The second point" do
        list do
          ordered true
          item "A nested item, in a numbered list"
          item "Another nested item"
        end
      end

      item "The third point, with <b>HTML</b>"
    end
  end

  slide "a table" do
    heading "A table"

    table do
      header true
      reveal true
      row ["Element", "Content"]
      row ["text_area", "text, with HTML"]
      row ["image", "one file, as a data URI"]
      row ["list", "items, with nested lists"]
      row ["table", "rows of cells"]
    end
  end

  slide "a quotation" do
    heading "A quotation"
    notes "Say who Mies van der Rohe was.\nThe handout view shows these notes."

    quotation "Less is more." do
      by "Ludwig Mies van der Rohe"
    end
  end

  slide "code" do
    heading "Code"

    code "elixir" do
      reveal [1..3, 5..7]

      text ~S"""
      defmodule Greeter do
        def greet(name), do: "Hello, #{name}!"
      end

      Greeter.greet("world")
      |> IO.puts()
      # The last group shows at step 2.
      """
    end
  end

  slide "columns" do
    heading "Columns"

    columns do
      column do
        width "40%"

        list do
          item "A column of 40 percent"
          item "with a list"
        end
      end

      column do
        at from: :next

        text_box do
          text_area do
            text "A column that takes the rest, and shows at the next step."
          end
        end
      end
    end
  end

  slide "math" do
    heading "Math"

    math ~S"""
    <math display="block">
      <mi>E</mi><mo>=</mo><mi>m</mi><msup><mi>c</mi><mn>2</mn></msup>
    </math>
    """
  end

  slide "a diagram" do
    heading "A diagram"

    diagram "examples/flow.svg" do
      width "60%"
      part "arrow", at: [from: 2]
      part "output", at: [from: 3]
    end
  end

  slide "a spacer" do
    heading "A spacer"

    text_box do
      text_area do
        text "This text is at the top."
      end
    end

    spacer()

    text_box do
      text_area do
        text "The spacer pushes this text to the bottom."
      end
    end
  end
end
