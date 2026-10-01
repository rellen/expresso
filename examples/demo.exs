# A deck from the functions of `Expresso.Builder`, in place of the DSL. Each
# function takes the same options as the entity of the DSL with the same name.
import Expresso.Builder

points = ["Concurrency", "Fault tolerance", "Hot code upgrade"]

deck(
  [
    slide("heading_with_text_box",
      heading: "This is a heading",
      elements: [
        text_box(
          elements: [
            text_area(
              text: "This is a text-area inside a text-box. Text supports <b>raw HTML</b>"
            )
          ]
        )
      ]
    ),
    slide("a list from data",
      heading: "One point at each step",
      elements: [list(reveal: true, elements: Enum.map(points, &item/1))]
    )
  ],
  name: "demo"
)
