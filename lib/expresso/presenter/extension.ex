defmodule Expresso.Presenter.Extension do
  @moduledoc """
  The Spark DSL extension of the presenter definition

  It gives the options `state`, `sync` and `reset`, the `mode` entity, and the `key` and
  `event` entities of a mode. The entities `attribute`, `property` and `mark`
  give the projections of `Expresso.Presenter.Projection`. It imports
  `Expresso.Presenter.Commands`, so a binding can write `step(1)` in place of
  `{:step, 1}`.
  `Expresso.Presenter.Verifier` runs when a module that uses the DSL compiles.

  Only `Expresso.Presenter.Default` uses the DSL. A deck cannot change the
  keys of the presenter.
  """

  @commands {:wrap_list, :any}

  @key %Spark.Dsl.Entity{
    name: :key,
    target: Expresso.Presenter.Binding,
    args: [:keys, :commands, :text],
    transform: {Expresso.Presenter.Binding, :keys, []},
    schema: [
      keys: [
        type: {:wrap_list, :string},
        required: true,
        doc: "The values of `KeyboardEvent.key`, such as \"j\" or \" \"."
      ],
      commands: [type: @commands, required: true, doc: "The commands of the keys."],
      text: [type: :string, required: true, doc: "The text in the list of keys."],
      label: [type: :string, doc: "The name of the keys in the list. The default names each key."],
      each: [
        type: :boolean,
        default: true,
        doc: "Put the `each` commands of the mode in front of the commands."
      ]
    ]
  }

  @pointer {:or,
            [
              {:tuple, [{:in, [:click]}, {:in, Expresso.Presenter.Schema.regions()}]},
              {:tuple, [{:in, [:swipe]}, {:in, Expresso.Presenter.Schema.directions()}]},
              {:in, [:element]}
            ]}

  @event %Spark.Dsl.Entity{
    name: :event,
    target: Expresso.Presenter.Binding,
    args: [:on, :commands, :text],
    schema: [
      on: [
        type: {:wrap_list, @pointer},
        required: true,
        doc:
          "The events, such as [click: :right, swipe: :left], or :element for a click on an element with commands."
      ],
      commands: [type: @commands, required: true, doc: "The commands of the events."],
      text: [type: :string, required: true, doc: "The text in the list of keys."],
      label: [type: :string, required: true, doc: "The name of the events in the list."],
      each: [
        type: :boolean,
        default: true,
        doc: "Put the `each` commands of the mode in front of the commands."
      ]
    ]
  }

  @mode %Spark.Dsl.Entity{
    name: :mode,
    target: Expresso.Presenter.Mode,
    args: [:name],
    entities: [bindings: [@key, @event]],
    schema: [
      name: [type: :atom, required: true, doc: "The name of the mode."],
      match: [
        type: :keyword_list,
        required: true,
        doc: "The condition on the state, such as [view: :present]."
      ],
      each: [
        type: @commands,
        default: [],
        doc: "The commands that go in front of each binding."
      ],
      any: [
        type: @commands,
        doc: "The commands of each event. A mode with this option has no binding."
      ],
      other: [
        type: :boolean,
        default: false,
        doc: "Give the `each` commands to a key with no binding."
      ],
      element: [
        type: :boolean,
        default: false,
        doc: "Run the commands of the element under a click, after the `each` commands."
      ]
    ]
  }

  @attribute %Spark.Dsl.Entity{
    name: :attribute,
    target: Expresso.Presenter.Projection.Attribute,
    args: [:field, :name],
    schema: [
      field: [type: :atom, required: true, doc: "The field of the state."],
      name: [
        type: :string,
        required: true,
        doc: "The attribute of the `body`, such as data-view."
      ],
      flag: [
        type: :boolean,
        default: false,
        doc: "Write \"true\" while the field is true, and remove the attribute while it is false."
      ]
    ]
  }

  @property %Spark.Dsl.Entity{
    name: :property,
    target: Expresso.Presenter.Projection.Property,
    args: [:name, :entry],
    schema: [
      name: [type: :string, required: true, doc: "The custom property, such as --fraction."],
      entry: [
        type: {:in, [:fraction, :done]},
        required: true,
        doc: "The value of the current entry of the list of the steps."
      ]
    ]
  }

  @mark %Spark.Dsl.Entity{
    name: :mark,
    target: Expresso.Presenter.Projection.Mark,
    args: [:attribute, :selector, :key, :values],
    schema: [
      attribute: [type: :string, required: true, doc: "The attribute, such as data-selected."],
      selector: [type: :string, required: true, doc: "The CSS selector of the elements."],
      key: [
        type: {:in, [:slide, :index]},
        required: true,
        doc: "The number of an element: :slide reads data-slide, and :index reads data-index."
      ],
      values: [
        type: {:list, {:tuple, [:string, :atom, :integer]}},
        required: true,
        doc: "Each text of the attribute, with a field of the state and an offset."
      ],
      scroll: [
        type: :boolean,
        default: false,
        doc: "Scroll the first marked element into the view of its container."
      ]
    ]
  }

  @presenter %Spark.Dsl.Section{
    name: :presenter,
    top_level?: true,
    imports: [Expresso.Presenter.Commands],
    entities: [@mode, @attribute, @property, @mark],
    schema: [
      state: [
        type: :keyword_list,
        required: true,
        doc: "The first value of each field of the state."
      ],
      sync: [
        type: {:list, :atom},
        required: true,
        doc:
          "The fields that a window sends to the other window. The message always holds the slide and the step, so the list does not hold index."
      ],
      reset: [
        type: {:list, :atom},
        default: [],
        doc: "The fields that take their first value again at each change of the step."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@presenter],
    verifiers: [Expresso.Presenter.Verifier]
end
