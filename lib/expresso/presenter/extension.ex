defmodule Expresso.Presenter.Extension do
  @moduledoc """
  The Spark DSL extension of the presenter definition

  It gives the options `state` and `sync`, the `mode` entity, and the `key` and
  `event` entities of a mode. It imports `Expresso.Presenter.Commands`, so a
  binding can write `step(1)` in place of `{:step, 1}`.
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
              {:tuple, [{:in, [:click]}, {:in, [:left_third, :right]}]},
              {:tuple, [{:in, [:swipe]}, {:in, [:left, :right]}]},
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

  @presenter %Spark.Dsl.Section{
    name: :presenter,
    top_level?: true,
    imports: [Expresso.Presenter.Commands],
    entities: [@mode],
    schema: [
      state: [
        type: :keyword_list,
        required: true,
        doc: "The first value of each field of the state."
      ],
      sync: [
        type: {:list, :atom},
        required: true,
        doc: "The fields that a window sends to the other window."
      ]
    ]
  }

  use Spark.Dsl.Extension,
    sections: [@presenter],
    verifiers: [Expresso.Presenter.Verifier]
end
