defmodule Expresso.Extension do
  @text_area %Spark.Dsl.Entity{
    name: :text_area,
    target: Expresso.Element.TextArea,
    schema: [text: [type: :string]]
  }

  @text_box %Spark.Dsl.Entity{
    name: :text_box,
    target: Expresso.Element.TextBox,
    entities: [elements: [@text_area]]
  }

  @slide_elements [elements: [@text_box]]

  @slide %Spark.Dsl.Entity{
    name: :slide,
    target: Expresso.Slide,
    entities: @slide_elements,
    schema: [name: [type: :string]]
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
    transformers: []
end
