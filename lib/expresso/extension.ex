defmodule Expresso.Extension do
  @moduledoc """
  The Spark DSL extension

  It gives the `deck` section, the `slide` entity and the entities of an element.
  The overlay transformer, the overlay verifiers, `Expresso.GotoVerifier`,
  `Expresso.TransitionVerifier`, `Expresso.ThemeVerifier` and
  `Expresso.CodeVerifier` run for each deck module.
  """

  # The overlay specification of an element. Each element entity merges this
  # schema into its own. `docs/overlays.md` gives the forms.
  # The ways in which an element shows and hides at the steps of its `at`
  # option. The slide and the deck take the same values.
  @effects [:fade, :grow, :fly_up, :fly_down, :fly_left, :fly_right, :wipe, :blur]

  # The time and the easing of the animations of an element. A speed is a
  # preset of the theme or a number of milliseconds.
  @speed {:or, [{:in, [:fast, :normal, :slow]}, :pos_integer]}

  # A template is a module, or a built-in template such as {:builtins, :default}.
  @template {:or, [{:tuple, [{:in, [:builtins]}, :atom]}, :atom]}
  @easings [:ease_in_out, :ease_out, :linear, :spring]

  @overlay_schema [
    at: [
      type: {:custom, Expresso.Overlay, :new, []},
      doc: "The steps that show the element. See docs/overlays.md."
    ],
    effect: [
      type: :atom,
      doc:
        "How the element shows and hides: #{Enum.map_join(@effects, ", ", &inspect/1)}, or an effect of the css option of the deck. The default is the effect of the nearest parent, of the slide or of the deck."
    ],
    speed: [
      type: @speed,
      doc:
        "The time of each animation of the element: :fast, :normal, :slow or a number of milliseconds. The default is the speed of the nearest parent, of the slide or of the deck."
    ],
    easing: [
      type: {:in, @easings},
      doc:
        "The easing of each animation of the element: #{Enum.map_join(@easings, ", ", &inspect/1)}. The default is the easing of the nearest parent, of the slide or of the deck."
    ]
  ]

  # The CSS classes of an element or of a slide. `Expresso.Element.class/1`
  # gives the rules.
  @class_schema [
    class: [
      type: {:custom, Expresso.Element, :class, []},
      doc:
        "CSS class names for the element, such as \"dense\". A rule of the css option of the deck can then select the element. See docs/reference/class-option.md."
    ]
  ]

  # A link to a slide and a step of the deck. `Expresso.Goto` gives the rules.
  @goto_schema [
    goto: [
      type: {:custom, Expresso.Goto, :new, []},
      doc:
        "Make the element a link to a slide and a step, such as [slide: 5], [slide: 5, step: 2] or [slide: \"summary\"]. The slide is a number or the name of a slide. See Expresso.Goto."
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
      set: [type: :keyword_list, doc: "Custom properties, such as [x: \"400px\"]."],
      move_to: [
        type: :string,
        doc:
          "The id of an element of the SVG file. The part moves to the center of that element. Only an on entity of a part takes it. See docs/reference/overlay-options.md."
      ]
    ]
  }

  @text_area %Spark.Dsl.Entity{
    name: :text_area,
    target: Expresso.Element.TextArea,
    entities: [on: [@on]],
    schema: @overlay_schema ++ @class_schema ++ @goto_schema ++ [text: [type: :string]]
  }

  @image %Spark.Dsl.Entity{
    name: :image,
    target: Expresso.Element.Image,
    args: [:src],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        @goto_schema ++
        [
          src: [
            type: :string,
            required: true,
            doc:
              "The path of the image file, from the root option of the deck or from the working directory of the command."
          ],
          alt: [type: :string, doc: "The text of the image for a screen reader."],
          width: [
            type: :string,
            doc: "The width of the image, such as 900px or 60%. See docs/architecture.md."
          ]
        ]
  }

  @embed %Spark.Dsl.Entity{
    name: :embed,
    target: Expresso.Element.Embed,
    args: [:src],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          src: [
            type: {:custom, Expresso.Element.Embed, :source, []},
            required: true,
            doc:
              "The page: an address that starts with https:// or http://, or the path of a local .html file. See docs/reference/embed-element.md."
          ],
          title: [
            type: :string,
            required: true,
            doc: "The name of the page for a screen reader."
          ],
          fallback: [
            type: :string,
            doc:
              "The path of an image that shows on paper, in the handout view and while the page loads."
          ],
          width: [
            type: :string,
            doc: "The width of the page, such as 900px or 80%. The default is 80%."
          ],
          aspect: [
            type: {:custom, Expresso.Element.Embed, :aspect, []},
            doc:
              "The ratio of the width to the height, such as \"16/9\". The default is \"16/9\"."
          ],
          interactive: [
            type: :boolean,
            default: false,
            doc:
              "Let the page take clicks and keys. The default is false, so the keys and the clicks of the presenter work on the slide."
          ]
        ]
  }

  @video %Spark.Dsl.Entity{
    name: :video,
    target: Expresso.Element.Video,
    args: [:src],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          src: [
            type: {:custom, Expresso.Element.Video, :source, []},
            required: true,
            doc:
              "The path of a .webm or a .mp4 file. The document holds the video one time. See docs/reference/video-element.md."
          ],
          title: [
            type: :string,
            required: true,
            doc: "The name of the video for a screen reader."
          ],
          poster: [
            type: :string,
            required: true,
            doc:
              "The path of an image that shows on paper, in the handout view, in the speaker view and while the video loads."
          ],
          width: [
            type: :string,
            doc: "The width of the video, such as 900px or 80%. The default is 80%."
          ],
          aspect: [
            type: {:custom, Expresso.Element.Embed, :aspect, []},
            doc:
              "The ratio of the width to the height, such as \"16/9\". The default is \"16/9\"."
          ],
          loop: [
            type: :boolean,
            default: true,
            doc: "Play the video again from the start at its end."
          ],
          controls: [
            type: :boolean,
            default: false,
            doc:
              "Show the controls of the browser, so the presenter can turn the sound on. The default is false, so the clicks of the presenter work on the slide."
          ]
        ]
  }

  @qr_code %Spark.Dsl.Entity{
    name: :qr_code,
    target: Expresso.Element.QrCode,
    args: [:text],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          text: [
            type: :string,
            required: true,
            doc:
              "The text of the code, such as the address of the slides. See docs/reference/qr-code-element.md."
          ],
          size: [
            type: :string,
            doc:
              "The width and the height of the code, such as 300px or 25%. A percentage is a part of the width of the slide."
          ],
          label: [type: :string, doc: "A line of text under the code."],
          title: [
            type: :string,
            doc: "The name of the code for a screen reader. The default is the text of the code."
          ],
          level: [
            type: {:in, Expresso.Element.QrCode.levels()},
            default: :m,
            doc:
              "The error correction level: :l, :m, :q or :h. A higher level makes a larger code that a scanner reads when a part of it is not clear."
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
                @class_schema ++
                @goto_schema ++
                [text: [type: :string, required: true, doc: "The text of the item."]]
          }

          %Spark.Dsl.Entity{
            name: :list,
            target: Expresso.Element.List,
            entities: [elements: [item], on: [@on]],
            schema:
              @overlay_schema ++
                @class_schema ++
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
                  ],
                  dim: [
                    type: :boolean,
                    default: false,
                    doc: "Dim each child when a later child shows. See docs/overlays.md."
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
        @class_schema ++
        [cells: [type: {:list, :string}, required: true, doc: "The text of each cell."]]
  }

  @table %Spark.Dsl.Entity{
    name: :table,
    target: Expresso.Element.Table,
    entities: [elements: [@row], on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
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
          ],
          dim: [
            type: :boolean,
            default: false,
            doc: "Dim each child when a later child shows. See docs/overlays.md."
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
        @class_schema ++
        [
          text: [type: :string, required: true, doc: "The text of the quotation."],
          by: [type: :string, doc: "The name of the source of the quotation."]
        ]
  }

  @spacer %Spark.Dsl.Entity{
    name: :spacer,
    target: Expresso.Element.Spacer,
    entities: [on: [@on]],
    schema: @overlay_schema ++ @class_schema
  }

  @code %Spark.Dsl.Entity{
    name: :code,
    target: Expresso.Element.Code,
    args: [{:optional, :lang}],
    entities: [on: [@on]],
    transform: {Expresso.Element.Code, :check, []},
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          lang: [
            type: :string,
            doc: "The name of the language, such as elixir. See Expresso.Highlight."
          ],
          text: [
            type: :string,
            doc: "The source code. Give this option or the src option, and not both."
          ],
          src: [
            type: :string,
            doc:
              "The path of a file that holds the source code, from the root option of the deck or from the working directory of the command. See docs/reference/code-element.md."
          ],
          lines: [
            type: {:custom, Expresso.Element.Code, :lines, []},
            doc:
              "The lines of the src file that the element shows: a range, such as 10..24, or a start text and an end text, such as [from: \"def start(\", to: \"end\"]. The default is each line of the file. See docs/reference/code-element.md."
          ],
          line_numbers: [
            type: :boolean,
            default: false,
            doc:
              "Show the number of each line. With src, the number of a line is its number in the file."
          ],
          reveal: [
            type: {:custom, Expresso.Element.Code, :reveal, []},
            doc:
              "Line numbers and ranges, one group at each step. With src, a number is the number of the line in the file. See docs/overlays.md."
          ],
          dim: [
            type: :boolean,
            default: false,
            doc: "Dim each group of lines when a later group shows. See docs/overlays.md."
          ],
          highlight: [
            type: {:custom, Expresso.Element.Code, :reveal, []},
            doc:
              "Line numbers and ranges, one group in focus at each step. Each line shows at each step, and the lines that are not in focus dim. See docs/reference/code-element.md."
          ],
          whole_first: [
            type: :boolean,
            default: false,
            doc:
              "With highlight, show the whole code in full color for one step before the first group comes into focus. The default is false."
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
        @class_schema ++
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
        @class_schema ++
        [
          src: [
            type: :string,
            required: true,
            doc:
              "The path of the SVG file, from the root option of the deck or from the working directory of the command."
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
    @diagram,
    @embed,
    @video,
    @qr_code
  ]

  @column %Spark.Dsl.Entity{
    name: :column,
    target: Expresso.Element.Column,
    entities: [elements: @inner_elements, on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
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
    schema: @overlay_schema ++ @class_schema
  }

  @text_box %Spark.Dsl.Entity{
    name: :text_box,
    target: Expresso.Element.TextBox,
    entities: [elements: @inner_elements ++ [@columns], on: [@on]],
    schema: @overlay_schema ++ @class_schema
  }

  @footnote %Spark.Dsl.Entity{
    name: :footnote,
    target: Expresso.Element.Footnote,
    args: [:text],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          text: [
            type: :string,
            required: true,
            doc:
              "The text of the footnote, such as a source. It can contain HTML. The renderer puts it at the bottom of the slide, with a number. See docs/reference/footnote-element.md."
          ]
        ]
  }

  @pause %Spark.Dsl.Entity{
    name: :pause,
    target: Expresso.Element.Pause,
    schema: [
      label: [
        type: :string,
        doc:
          "The name of the step that the pause starts. The speaker view shows it. See docs/reference/step-labels.md."
      ]
    ]
  }

  @slide_elements [elements: [@text_box, @columns] ++ @inner_elements ++ [@footnote, @pause]]

  @slide %Spark.Dsl.Entity{
    name: :slide,
    target: Expresso.Slide,
    args: [{:optional, :name}],
    entities: @slide_elements,
    schema: [
      name: [type: :string, doc: "A name for the slide."],
      class: [
        type: {:custom, Expresso.Element, :class, []},
        doc:
          "CSS class names for the slide, such as \"dense\". The present view and each page of the handout view get them. See docs/reference/class-option.md."
      ],
      heading: [type: :string, doc: "The heading that the slide template shows."],
      template: [
        type: @template,
        doc:
          "The slide template: a module, or {:builtins, name}. See docs/architecture.md. The default is {:builtins, :default}."
      ],
      notes: [
        type: :string,
        doc: "The notes of the speaker. The handout view shows them under each page."
      ],
      meta: [
        type: :keyword_list,
        doc:
          "Values of your own for the templates, such as [section: \"Part 3\"]. A template reads them from @metadata[:meta]. See docs/reference/template-option.md."
      ],
      steps: [type: :pos_integer, doc: "The maximum step number of the slide."],
      labels: [
        type: {:list, {:or, [:string, nil]}},
        doc:
          "The name of each step, from step 1, such as [\"The question\", nil, \"The answer\"]. nil gives a step no name. See docs/reference/step-labels.md."
      ],
      handout: [
        type: {:custom, Expresso.Handout, :new, []},
        doc:
          "The steps that the handout view and a printer show, such as [2, :last]. See Expresso.Handout."
      ],
      auto_reveal: [
        type: :boolean,
        default: false,
        doc: "Show each element of the slide one after the other. See docs/overlays.md."
      ],
      transition: [
        type: :atom,
        doc:
          "The transition between the slide before and this slide, in the two directions. The default is the transition of the deck."
      ],
      effect: [
        type: :atom,
        doc:
          "How each element with an at option shows and hides. An element or its parent can replace it. The default is the effect of the deck."
      ],
      speed: [
        type: @speed,
        doc:
          "The time of each animation of the slide. An element or its parent can replace it. The default is the speed of the deck."
      ],
      easing: [
        type: {:in, @easings},
        doc:
          "The easing of each animation of the slide. An element or its parent can replace it. The default is the easing of the deck."
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
      css: [
        type: :string,
        doc:
          "A style sheet, or the path of a file that holds one. The document puts it after the theme, so it can replace each rule of the theme and give new effects and states. See docs/reference/css-option.md."
      ],
      root: [
        type: :string,
        doc:
          "The directory of each relative path of the deck, such as __DIR__. Without it, a path is relative to the working directory of the command. See docs/reference/root-option.md."
      ],
      effect: [
        type: :atom,
        default: :fade,
        doc:
          "How each element with an at option shows and hides. A slide, an element or its parent can replace it."
      ],
      speed: [
        type: @speed,
        doc:
          "The time of each animation in a slide: :fast, :normal, :slow or a number of milliseconds. A slide, an element or its parent can replace it. Without the option, the theme gives 300 ms. The transition between slides keeps its own time."
      ],
      easing: [
        type: {:in, @easings},
        doc:
          "The easing of each animation in a slide: #{Enum.map_join(@easings, ", ", &inspect/1)}. A slide, an element or its parent can replace it. Without the option, the theme gives :ease_in_out."
      ],
      transition: [
        type: :atom,
        default: :fade,
        doc:
          "The transition from one slide to the next in the present view: :fade, :slide, :zoom, :none or a transition of the CSS of the deck. A slide can replace it. See docs/reference/transition-option.md."
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
      ],
      template: [
        type: @template,
        doc:
          "The deck template, which gives the header and the footer: a module, or {:builtins, name}. See docs/architecture.md. The default is {:builtins, :default}."
      ],
      slide_template: [
        type: @template,
        doc:
          "The slide template of each slide without a template option: a module, or {:builtins, name}. See docs/reference/template-option.md. The default is {:builtins, :default}."
      ],
      theme: [
        type: {:custom, Expresso.Palette, :validate, []},
        default: :default,
        doc:
          "The colors of the deck: the name of a built-in theme, such as :dracula, a map with a #rrggbb color for each slot of base16, from :base00 to :base0F, or a keyword list with colors, or with dark and light, and adjust. Each built-in theme meets the contrast minimums of WCAG, and a map that does not gets a warning. Paper always gets the default theme. See docs/reference/theme-option.md."
      ]
    ]
  }

  @sections [@deck]

  use Spark.Dsl.Extension,
    sections: @sections,
    imports: [],
    transformers: [Expresso.PathTransformer, Expresso.Overlay.Transformer],
    verifiers: [
      Expresso.GotoVerifier,
      Expresso.Overlay.Verifier,
      Expresso.Overlay.PropertyVerifier,
      Expresso.Overlay.EffectVerifier,
      Expresso.TransitionVerifier,
      Expresso.Overlay.SizeVerifier,
      Expresso.ThemeVerifier,
      Expresso.CodeVerifier
    ]
end
