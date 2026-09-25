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

  # A list holds items, and an item holds one nested list. Spark cannot nest
  # two entities inside each other without a limit, so the extension builds
  # three levels. The item of the deepest list holds no list.
  @list_levels 3

  @list Enum.reduce(1..@list_levels, nil, fn _level, inner ->
          item = %Spark.Dsl.Entity{
            name: :item,
            target: Expresso.Element.Item,
            args: [:text],
            entities: [elements: List.wrap(inner), on: [@on]],
            schema:
              @overlay_schema ++
                [text: [type: :string, required: true, doc: "The text of the item."]]
          }

          %Spark.Dsl.Entity{
            name: :list,
            target: Expresso.Element.List,
            entities: [elements: [item], on: [@on]],
            schema:
              @overlay_schema ++
                [
                  ordered: [
                    type: :boolean,
                    default: false,
                    doc: "Number the items. The default is a bullet for each item."
                  ],
                  reveal: [
                    type: :boolean,
                    default: false,
                    doc: "Show the items one after the other. See docs/overlays.md."
                  ]
                ]
          }
        end)

  @row %Spark.Dsl.Entity{
    name: :row,
    target: Expresso.Element.Row,
    args: [:cells],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        [cells: [type: {:list, :string}, required: true, doc: "The text of each cell."]]
  }

  @table %Spark.Dsl.Entity{
    name: :table,
    target: Expresso.Element.Table,
    entities: [elements: [@row], on: [@on]],
    schema:
      @overlay_schema ++
        [
          header: [
            type: :boolean,
            default: false,
            doc: "Make the first row the header of the table."
          ],
          reveal: [
            type: :boolean,
            default: false,
            doc: "Show the rows one after the other. See docs/overlays.md."
          ]
        ]
  }

  @quotation %Spark.Dsl.Entity{
    name: :quotation,
    target: Expresso.Element.Quotation,
    args: [:text],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        [
          text: [type: :string, required: true, doc: "The text of the quotation."],
          by: [type: :string, doc: "The name of the source of the quotation."]
        ]
  }

  @spacer %Spark.Dsl.Entity{
    name: :spacer,
    target: Expresso.Element.Spacer,
    entities: [on: [@on]],
    schema: @overlay_schema
  }

  @code %Spark.Dsl.Entity{
    name: :code,
    target: Expresso.Element.Code,
    args: [{:optional, :lang}],
    entities: [on: [@on]],
    transform: {Expresso.Element.Code, :build, []},
    schema:
      @overlay_schema ++
        [
          lang: [
            type: :string,
            doc: "The name of the language, such as elixir. See Expresso.Highlight."
          ],
          text: [type: :string, required: true, doc: "The source code."],
          reveal: [
            type: {:custom, Expresso.Element.Code, :reveal, []},
            doc: "Line numbers and ranges, one group at each step. See docs/overlays.md."
          ]
        ]
  }

  @math %Spark.Dsl.Entity{
    name: :math,
    target: Expresso.Element.Math,
    args: [:text],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        [text: [type: :string, required: true, doc: "The MathML, from <math> to </math>."]]
  }

  @part %Spark.Dsl.Entity{
    name: :part,
    target: Expresso.Element.Part,
    args: [:id],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        [id: [type: :string, required: true, doc: "The id of an element of the SVG file."]]
  }

  @diagram %Spark.Dsl.Entity{
    name: :diagram,
    target: Expresso.Element.Diagram,
    args: [:src],
    entities: [elements: [@part], on: [@on]],
    schema:
      @overlay_schema ++
        [
          src: [
            type: :string,
            required: true,
            doc: "The path of the SVG file, from the working directory of the command."
          ],
          width: [
            type: :string,
            doc: "The width of the diagram, such as 900px or 60%. See docs/architecture.md."
          ]
        ]
  }

  # The elements that a text box and a column hold
  @inner_elements [
    @text_area,
    @image,
    @list,
    @table,
    @quotation,
    @spacer,
    @code,
    @math,
    @diagram
  ]

  @column %Spark.Dsl.Entity{
    name: :column,
    target: Expresso.Element.Column,
    entities: [elements: @inner_elements, on: [@on]],
    schema:
      @overlay_schema ++
        [
          width: [
            type: :string,
            doc: "The width of the column, such as 30%. The default is an equal part."
          ]
        ]
  }

  # A column cannot hold a columns element, because Spark cannot nest two
  # entities inside each other without a limit.
  @columns %Spark.Dsl.Entity{
    name: :columns,
    target: Expresso.Element.Columns,
    entities: [elements: [@column], on: [@on]],
    schema: @overlay_schema
  }

  @text_box %Spark.Dsl.Entity{
    name: :text_box,
    target: Expresso.Element.TextBox,
    entities: [elements: @inner_elements ++ [@columns], on: [@on]],
    schema: @overlay_schema
  }

  @pause %Spark.Dsl.Entity{
    name: :pause,
    target: Expresso.Element.Pause
  }

  @slide_elements [elements: [@text_box, @columns] ++ @inner_elements ++ [@pause]]

  @slide %Spark.Dsl.Entity{
    name: :slide,
    target: Expresso.Slide,
    args: [{:optional, :name}],
    entities: @slide_elements,
    schema: [
      name: [type: :string, doc: "A name for the slide."],
      heading: [type: :string, doc: "The heading that the slide template shows."],
      notes: [
        type: :string,
        doc: "The notes of the speaker. The handout view shows them under each page."
      ],
      steps: [type: :pos_integer, doc: "The maximum step number of the slide."],
      handout: [
        type: {:custom, Expresso.Handout, :new, []},
        doc:
          "The steps that the handout view and a printer show, such as [2, :last]. See Expresso.Handout."
      ],
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
      ],
      duration: [
        type: :pos_integer,
        doc:
          "The length of the talk in minutes. The speaker view then shows the time left and the pace. The address parameter `?duration=` replaces it."
      ],
      handout: [
        type: {:in, [:all, :last]},
        default: :all,
        doc:
          "The steps that the handout view and a printer show for a slide without a handout option."
      ],
      print_notes: [
        type: :boolean,
        default: true,
        doc:
          "Print the notes of the speaker under each page. The value false leaves them out of the handout view and of the print."
      ],
      progress: [
        type: :boolean,
        default: true,
        doc:
          "Show the progress bar in the present view at the start. The key `g` shows or hides it during the talk."
      ],
      slide_numbers: [
        type: :boolean,
        default: false,
        doc:
          "Show the number of each slide and the number of slides, such as 3 / 12, in a corner of the slide. Slide 1 shows no number."
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
