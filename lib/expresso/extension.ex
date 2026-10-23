defmodule Expresso.Extension do
  @moduledoc """
  The Spark DSL extension

  It gives the `deck` section, the `slide` entity and the entities of an element.
  The transformers and the verifiers run for each deck module.
  `Expresso.VerifierTransformer` runs the checks that give only errors, so an
  error stops the compile. The verifiers give only warnings.
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

  # The frame of a window around a code element, an image or an embed.
  # `Expresso.Element.Window` gives the rules.
  @window_schema [
    window: [
      type: {:in, Expresso.Element.Window.styles()},
      doc:
        "A frame that looks like a window of an operating system: :macos, :terminal, :plain or :none. The default is the window option of the deck. See docs/reference/window-option.md."
    ],
    window_title: [
      type: :string,
      doc:
        "The text of the bar of the window. A code element with src shows the name of its file without this option."
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
        @window_schema ++
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
        @window_schema ++
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
    transform: {Expresso.Element.QrCode, :check, []},
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

  @number {:or, [:integer, :float]}

  @point %Spark.Dsl.Entity{
    name: :point,
    target: Expresso.Element.Point,
    args: [:name],
    entities: [on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          name: [
            type: :string,
            required: true,
            doc: "The name of the point. It names the mark, and the table holds it."
          ],
          x: [type: @number, required: true, doc: "The value of the point on the x axis."],
          y: [type: @number, required: true, doc: "The value of the point on the y axis."],
          symbol: [
            type: {:or, [:string, {:in, Expresso.Element.Chart.Encoding.symbols()}]},
            doc:
              "The symbol of the mark: a category, such as \"EU\", or a symbol, such as :square. The categories take :circle, :square, :triangle, :diamond, :cross and :star, in this order. The default is :circle."
          ],
          color: [
            type: {:or, [:string, {:in, Expresso.Element.Chart.Encoding.roles()}]},
            doc:
              "The color of the mark: a category, such as \"EU\", or a role of the theme, such as :chart_3 or :accent. The categories take the colors of the series in order."
          ],
          size: [
            type: @number,
            doc:
              "A number more than zero. The area of the mark grows in proportion to it. A bubble chart needs a size for each point."
          ]
        ]
  }

  @series %Spark.Dsl.Entity{
    name: :series,
    target: Expresso.Element.Series,
    args: [:name, {:optional, :values}],
    entities: [elements: [@point], on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          name: [type: :string, required: true, doc: "The name of the series."],
          values: [
            type: {:list, {:or, [:integer, :float]}},
            doc:
              "One number for each category of the chart, in the order of the categories. A series of a scatter plot holds point entities in place of values."
          ],
          symbol: [
            type: {:in, Expresso.Element.Chart.Encoding.symbols()},
            doc:
              "The symbol of each point of a series of a scatter plot, such as :square. A point can replace it. The default is :circle."
          ],
          color: [
            type: {:in, Expresso.Element.Chart.Encoding.roles()},
            doc:
              "The color of each point of a series of a scatter plot: a role of the theme, such as :chart_3 or :accent. A point can replace it. The default is the color of the place of the series, from :chart_1."
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
        doc: "The value of the flow, zero or more."
      ]
    ]
  }

  # A node of a chart of flows, or a node of a tree. A node of a tree holds
  # the nodes under it. The node declares the key of its children without
  # their definitions: in the block of a node, the `node` macro of the tree
  # stays in scope, so a tree can nest to each depth, as a list does. See
  # "The definitions of the elements" in docs/architecture.md. Each parent
  # refuses the options of the other parent: see `Expresso.Element.Node`.
  @node %Spark.Dsl.Entity{
    name: :node,
    target: Expresso.Element.Node,
    args: [:name],
    entities: [elements: [], on: [@on]],
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          name: [
            type: :string,
            required: true,
            doc:
              "The name of the node in the flows of a chart, or the identity of the node in a tree."
          ],
          label: [
            type: :string,
            doc: "The text of the label of the node. The default is the name."
          ],
          detail: [
            type: :string,
            doc:
              "The second line of the box of a node in a tree, such as a role. Only a tree takes this option."
          ],
          image: [
            type: :string,
            doc:
              "The path of an image that the box of a node in a tree shows in a circle, such as \"ana.jpg\". Only a tree takes this option."
          ],
          icon: [
            type: :string,
            doc:
              "The name of an icon that the box of a node in a tree shows, in place of an image. See the icon element. Only a tree takes this option."
          ],
          fields: [
            type: {:custom, Expresso.Element.Node, :fields, []},
            doc:
              "Short facts under the detail of the box of a node in a tree, one line each, such as [team: \"42 people\"]. Only a tree takes this option."
          ],
          parent: [
            type: :string,
            doc:
              "The name of the node above a node in a tree, in place of nesting, such as \"Ana\". Only a node at the top of the tree takes this option. Only a tree takes this option."
          ],
          layout: [
            type: {:in, Expresso.Element.Hierarchy.Layout.layouts()},
            doc:
              "How the nodes under a node in a tree go, and the nodes under them: :top_down, :left_right or :stacked. The default is the layout of the tree. Only a tree takes this option."
          ],
          value: [
            type: {:custom, Expresso.Element.Node, :value, []},
            doc:
              "A number of a node in a tree that is not negative, such as a size or a count. Only a tree takes this option."
          ],
          color: [
            type: {:in, Expresso.Element.Icon.colors()},
            doc:
              "The role of the theme that gives the color of the box of a node in a tree, and of the boxes under it: :text, :muted, :accent, :success, :emphasis, :warning or :danger. Only a tree takes this option."
          ],
          column: [
            type: :pos_integer,
            doc:
              "The column of the node, from 1 at the left. The default is one column after its last source. Only a sankey takes this option."
          ],
          order: [
            type: :integer,
            doc:
              "The place of the node in its column, from the top. The default is its place in the data."
          ]
        ]
  }

  @frame %Spark.Dsl.Entity{
    name: :frame,
    target: Expresso.Element.Frame,
    args: [:label],
    entities: [elements: [@series, @node, @point], flows: [@flow]],
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
    entities: [
      elements: [@series, @point],
      timeline: [@frame],
      flows: [@flow, @node],
      on: [@on]
    ],
    transform: {Expresso.Element.Chart, :check, []},
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          kind: [
            type: {:in, Expresso.Element.Chart.Kinds.all()},
            required: true,
            doc:
              "The kind of the chart: #{Enum.map_join(Expresso.Element.Chart.Kinds.all(), ", ", &inspect/1)}. See docs/reference/chart-element.md."
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
              "The name of each category, such as [\"2023\", \"2024\"]. A category of a treemap or a sunburst can be a list of its levels, such as [\"Production\", \"Press\"]. A category of a sankey is a path of nodes, such as [\"Coal\", \"Electricity\"]."
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
              "Show the series one after the other. A sankey and an alluvial chart show their links one column at a time. A parallel sets chart shows its nodes first, then the ribbons of one first node at a time. A chord chart shows its ring first, then the chords of one source at a time. A pie takes no reveal option."
          ],
          dim: [
            type: :boolean,
            default: false,
            doc: "Dim each series when a later series shows."
          ],
          highlight: [
            type: {:list, {:or, [:string, {:list, :string}]}},
            doc:
              "Groups of series or of categories, one group in focus at each step, such as [\"Returns\", [\"Orders\", \"Returns\"], \"2024\"]. Each item is the name of a series or of a category, or a list of names. Each series shows at each step, and the rest of the chart dims. A category of a treemap or a sunburst is a part or a group, such as \"Production/Press\" or \"Production\". A chart of flows takes the names of nodes in place of categories. See docs/reference/chart-element.md."
          ],
          whole_first: [
            type: :boolean,
            default: false,
            doc:
              "With highlight, show the whole chart in full color for one step before the first group comes into focus. The default is false."
          ],
          separator: [
            type: :string,
            default: "/",
            doc:
              "The text between two levels of a category of a treemap or a sunburst, such as \"Production/Press\". The default is a slash."
          ],
          shape: [
            type: {:custom, Expresso.Element.Chart.Voronoi, :shape, []},
            doc:
              "The container of a voronoi chart: :rectangle, :circle, :hexagon, or a list of points in a unit box, such as [{0, 0}, {1, 0}, {0.5, 1}]. The y axis goes down, so {0.5, 1} is at the bottom. The polygon must be convex. The default is :rectangle."
          ],
          levels: [
            type: {:list, :string},
            doc:
              "For a treemap or a sunburst, the headings of the CSV columns that hold the levels, from the top level down. For a chart of flows, the headings of the CSV columns that hold the nodes of each path. Requires the src option, but an alluvial chart or a parallel sets chart can take levels without src to give the title of each column."
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
          ],
          x_label: [
            type: :string,
            doc:
              "The name of the x axis of a scatter plot, such as \"Cost per month\". It goes under the axis and into the header of the table."
          ],
          y_label: [
            type: :string,
            doc:
              "The name of the y axis of a scatter plot, such as \"Requests per second\". It goes beside the axis and into the header of the table."
          ],
          x_range: [
            type: {:tuple, [@number, @number]},
            doc:
              "The low end and the high end of the x axis of a scatter plot, such as {0, 100}. The default comes from the points."
          ],
          y_range: [
            type: {:tuple, [@number, @number]},
            doc:
              "The low end and the high end of the y axis of a scatter plot, such as {0, 100}. The default comes from the points."
          ],
          label: [
            type: :string,
            doc:
              "The heading of the column of the CSV file of a scatter plot that names each point. The default is the first column. Requires the src option."
          ],
          x: [
            type: :string,
            doc:
              "The heading of the column of the CSV file of a scatter plot with the x values. The default is \"x\". Requires the src option."
          ],
          y: [
            type: :string,
            doc:
              "The heading of the column of the CSV file of a scatter plot with the y values. The default is \"y\". Requires the src option."
          ],
          symbol: [
            type: :string,
            doc:
              "The heading of the column of the CSV file of a scatter plot with the category of the symbol. Requires the src option."
          ],
          color: [
            type: :string,
            doc:
              "The heading of the column of the CSV file of a scatter plot with the category of the color. Requires the src option."
          ],
          size: [
            type: :string,
            doc:
              "The heading of the column of the CSV file of a scatter plot with the size of each point. Requires the src option."
          ],
          labels: [
            type: {:or, [{:in, [:all, :none]}, {:list, :string}]},
            default: :none,
            doc:
              "The points of a scatter plot with a label: :all, :none, or a list of the names of points, such as [\"api\", \"web\"]. A label goes next to its mark and does not cover another label. The default is :none."
          ],
          symbol_label: [
            type: :string,
            doc:
              "The title of the legend of the symbols of a scatter plot, such as \"Region\", and the header of its column in the table."
          ],
          color_label: [
            type: :string,
            doc:
              "The title of the legend of the colors of a scatter plot, and the header of its column in the table."
          ],
          size_label: [
            type: :string,
            doc:
              "The title of the legend of the sizes of a scatter plot, such as \"Users\", and the header of its column in the table."
          ],
          opacity: [
            type: {:custom, Expresso.Element.Chart.Encoding, :opacity, []},
            doc:
              "The opacity of each mark of a scatter plot, from 0 to 1, such as 0.6. An area with many marks then looks darker."
          ],
          x_scale: [
            type: {:in, [:linear, :log]},
            default: :linear,
            doc: "The scale of the x axis of a scatter plot: :linear or :log."
          ],
          y_scale: [
            type: {:in, [:linear, :log]},
            default: :linear,
            doc: "The scale of the y axis of a scatter plot: :linear or :log."
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
    transform: {Expresso.Element.Table, :check, []},
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          caption: [
            type: :string,
            doc:
              "The name of the table, as text. It shows above the table, and a screen reader reads it when it moves into the table. See docs/reference/table-element.md."
          ],
          caption_hidden: [
            type: :boolean,
            default: false,
            doc:
              "Hide the caption from the eye and not from a screen reader. The table needs the caption option."
          ],
          header: [
            type: :boolean,
            default: false,
            doc: "Make the first row the header of the table."
          ],
          row_header: [
            type: :boolean,
            default: false,
            doc: "Make the first cell of each row the header of its row."
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
        @window_schema ++
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
    args: [{:optional, :src}],
    entities: [elements: [@part], on: [@on]],
    transform: {Expresso.Element.Diagram, :check, []},
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          src: [
            type: :string,
            doc:
              "The path of the SVG file, or of the source of a graph such as a .dot, a .d2 or a .mmd file, from the root option of the deck or from the working directory of the command. Give this argument or the source option."
          ],
          source: [
            type: :string,
            doc:
              "The text of a graph in the deck, in place of a file, such as \"flowchart LR\\n  a --> b\". It needs the lang option. See docs/reference/diagram-element.md."
          ],
          lang: [
            type: {:in, [:mermaid]},
            doc:
              "The language of the source option: :mermaid. A file gives its language with its extension."
          ],
          width: [
            type: :string,
            doc: "The width of the diagram, such as 900px or 60%. See docs/architecture.md."
          ],
          layout: [
            type:
              {:in,
               Expresso.Element.Diagram.Graphviz.layouts() ++
                 Expresso.Element.Diagram.D2.layouts()},
            doc:
              "The layout engine of the tool that draws a graph, such as :neato for Graphviz or :dagre for D2. See docs/reference/diagram-element.md."
          ],
          edges: [
            type: {:in, [:follow, :own]},
            doc:
              "When an edge of a graph without its own part shows. :follow, the default, shows it from the step where both of its ends show. :own shows it at each step. See docs/reference/diagram-element.md."
          ],
          colors: [
            type: {:in, [:theme, :tool]},
            doc:
              "The colors of a graph. :theme, the default, gives the graph the colors of the theme. :tool keeps the colors of the tool. See docs/reference/diagram-element.md."
          ],
          font: [
            type: :string,
            doc:
              "A directory with the TTF files of the font of a graph, from the root option of the deck. The default is the font of the built-in theme. See docs/reference/diagram-element.md."
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

  @tree %Spark.Dsl.Entity{
    name: :tree,
    target: Expresso.Element.Hierarchy,
    entities: [elements: [@node], timeline: [@frame], on: [@on]],
    transform: {Expresso.Element.Hierarchy, :check, []},
    schema:
      @overlay_schema ++
        @class_schema ++
        [
          title: [
            type: :string,
            required: true,
            doc: "The name of the tree for a screen reader."
          ],
          width: [
            type: :string,
            doc: "The width of the tree, such as 900px or 70%. The default is 80%."
          ],
          color: [
            type: {:custom, Expresso.Element.Hierarchy, :color, []},
            doc:
              "The colors of the boxes from the palette: :branch gives each node under the root and its boxes a color, and {:field, \"name\"} gives each value of a field a color and adds a legend. The color option of a node comes first. The default is no color."
          ],
          reveal: [
            type: {:in, [:levels, :branches, :nodes]},
            doc:
              "Show the nodes in steps: :levels shows one level at each step, :branches shows the root and then one branch at each step, and :nodes shows one node at each step. A node with its own at option keeps it."
          ],
          dim: [
            type: :boolean,
            default: false,
            doc:
              "Dim the boxes of the earlier steps when a later box shows. The default is false."
          ],
          highlight: [
            type: {:custom, Expresso.Element.Hierarchy, :highlight, []},
            doc:
              "Groups of nodes, one group in focus at each step, such as [\"Ben\", branch(\"Ben\"), [\"Cy\", \"Di\"]]. An item is the name of a node, branch(name) for a node and each node under it, or a list of those. The rest of the tree dims. See docs/reference/tree-element.md."
          ],
          whole_first: [
            type: :boolean,
            default: false,
            doc:
              "With highlight, show the whole tree in full color for one step before the first group comes into focus. The default is false."
          ],
          reflow: [
            type: :boolean,
            default: false,
            doc:
              "Calculate the layout at each step from the boxes that show, and move the boxes when a box shows. The default is false: the layout keeps a place for each box from the first step, and no box moves."
          ],
          src: [
            type: :string,
            doc:
              "The path of a CSV file with a row for each node, from the root option of the deck or from the working directory of the command. The file has the columns id and parent, or the column path. See docs/reference/tree-element.md."
          ],
          delimiter: [
            type: :string,
            doc:
              "The character between two cells of the src file, such as \";\". The default is a comma, or a tab for a file that ends in .tsv. Requires the src option."
          ],
          frames: [
            type: :string,
            doc:
              "The heading of the column of the src file that names the frame of each row, such as \"year\". Each value of the column is a frame, in the order of the file. Requires the src option."
          ],
          separator: [
            type: :string,
            default: "/",
            doc:
              "The text between two levels of a path in the column path of the src file, such as \"home/photos\". The default is a slash."
          ],
          fields: [
            type: {:list, :string},
            doc:
              "The headings of the columns of the src file that become the fields of each box, in that order, such as [\"team\", \"site\"]. Requires the src option."
          ],
          layout: [
            type: {:in, Expresso.Element.Hierarchy.Layout.layouts()},
            default: :top_down,
            doc:
              "How the nodes under each node go: :top_down puts them in a row under the node, :left_right puts them in a column at its right, and :stacked puts them one under the other below it. The default is :top_down."
          ],
          stack_from: [
            type: {:custom, Expresso.Element.Hierarchy, :stack_from, []},
            doc:
              "The first level that the tree puts in the layout :stacked, with 1 for the root. The default is no stacked level."
          ],
          sum: [
            type: :boolean,
            default: true,
            doc:
              "Give a node with no value the sum of the values of the nodes under it. The default is true."
          ],
          value_format: [
            type: {:in, [:number, :bytes, :percent]},
            default: :number,
            doc:
              "The text of a value: :number gives 1,250, :bytes gives 412 GB, and :percent gives the part of the value of the root, such as 12.5%. The default is :number."
          ],
          sort: [
            type: {:in, [:value, :none]},
            default: :none,
            doc:
              "The order of the nodes under each node: :value puts the largest value first, and :none keeps the order of the data. The default is :none."
          ],
          bar: [
            type: :boolean,
            default: false,
            doc:
              "Show a bar along the bottom of each box, with a length in proportion to the part of the value of the root. The default is false."
          ],
          limit: [
            type: :pos_integer,
            doc:
              "The most nodes under each node. One more node holds the rest, with the sum of their values."
          ],
          depth: [
            type: :pos_integer,
            doc:
              "The most levels of the tree, with 1 for the root only. A node at the last level shows the total of the values under it."
          ],
          box: [
            type: {:custom, Expresso.Element.Hierarchy, :box, []},
            doc:
              "The size of the boxes of each level, from the root down, in the units of the drawing, such as [[width: 280, height: 120], [width: 220, height: 96]]. The last size applies to each deeper level. The default is [width: 220, height: 96] for each level. See docs/reference/tree-element.md."
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
    @tree,
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
        type: {:custom, Expresso.Template, :validate, [:slide]},
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
      window: [
        type: {:in, Expresso.Element.Window.styles()},
        doc:
          "The frame of each code element, image and embed without a window option: :macos, :terminal, :plain or :none. The default is :none. See docs/reference/window-option.md."
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
        type: {:custom, Expresso.Template, :validate, [:deck]},
        doc:
          "The deck template, which gives the header and the footer: a module, or {:builtins, name}. See docs/architecture.md. The default is {:builtins, :default}."
      ],
      slide_template: [
        type: {:custom, Expresso.Template, :validate, [:slide]},
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
      Expresso.CssTransformer,
      Expresso.IconTransformer,
      Expresso.SectionTransformer,
      Expresso.Overlay.Transformer,
      Expresso.VerifierTransformer
    ],
    verifiers: [
      Expresso.Overlay.PropertyVerifier,
      Expresso.Overlay.SizeVerifier,
      Expresso.ThemeVerifier,
      Expresso.CodeVerifier
    ]
end
