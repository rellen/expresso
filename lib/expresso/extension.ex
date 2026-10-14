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
    ],
    morph: [
      type: :string,
      doc:
        "A key of the morph between two slides. The element with this key on the next slide takes its place and its size from this element. See docs/reference/morph-option.md."
    ]
  ]

  @morph_modes [:auto, :named, :off]

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
          captions: [
            type: {:custom, Expresso.Element.Video, :captions, []},
            doc:
              "The path of a WebVTT file with the captions of the video, from the root option of the deck. The browser shows the captions on the video. See docs/reference/video-element.md."
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

  @audio %Spark.Dsl.Entity{
    name: :audio,
    target: Expresso.Element.Audio,
    args: [:src],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          src: [
            type: {:custom, Expresso.Element.Audio, :source, []},
            required: true,
            doc:
              "The path of a .mp3, .m4a, .ogg, .oga or .wav file. The document holds the sound one time. See docs/reference/audio-element.md."
          ],
          title: [
            type: :string,
            required: true,
            doc: "The name of the sound for a screen reader. The handout view and paper show it."
          ],
          loop: [
            type: :boolean,
            default: false,
            doc: "Play the sound again from the start at its end."
          ],
          controls: [
            type: :boolean,
            default: false,
            doc:
              "Show the controls of the browser on the slide. The default is false, so the present view shows nothing in the place of the element."
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

  @series %Spark.Dsl.Entity{
    name: :series,
    target: Expresso.Element.Series,
    args: [:name, :values],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          name: [type: :string, required: true, doc: "The name of the series."],
          values: [
            type: {:list, {:or, [:integer, :float]}},
            required: true,
            doc: "One number for each category of the chart, in the order of the categories."
          ]
        ]
  }

  @flow %Spark.Dsl.Entity{
    name: :flow,
    target: Expresso.Element.Flow,
    args: [:from, :to, :value],
    schema: [
      from: [type: :string, required: true, doc: "The node where the flow starts."],
      to: [type: :string, required: true, doc: "The node where the flow ends."],
      value: [
        type: {:or, [:integer, :float]},
        required: true,
        doc: "The size of the flow, zero or more."
      ]
    ]
  }

  @frame %Spark.Dsl.Entity{
    name: :frame,
    target: Expresso.Element.Frame,
    args: [:label],
    entities: [elements: [@series], flows: [@flow]],
    schema: [
      label: [
        type: :string,
        required: true,
        doc: "The name of the point in time, such as \"2024\"."
      ]
    ]
  }

  @chart %Spark.Dsl.Entity{
    name: :chart,
    target: Expresso.Element.Chart,
    args: [:kind],
    entities: [elements: [@series], timeline: [@frame], flows: [@flow], on: [@on]],
    transform: {Expresso.Element.Chart, :check, []},
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          kind: [
            type: {:in, Expresso.Element.Chart.kinds()},
            required: true,
            doc:
              "The kind of the chart: :bar, :line, :pie, :treemap, :sunburst or :sankey. See docs/reference/chart-element.md."
          ],
          title: [
            type: :string,
            required: true,
            doc: "The name of the chart for a screen reader, and the caption of its table."
          ],
          category_label: [
            type: :string,
            doc:
              "The name of the categories, such as \"Year\". It goes under the axis of the categories and into the corner of the table. A chart with src takes the first heading of its file by default."
          ],
          value_label: [
            type: :string,
            doc:
              "The name of the values, such as \"Widgets an hour\". It goes beside the axis of the values and into the caption of the table."
          ],
          categories: [
            type: {:list, {:or, [:string, {:list, :string}]}},
            doc:
              "The name of each category, such as [\"2023\", \"2024\"]. A category of a treemap or a sunburst can be a list of its levels, such as [\"Production\", \"Press\"], and a category of a sankey is a path of nodes, such as [\"Coal\", \"Electricity\"]."
          ],
          src: [
            type: :string,
            doc:
              "The path of a CSV file with the categories and the series, from the root option of the deck or from the working directory of the command. A file that ends in .tsv has a tab between two cells."
          ],
          delimiter: [
            type: :string,
            doc:
              "The character between two cells of the src file, such as \";\" or \"|\". The default is a comma, or a tab for a file that ends in .tsv. Requires the src option."
          ],
          width: [
            type: :string,
            doc: "The width of the chart, such as 900px or 70%. The default is 80%."
          ],
          values: [
            type: :boolean,
            default: true,
            doc: "Show the value of each bar. The default is true."
          ],
          reveal: [
            type: :boolean,
            default: false,
            doc:
              "Show the series one after the other, or the links of a sankey one column at a time. A pie takes no reveal option."
          ],
          dim: [
            type: :boolean,
            default: false,
            doc: "Dim each series when a later series shows."
          ],
          separator: [
            type: :string,
            default: "/",
            doc:
              "The text between two levels of a category of a treemap or a sunburst, such as \"Production/Press\". The default is a slash."
          ],
          levels: [
            type: {:list, :string},
            doc:
              "The headings of the columns of a CSV file that hold the levels of the categories of a treemap or a sunburst, from the top level down, or the nodes of each path of a sankey. Requires the src option."
          ],
          frames: [
            type: :string,
            doc:
              "The heading of the column of a CSV file that names the frame of each row. Requires the src option."
          ],
          frame_label: [
            type: {:in, [:top_right, :top_left, :none]},
            default: :top_right,
            doc: "The place of the label of the frame in a chart with frames."
          ],
          sort: [
            type: :boolean,
            default: false,
            doc:
              "Put the categories of a bar chart in order of their totals, from the largest, in each frame."
          ],
          count: [
            type: :boolean,
            default: false,
            doc:
              "Count each value from the value of one frame to the value of the next. The default is a fade."
          ],
          thumbnail: [
            type: {:or, [{:in, [:first, :last]}, :pos_integer]},
            default: :first,
            doc:
              "The frame that the overview and the menu of the slides show: :first, :last or the number of a frame."
          ]
        ]
  }

  # A list holds items, and an item holds nested lists. The item declares the
  # key of its children without their definitions: in the block of an item,
  # the `list` macro of the slide stays in scope, so a list can nest to each
  # depth. See "The definitions of the elements" in docs/architecture.md.
  @item %Spark.Dsl.Entity{
    name: :item,
    target: Expresso.Element.Item,
    args: [:text],
    entities: [elements: [], on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        @goto_schema ++
        [text: [type: :string, required: true, doc: "The text of the item."]]
  }

  @list %Spark.Dsl.Entity{
    name: :list,
    target: Expresso.Element.List,
    entities: [elements: [@item], on: [@on]],
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
              "The lines of the src file that the element shows: a range, such as 10..24, or a start text and an end text, such as [from: \"def start(\", to: \"end\"]. to: :block ends the lines at the end of the block of the start line. The default is each line of the file. See docs/reference/code-element.md."
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
              "Groups of lines, one group at each step: line numbers, ranges, and texts such as [from: \"def start(\", to: \"end\"] or [from: \"def start(\", to: :block]. With src, a number is the number of the line in the file, unless relative is true. See docs/reference/code-element.md."
          ],
          dim: [
            type: :boolean,
            default: false,
            doc: "Dim each group of lines when a later group shows. See docs/overlays.md."
          ],
          highlight: [
            type: {:custom, Expresso.Element.Code, :reveal, []},
            doc:
              "Groups of lines in the form of reveal, one group in focus at each step. Each line shows at each step, and the lines that are not in focus dim. See docs/reference/code-element.md."
          ],
          trailing_comments: [
            type: :boolean,
            default: true,
            doc:
              "false removes a comment at the end of a line that has code before it. A line that is only a comment stays. The default is true. See docs/reference/code-element.md."
          ],
          wrap: [
            type: :boolean,
            default: false,
            doc:
              "Break a line that is too long for the slide, with its next parts indented under its start. The layout check then does not report the line. The default is false."
          ],
          relative: [
            type: :boolean,
            default: false,
            doc:
              "Count the numbers of reveal and highlight from the first line that the element shows, so 1 is the first line of the excerpt. The default is false: a number is the number of the line in the file."
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
          ],
          alt: [
            type: :string,
            doc:
              "The text of the diagram for a screen reader. The diagram then has the role img, and a screen reader reads this text in the place of the text of the SVG. See docs/reference/diagram-element.md."
          ]
        ]
  }

  @stat %Spark.Dsl.Entity{
    name: :stat,
    target: Expresso.Element.Stat,
    args: [:value],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          value: [
            type: {:or, [:integer, :float]},
            required: true,
            doc: "The number, such as 1250 or 99.5. See docs/reference/stat-element.md."
          ],
          label: [type: :string, doc: "The text under the number, such as \"orders this year\"."],
          prefix: [type: :string, doc: "The text before the number, such as \"$\"."],
          suffix: [type: :string, doc: "The text after the number, such as \"%\" or \"k\"."],
          decimals: [
            type: :non_neg_integer,
            doc:
              "The number of digits after the point. The default is the decimals of the value: 0 for an integer."
          ],
          group: [
            type: :boolean,
            default: true,
            doc: "Put a comma between each group of three digits, such as 1,250."
          ],
          count: [
            type: :boolean,
            default: false,
            doc: "Count from the from option to the value when the stat shows."
          ],
          from: [
            type: {:or, [:integer, :float]},
            default: 0,
            doc: "The number at the start of the count. The default is 0."
          ]
        ]
  }

  @icon %Spark.Dsl.Entity{
    name: :icon,
    target: Expresso.Element.Icon,
    args: [:name],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          name: [
            type: :string,
            required: true,
            doc:
              "The name of a Lucide icon, such as \"rocket\", or a name of the icons option of the deck. See docs/reference/icon-element.md."
          ],
          label: [type: :string, doc: "The text under the icon. A screen reader reads it."],
          size: [
            type: :string,
            default: "3em",
            doc: "The width and the height of the icon, as a CSS length. The default is 3em."
          ],
          color: [
            type: {:in, Expresso.Element.Icon.colors()},
            default: :text,
            doc:
              "The role of the theme that gives the color: :text, :muted, :accent, :success, :emphasis, :warning or :danger. The default is :text."
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
    @audio,
    @qr_code,
    @chart,
    @stat,
    @icon
  ]

  @toc %Spark.Dsl.Entity{
    name: :toc,
    target: Expresso.Element.Toc,
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          reveal: [
            type: :boolean,
            default: false,
            doc: "Show the entries one after the other, one at each step."
          ],
          dim: [
            type: :boolean,
            default: false,
            doc: "Dim each entry when a later entry shows."
          ],
          progress: [
            type: {:in, Expresso.Element.Toc.progress_values()},
            default: :dim_rest,
            doc:
              "How the entries other than the current section look: :dim_rest, :dim_earlier, :check_earlier or :strike_earlier. See docs/reference/toc-element.md."
          ]
        ]
  }

  # A callout holds the elements of a text box, and not a callout or columns.
  @callout %Spark.Dsl.Entity{
    name: :callout,
    target: Expresso.Element.Callout,
    args: [:kind],
    entities: [elements: [], on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          kind: [
            type: {:in, Expresso.Element.Callout.kinds()},
            required: true,
            doc:
              "The kind of the callout: :note, :tip, :important, :warning, :caution, :definition or :example. See docs/reference/callout-element.md."
          ],
          title: [
            type: {:custom, Expresso.Element.Callout, :title, []},
            doc:
              "The text of the header in place of the name of the kind, such as \"Before you start\". The value false removes the header."
          ]
        ]
  }

  @column %Spark.Dsl.Entity{
    name: :column,
    target: Expresso.Element.Column,
    entities: [elements: [], on: [@on]],
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

  @columns %Spark.Dsl.Entity{
    name: :columns,
    target: Expresso.Element.Columns,
    entities: [elements: [@column], on: [@on]],
    schema: @overlay_schema ++ @class_schema
  }

  @text_box %Spark.Dsl.Entity{
    name: :text_box,
    target: Expresso.Element.TextBox,
    entities: [elements: [], on: [@on]],
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

  @shape %Spark.Dsl.Entity{
    name: :shape,
    target: Expresso.Element.Shape,
    args: [:kind],
    entities: [on: [@on]],
    transform: {Expresso.Element.Shape, :check, []},
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          kind: [
            type: {:in, Expresso.Element.Shape.kinds()},
            required: true,
            doc:
              "The kind of the shape: :rect, :ellipse, :line or :arrow. See docs/reference/shape-element.md."
          ],
          x: [
            type: :string,
            doc:
              "The left edge of a rectangle or an ellipse, such as 10%. A percentage is a part of the width of the slide."
          ],
          y: [
            type: :string,
            doc:
              "The top edge of a rectangle or an ellipse, such as 20%. A percentage is a part of the height of the slide."
          ],
          width: [type: :string, doc: "The width of a rectangle or an ellipse, such as 30%."],
          height: [type: :string, doc: "The height of a rectangle or an ellipse, such as 15%."],
          from: [
            type: {:custom, Expresso.Element.Shape, :point, []},
            doc: "The start of a line or an arrow, such as [\"10%\", \"50%\"]."
          ],
          to: [
            type: {:custom, Expresso.Element.Shape, :point, []},
            doc: "The end of a line or an arrow. The head of an arrow is at this point."
          ],
          text: [
            type: :string,
            doc: "A short text in the center of a rectangle or an ellipse."
          ],
          fill: [
            type: :boolean,
            default: false,
            doc: "Fill a rectangle or an ellipse with a light tint of its color."
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

  @slide_elements [
    elements:
      [@text_box, @columns, @callout, @toc] ++ @inner_elements ++ [@footnote, @shape, @pause]
  ]

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
      sr_heading: [
        type: :boolean,
        doc:
          "false gives the slide no hidden heading. A slide with no h1 otherwise gets an h1 that only a screen reader reads, with the name of the slide. See docs/reference/accessibility.md."
      ],
      section: [
        type: :string,
        doc:
          "The title of the section that starts at this slide. The section runs to the next slide with a section. A toc lists the sections. See docs/reference/toc-element.md."
      ],
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
      morph: [
        type: {:in, @morph_modes},
        doc:
          "The morph between the slide before and this slide, in the two directions: :auto, :named or :off. The default is the morph of the deck. See docs/reference/morph-option.md."
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
      morph: [
        type: {:in, @morph_modes},
        default: :auto,
        doc:
          "How the elements of two neighbor slides move from one slide to the next: :auto matches the same elements and the keys of the morph option, :named matches only the keys, and :off has no morph. See docs/reference/morph-option.md."
      ],
      lang: [
        type: {:custom, Expresso.Deck, :lang, []},
        default: "en",
        doc:
          "The language of the text of the deck, as a language tag, such as \"de\" or \"pt-BR\". A screen reader selects its voice from it. The default is \"en\". See docs/reference/lang-option.md."
      ],
      dim_contrast: [
        type: {:custom, Expresso.Deck, :dim_contrast, []},
        doc:
          "The minimum contrast ratio of dimmed text on its background, from 3 to 7. The default is 3. Give 4.5 to meet WCAG 2.2 criterion 1.4.3 for normal text. See docs/reference/dim-contrast-option.md."
      ],
      icons: [
        type: :keyword_list,
        doc:
          "Icons of your own: a name and the path of an SVG file for each, such as [logo: \"assets/logo.svg\"]. A name of the deck wins over a Lucide name. See docs/reference/icon-element.md."
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
    transformers: [
      Expresso.PlacementTransformer,
      Expresso.PathTransformer,
      Expresso.IconTransformer,
      Expresso.SectionTransformer,
      Expresso.Overlay.Transformer
    ],
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
