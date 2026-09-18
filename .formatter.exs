# Used by "mix format"

# `mix spark.formatter --extensions Expresso.Extension` manages this list. Run it
# after a change to an entity or an option of the DSL. The formatter then adds no
# parentheses to a call of the DSL. It removes none either, so write a call
# without them.
spark_locals_without_parens = [
  alt: 1,
  at: 1,
  auto_reveal: 1,
  heading: 1,
  image: 1,
  image: 2,
  name: 1,
  on: 1,
  on: 2,
  pause: 0,
  pause: 1,
  set: 1,
  slide: 0,
  slide: 1,
  slide: 2,
  state: 1,
  steps: 1,
  text: 1,
  text_area: 0,
  text_area: 1,
  text_box: 0,
  text_box: 1,
  width: 1
]

[
  import_deps: [:spark, :stream_data, :temple],
  inputs: ["{mix,.formatter,.check}.exs", "{config,lib,test,examples}/**/*.{ex,exs}"],
  locals_without_parens: spark_locals_without_parens,
  export: [locals_without_parens: spark_locals_without_parens]
]
