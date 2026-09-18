defmodule Expresso.Extension do
  @moduledoc """
  The Spark DSL extension

  It gives the `deck` section, the `slide` entity and the entities of an element.
  The overlay transformer and the overlay verifier run for each deck module.
  """

  # The overlay specification of an element. Each element entity merges this
  # schema into its own. `docs/overlays.md` gives the forms.
  @overlay_schema [
    at: [
      type: {:custom, Expresso.Overlay, :new, []},
      doc: "The steps that show the element. See docs/overlays.md."
    ]
  ]

  @on %Spark.Dsl.Entity{
    name: :on,
    target: Expresso.Element.On,
    args: [:at],
    schema: [
      at: [
        type: {:custom, Expresso.Overlay, :new, []},
        required: true,
        doc: "The steps that give the state."
      ],
      state: [type: :atom, doc: "A state of the theme, such as :alert."],
      set: [type: :keyword_list, doc: "Custom properties, such as [x: \"400px\"]."]
    ]
  }

  @text_area %Spark.Dsl.Entity{
    name: :text_area,
    target: Expresso.Element.TextArea,
    entities: [on: [@on]],
    schema: @overlay_schema ++ [text: [type: :string]]
  }

  @image %Spark.Dsl.Entity{
    name: :image,
    target: Expresso.Element.Image,
    args: [:src],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        [
          src: [
            type: :string,
            required: true,
            doc: "The path of the image file, from the working directory of the command."
          ],
          alt: [type: :string, doc: "The text of the image for a screen reader."],
          width: [
            type: :string,
            doc: "The width of the image, such as 900px or 60%. See docs/architecture.md."
          ]
        ]
  }

  @text_box %Spark.Dsl.Entity{
    name: :text_box,
    target: Expresso.Element.TextBox,
    entities: [elements: [@text_area, @image], on: [@on]],
    schema: @overlay_schema
  }

  @pause %Spark.Dsl.Entity{
    name: :pause,
    target: Expresso.Element.Pause
  }

  @slide_elements [elements: [@text_box, @image, @pause]]

  @slide %Spark.Dsl.Entity{
    name: :slide,
    target: Expresso.Slide,
    args: [{:optional, :name}],
    entities: @slide_elements,
    schema: [
      name: [type: :string, doc: "A name for the slide."],
      heading: [type: :string, doc: "The heading that the slide template shows."],
      steps: [type: :pos_integer, doc: "The maximum step number of the slide."],
      auto_reveal: [
        type: :boolean,
        default: false,
        doc: "Show each element of the slide one after the other. See docs/overlays.md."
      ]
    ]
  }

  @deck %Spark.Dsl.Section{
    name: :deck,
    entities: [@slide],
    top_level?: true,
    schema: [
      name: [
        type: :string,
        doc: "A unique identifier for this deck."
      ]
    ]
  }

  @sections [@deck]

  use Spark.Dsl.Extension,
    sections: @sections,
    imports: [],
    transformers: [Expresso.Overlay.Transformer],
    verifiers: [
      Expresso.Overlay.Verifier,
      Expresso.Overlay.PropertyVerifier,
      Expresso.Overlay.SizeVerifier
    ]
end
