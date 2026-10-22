defmodule Expresso.Presenter.Schema do
  @moduledoc """
  Describes each value that Elixir writes for the script of the presenter

  The renderer writes seven values for the script:

    * the program that `Expresso.Presenter.Program` makes;
    * the list of the steps that `Expresso.Steps` makes;
    * the commands of a page of the overview and of a row of the menu;
    * the commands of the links that `Expresso.Goto` makes;
    * the sources of the embeds that `Expresso.Element.Embed` makes;
    * the sources of the videos that `Expresso.Element.Video` makes;
    * the sources of the sounds that `Expresso.Element.Audio` makes.

  The two windows of the presenter also send a
  message to each other. This module describes the JSON form of each value.
  It is the one source of these forms:

    * `Expresso.Presenter.Verifier` reads the fields of the state, the views,
      the built-in functions and the kind of each value from it.
    * `Expresso.Test.SchemaWriter` writes `assets/src/schema.ts` from it. That
      file holds a TypeScript type and a decoder for each value. A test fails
      when the file does not agree with this module.
    * `Expresso.Presenter.Schema.Check` examines a value with the forms.
      The verifier uses it for the values of a definition, and the tests use
      it for each value that the renderer writes.

  `types/0` returns the forms in order. A form can name an earlier form only.
  `t:type/0` describes the terms of a form.

  `constants/0` returns the constants of the script, such as the kinds of
  element and the selectors of the elements that hold commands.
  `Expresso.Test.SchemaWriter` writes each constant into
  `assets/src/schema.ts` too, so the script and Elixir use the same values.
  """

  @typedoc """
  The form of a JSON value

    * `:boolean` and `:string` - a value of that type.
    * `{:string, pattern}` - a string that agrees with a regular expression,
      in source text.
    * `{:integer, min}` - an integer that is not less than `min`, or any
      integer for `nil`.
    * `{:number, min, max}` - a finite number from `min` to `max`. `nil` sets
      no limit.
    * `{:literal, value}` - exactly one string, boolean or integer.
    * `{:enum, values}` - one of the strings.
    * `{:nullable, type}` - a value of the type, or `null`.
    * `{:list, type}` - an array of values of the type.
    * `{:tuple, types}` - an array with one value of each type, in order.
    * `{:record, fields}` - an array with one value of each field, in order.
      The script reads it as an object with these keys, and
      `Expresso.Presenter.Schema.Record.write/2` writes it. Only a form with
      a name that starts with `written_` holds a record, or a union of records
      with the same keys.
    * `{:object, fields}` - an object with exactly these keys.
    * `{:open_object, fields}` - an object with these keys. It can have other
      keys, and the decoder does not return them.
    * `{:partial, fields}` - an object with some of these keys and no other key.
    * `{:union, types}` - a value of one of the types.
    * `{:ref, name}` - the form of `types/0` with that name.
  """
  @type type ::
          :boolean
          | :string
          | {:string, String.t()}
          | {:integer, integer() | nil}
          | {:number, number() | nil, number() | nil}
          | {:literal, String.t() | boolean() | integer()}
          | {:enum, [String.t()]}
          | {:nullable, type()}
          | {:list, type()}
          | {:tuple, [type()]}
          | {:object, [{atom(), type()}]}
          | {:open_object, [{atom(), type()}]}
          | {:partial, [{atom(), type()}]}
          | {:record, [{atom(), type()}]}
          | {:union, [type()]}
          | {:ref, atom()}

  @typedoc "The kind of value of a field of the state"
  @type kind :: :index | :slide | :view | :boolean | :digits

  # The fields of the state, in the order of the TypeScript type `State`, and
  # the kind of value of each field.
  @fields [
    index: :index,
    view: :view,
    blank: :boolean,
    white: :boolean,
    digits: :digits,
    help: :boolean,
    progress: :boolean,
    every: :boolean,
    overview: :boolean,
    selected: :slide,
    undim: :boolean,
    menu: :boolean,
    cursor: :index
  ]

  @views [:present, :handout, :speaker]
  @builtins [:open_speaker, :fullscreen, :reset_timer, :switch_scheme]
  @transitions [:none, :fade, :slide, :zoom]
  @regions [:left_third, :right]
  @directions [:left, :right]

  @doc "Return the fields of the state and the kind of value of each field, in order"
  @spec fields() :: [{atom(), kind()}]
  def fields, do: @fields

  @doc "Return the views of the presenter"
  @spec views() :: [atom()]
  def views, do: @views

  @doc "Return the built-in functions of the browser that a command can call"
  @spec builtins() :: [atom()]
  def builtins, do: @builtins

  @doc "Return the built-in kinds of the transition into a slide"
  @spec transitions() :: [atom()]
  def transitions, do: @transitions

  @doc "Return the parts of the window under a click"
  @spec regions() :: [atom()]
  def regions, do: @regions

  @doc "Return the directions of a swipe"
  @spec directions() :: [atom()]
  def directions, do: @directions

  @doc """
  Return the form of a value of a kind

      iex> Expresso.Presenter.Schema.kind(:slide)
      {:integer, 1}
  """
  @spec kind(kind()) :: type()
  def kind(:index), do: {:integer, 0}
  def kind(:slide), do: {:integer, 1}
  def kind(:view), do: {:ref, :view}
  def kind(:boolean), do: :boolean
  def kind(:digits), do: {:string, "^[0-9]*$"}

  @doc """
  Return each form, with its name and the text that tells what it is

  The forms come in order. A form can name an earlier form only.
  """
  @spec types() :: [{atom(), String.t(), type()}]
  def types do
    [
      {:view, "A view of the presenter.", strings(@views)},
      {:field, "A field of the state.", strings(Keyword.keys(@fields))},
      {:boolean_field, "A field of the state that holds true or false.",
       strings(fields_of([:boolean]))},
      {:number_field, "A field of the state that holds a number.",
       strings(fields_of([:index, :slide]))},
      {:index_field, "A field of the state that holds the index of a step.",
       strings(fields_of([:index]))},
      {:state, "The state of the presenter. The program holds its first value.",
       {:object, for({field, kind} <- @fields, do: {field, kind(kind)})}},
      {:builtin, "A built-in function of the browser.", strings(@builtins)},
      {:region, "A part of the window under a click.", strings(@regions)},
      {:direction, "The direction of a swipe.", strings(@directions)},
      {:command,
       "A command of the program. `Expresso.Presenter.Definition` tells what each command does.",
       {:union, commands()}},
      {:commands, "The commands of an event, or of an element under a click.",
       {:list, {:ref, :command}}},
      {:written_mode,
       "A mode as the renderer writes it. Each pair holds each event that has the same commands.",
       {:object,
        name: :string,
        when: {:partial, for({field, kind} <- @fields, do: {field, kind(kind)})},
        any: {:nullable, {:ref, :commands}},
        other: {:nullable, {:ref, :commands}},
        element: {:nullable, {:ref, :commands}},
        keys: pairs(:string),
        click: pairs({:ref, :region}),
        swipe: pairs({:ref, :direction})}},
      {:written_attribute,
       "A projection to an attribute of the body, as the renderer writes it: the field, the name of the attribute, and true when the attribute is present only while the field is true.",
       {:union,
        [
          {:record, [field: {:ref, :boolean_field}, name: attribute(), flag: {:literal, true}]},
          {:record, [field: {:ref, :field}, name: attribute(), flag: {:literal, false}]}
        ]}},
      {:written_property,
       "A projection to a custom property of the body, as the renderer writes it: the name of the property, and the value of the current entry that it holds.",
       {:record, [name: {:string, "^--"}, entry: {:enum, ["fraction", "done"]}]}},
      {:written_mark,
       "A projection that marks elements, as the renderer writes it: the attribute, the selector of the elements, the key that each element compares, the value of each mark, and true when the first marked element scrolls into view.",
       {:record,
        [
          attribute: attribute(),
          selector: :string,
          key: {:enum, ["slide", "index"]},
          values: {:list, {:tuple, [:string, {:ref, :number_field}, {:integer, nil}]}},
          scroll: :boolean
        ]}},
      {:written_projections,
       "The projections as the renderer writes them. `Expresso.Presenter.Projection` tells what each one does.",
       {:object,
        attributes: {:list, {:ref, :written_attribute}},
        properties: {:list, {:ref, :written_property}},
        marks: {:list, {:ref, :written_mark}}}},
      {:written_program, "The program of the presenter for one deck, as the renderer writes it.",
       {:object,
        state: {:ref, :state},
        sync: {:list, {:ref, :field}},
        reset: {:list, {:ref, :field}},
        modes: {:list, {:ref, :written_mode}},
        project: {:ref, :written_projections}}},
      {:kind,
       "The kind of the transition into a slide: a built-in kind, or a transition of the CSS of the deck.",
       {:string, "^[A-Za-z0-9-]+$"}},
      {:slide,
       "One slide of the deck: the index of its step 1, its number of steps, and the transition into it.",
       {:object, first: {:integer, 0}, steps: {:integer, 1}, transition: {:ref, :kind}}},
      {:written_entry,
       "One step of the deck as the renderer writes it: the slide, the step, the fraction, the done part and the position.",
       {:record,
        [
          slide: {:integer, 1},
          step: {:integer, 1},
          fraction: {:number, 0, 1},
          done: {:number, 0, 1},
          position: :string
        ]}},
      {:written_deck, "The steps and the slides of a deck, as the renderer writes them.",
       {:object,
        steps: {:list, {:ref, :written_entry}},
        slides: {:list, {:ref, :slide}},
        duration_ms: {:nullable, {:integer, 1}}}},
      {:written_embeds,
       "The source of each embed of a deck, in the order of the numbers of the elements, as the renderer writes it.",
       {:list, {:object, kind: {:enum, ["src", "srcdoc"]}, value: :string}}},
      {:written_links,
       "The commands of each link of the `goto` option of a deck, in the order of the numbers of the links, as the renderer writes it.",
       {:list, {:ref, :commands}}},
      {:written_videos,
       "The data URI of each video of a deck, in the order of the numbers of the elements, as the renderer writes it.",
       {:list, {:string, "^data:video/(webm|mp4);base64,"}}},
      {:written_audios,
       "The data URI of each sound of a deck, in the order of the numbers of the elements, as the renderer writes it.",
       {:list, {:string, "^data:audio/(mpeg|mp4|ogg|wav);base64,"}}},
      {:scheme,
       "The variant of a theme with a light and a dark variant that the key t chose, or null for the variant of the screen.",
       {:nullable, {:enum, ["light", "dark"]}}},
      {:message,
       "The message that one window of the presenter sends to the other window. `fields` holds the fields of the option `sync` of the presenter. The other window ignores a key that it does not know.",
       {:open_object,
        expresso: {:literal, "position"},
        slide: {:integer, nil},
        step: {:integer, nil},
        fields: {:partial, for({field, kind} <- @fields, do: {field, kind(kind)})},
        scheme: {:ref, :scheme},
        time: {:number, nil, nil}}},
      {:request,
       "The message that the speaker view sends to the present view after its load. The present view answers with a message of its full state.",
       {:open_object, expresso: {:literal, "request"}}},
      {:element_kind, "A kind of element: the class of its root tag, and its name.",
       {:tuple, [:string, :string]}}
    ]
  end

  @doc """
  Return each constant of the script, with its name, the text that tells
  what it is, its form and its value

  A constant comes from Elixir and goes into the script when esbuild makes
  the bundle, so the document does not hold it.
  """
  @spec constants() :: [{atom(), String.t(), type(), term()}]
  def constants do
    [
      {:element_kinds,
       "Each kind of element that the script finds by the class of its root tag, in the order of the search. `Expresso.Element.kinds/0` tells how the script uses them.",
       {:list, {:ref, :element_kind}},
       for({_module, class, kind, _content} <- Expresso.Element.kinds(), do: [class, kind])},
      {:command_holders,
       "The selectors of the three kinds of element that hold the commands of a click: a link of the `goto` option, a page of the overview and a row of the menu. A link holds the number of its commands in the element `expresso-links`, and a page and a row hold their commands in `data-commands`. The script reads commands only from these elements.",
       {:object, link: :string, page: :string, row: :string},
       %{
         "link" => "a.goto[data-link]",
         "page" => ".handout-page[data-commands]",
         "row" => "#menu .menu-slide[data-commands], #menu .menu-step[data-commands]"
       }}
    ]
  end

  # The commands of a compiled program. A program holds numbers in place of
  # the symbols of a definition. A deck with no slide has `["goto", null]`
  # and `["select", 0]`, and these commands make no change.
  defp commands do
    sets = for {field, kind} <- @fields, do: {:tuple, [literal(field), kind(kind)]}

    Enum.map(sets, fn {:tuple, types} -> {:tuple, [{:literal, "set"} | types]} end) ++
      [
        {:tuple, [{:literal, "toggle"}, {:ref, :boolean_field}]},
        {:tuple, [{:literal, "clear"}, {:ref, :field}]},
        {:tuple,
         [
           {:literal, "assign"},
           {:literal, "selected"},
           {:tuple, [{:literal, "entry"}, {:literal, "slide"}]}
         ]},
        {:tuple, [{:literal, "append"}, {:literal, "digits"}]},
        {:tuple, [{:literal, "step"}, {:integer, nil}]},
        {:tuple, [{:literal, "goto"}, {:nullable, {:integer, 0}}]},
        {:tuple, [{:literal, "goto_slide"}, {:union, [{:literal, "selected"}, {:integer, 1}]}]},
        {:tuple, [{:literal, "select"}, {:integer, 0}]},
        {:tuple, [{:literal, "select_by"}, {:integer, nil}]},
        {:tuple, [{:literal, "copy"}, {:ref, :index_field}, {:ref, :index_field}]},
        {:tuple, [{:literal, "move"}, {:ref, :index_field}, {:integer, nil}]},
        {:tuple, [{:literal, "go"}, {:ref, :index_field}]},
        {:tuple, [{:literal, "go_typed"}]},
        {:tuple, [{:literal, "builtin"}, {:ref, :builtin}]}
      ]
  end

  defp pairs(event), do: {:list, {:tuple, [{:list, event}, {:ref, :commands}]}}

  defp attribute, do: {:string, "^data-"}

  defp literal(atom), do: {:literal, Atom.to_string(atom)}

  defp strings(atoms), do: {:enum, Enum.map(atoms, &Atom.to_string/1)}

  defp fields_of(kinds), do: for({field, kind} <- @fields, kind in kinds, do: field)
end
