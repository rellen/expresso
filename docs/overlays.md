# Overlay specifications

This document gives the design for overlays. The code contains each part of this design.
The section "Progress" gives the date of each slice, and the section "Changes to the
current code" says where each part is.

An overlay is a step in a slide. Overlays give reveals, emphasis and movement inside one
slide.

## The model

A slide is a function of a step index. The renderer runs one time. It writes all the
states of the slide into one HTML document. CSS then shows the state for the current
step.

The document does not contain a timeline. The person who gives the presentation controls
the step index. CSS calculates the intermediate values between two steps.

This model has one important limit. A CSS transition changes the appearance of one
element. A CSS transition cannot change one element into a different element. Each rule
in this document is a result of this limit.

## Syntax

An overlay specification tells the compiler which steps show an element. Put the
specification in the `at` option of an element.

### The specification

A specification is an Elixir term. The `at` option accepts these forms:

| Term | Meaning |
| --- | --- |
| `3` | Step 3 only. |
| `2..4` | Step 2 to step 4. |
| `[2, 5..7]` | Step 2, and step 5 to step 7. |
| `[from: 2]` | Step 2 and each step after step 2. |
| `:next` | The current value of the slide counter. |
| `[from: :next]` | The current value of the slide counter, and each step after it. |
| `[2, from: 5]` | Step 2, and step 5 and each step after step 5. |

A list holds integers, ranges and `from:` items in any order. `[2, from: 5]` is a list
with a keyword tail, and `mix format` keeps it. An author writes the option as a call
inside the block of the element, `at 3`, in the form of Spark. Spark does not accept an
option as a keyword in front of the block, so `text_box at: 3 do` is not a form.

A call of the DSL has no parentheses, and `.formatter.exs` lists each call so that
`mix format` adds none. `pause()` is the one exception. Elixir reads a bare `pause` as a
variable, and the compile stops with an error. Each step
number is 1 or more, and a range
goes up with a step of 1.

Two forms need data that a term cannot hold. A `from:` item needs the maximum step number
of the slide, and `:next` needs the counter of the slide. Therefore
`Expresso.Overlay.new/1` puts each form into an `Expresso.Overlay` struct, and the
transformer resolves the struct later. The struct holds one pair for each item, the first
step and the last step. In a pair, `:next` stands for the counter and `:max` stands for
the maximum step number.

### The slide counter

Each slide has a counter. The counter starts at 1.

Two constructions change the counter:

- The `pause` entity increments the counter.
- A `+` in a specification takes the current value of the counter. Then the `+`
  increments the counter.

This rule lets an element move in the slide without a change to a number. It also lets an
element take two steps. The `at` option takes the first step, and an `on` entity in the
same element takes the second step.

### An element without an `at` option

An element without an `at` option shows at each step of the slide. The renderer writes no
`data-on` attribute for such an element. The `auto_reveal` option of the slide changes
this rule for an element at the level of the slide. See "The auto_reveal option".

Therefore a `pause` entity alone reveals no element. A `pause` changes the counter only. An
element must contain a `+` to read the new value of the counter. This behavior is different
from `\pause` in Beamer, which reveals the content after it.

This explicit rule is the default. An author who wants the behavior of Beamer writes
`at from: :next` on each element, or gives the slide the `auto_reveal` option.

```elixir
slide "pipeline" do
  text_box do
    at from: :next
    on :next, state: :alert

    text_area do
      text "This box appears at one step. It becomes prominent at the next step."
    end
  end

  pause()

  text_box do
    at 3

    text_area do
      text "This box uses an absolute step number."
    end
  end
end
```

### The `auto_reveal` option

`auto_reveal` is a boolean option of the `slide` entity, and its default value is `false`.
With the value `true`, the transformer gives `at [from: :next]` to each element at the
level of the slide that has no `at` option. The elements of the slide then show one after
the other, which is the behavior of Beamer.

```elixir
slide "steps" do
  auto_reveal true

  text_box do
    text_area do
      text "This box shows at step 1."
    end
  end

  text_box do
    text_area do
      text "This box shows at step 2."
    end
  end
end
```

The option changes an element at the level of the slide only. A nested element keeps
`nil`, and it shows at each step at which its parent shows. Therefore a `text_box` and its
`text_area` elements show as one unit.

An earlier version of this document said "each element without an `at` option", with no
level. That rule is not correct, and this document gives the evidence:

- A nested element under a parent with an explicit `at` takes the counter value 1, because
  an absolute specification does not move the counter. The child is then outside its
  parent, and the verifier reports an error for a deck that the author wrote correctly.
- Where each parent is also implicit, there is no error, but each container costs one step.
  A slide with one `text_box` and one `text_area` becomes a slide of two steps. The box
  then shows with no text in it at the first step.

An author who wants a reveal inside one `text_box` writes `at from: :next` on each
`text_area` of that box. The option and the explicit specification work together.

These rules apply with the option:

- An element at the level of the slide that has an `at` option keeps it. An absolute step
  number and the implicit sequence share one step space, and they can name the same step.
- A `pause` gives one step and reveals no element. It puts one step between two elements.
- An `on` entity reads the counter after the `at` option of the same element. Therefore
  `on :next` gives the step after the element shows.
- A nested element with an explicit `at` can name a step at which its parent does not show.
  The verifier reports this, and the message names the two elements.
- The maximum step number is the counter value of the last element, and the `steps` option
  of the slide can make it larger. A `steps` option that is smaller gives an error from the
  transformer.

## Per-step state

The `on` entity gives a state to an element for a set of steps. The `on` entity accepts
the same specification forms as the `at` option.

The `on` entity can change two things only:

- `state` names a state of the theme. The compiler maps the state `alert` to the custom
  property `--alert`, and it sets the property to `1` on those steps.
- `set` writes custom properties. The compiler maps the key `x` to the property `--x`.

```elixir
text_box do
  at from: 2
  on 3, state: :alert
  on [from: 4], set: [x: "400px", y: "100px"]

  text_area do
    text "..."
  end
end
```

Both options write a custom property. A `state` is a `set` of one property with the value
`1`. The option has its own name because a state is the usual case.

### Why the on entity does not apply a class

An earlier version of this design gave the `on` entity a `class` option. CSS cannot add a
class name to an element. A selector matches an element, and the rule then sets
properties. No CSS construction copies the declarations of a class into a different rule.
Therefore a generated rule cannot apply `.alert` at step 3. No browser at the floor of
this design has a construction for it. The floor is July 2024, and the section "Custom
properties" defines it. The decision "How does the `on` entity apply a state?" gives the
evidence.

### The state option

The compiler registers each state as a number:

```css
@property --alert {
  syntax: "<number>";
  inherits: false;
  initial-value: 0;
}

section[data-step="3"] [data-el="s2-e1"] {
  --alert: 1;
}
```

The theme owns the appearance of the state. It reads the number in the base rule of the
element. The renderer does not know the values of the theme:

```css
.text-box {
  outline-width: calc(var(--alert) * 2px);
  background: color-mix(in srgb, var(--alert-bg) calc(var(--alert) * 100%), transparent);
  transition: outline-width var(--dur), background var(--dur);
}
```

A registered number interpolates. Therefore the state fades in across the step, and the
theme does not write a transition for it. A value that CSS cannot multiply takes the
space toggle. The theme writes `--alert-on: ;` for the state, and `var(--alert-on) #fee`
for the value. This form does not interpolate, but it works in each browser with custom
properties.

The `set` option does not have this problem. A generated rule writes a custom property
directly, and the property has a value at the step that the rule selects.

### Why the set is small

The `on` entity cannot change the text, the child elements or the element type. A change
of this kind needs a second render of the element. A second render puts a second element
into the document. The transition then stops, because CSS cannot calculate intermediate
values between two different elements. The templates must also read the step index, and
this makes each template more complex.

The values stay open, but the mechanism stays closed. The DSL does not contain a list of
permitted keys for `set`. The theme owns the custom properties, and
`Expresso.Overlay.PropertyVerifier` gives a warning for a key that the theme does not use.
`assets/style.css` is the one theme of this project, and a deck from the DSL cannot
replace it.

### Content that changes

Use two sibling elements with separate specifications. This construction is equivalent to
`\only<1>{}` and `\only<2>{}` in Beamer.

```elixir
text_box do
  at 1

  text_area do
    text "before"
  end
end

text_box do
  at 2

  text_area do
    text "after"
  end
end
```

For a smooth change between the two elements, give the same `view_transition_name` to
both elements. Then put the change of the step index in `document.startViewTransition`.
The browser calculates the intermediate positions and sizes.

A view transition name must be unique between the elements that the browser renders.
Therefore the theme must hide the inactive element with `display: none`. The value
`opacity: 0` is not sufficient.

The two hide mechanisms are different, and one element cannot use both. An element that
fades must stay in the layout, and the theme must hide it with `opacity: 0`. An element
with a view transition name must leave the layout, and the theme must hide it with
`display: none`. The theme selects one mechanism for each element.

## Compilation

### The transformer

The transformer runs one time for each slide. It does these operations:

1. Give `at [from: :next]` to each element at the level of the slide that has no `at`
   option, when the slide has the `auto_reveal` option.
2. Read the elements of the slide in document order.
3. Increment the counter at each `pause` entity.
4. Replace each `+` with the current value of the counter, and increment the counter.
5. Expand each specification into an explicit list of step numbers.
6. Write the maximum step number into `slide.metadata`.
7. Remove each `pause` entity from the elements of the slide.

Step 1 runs before the counter walk, because the implicit specification takes a value from
the counter. It also fixes the maximum step number of the slide.

An open specification, such as `[from: 2]`, needs the maximum step number of the slide.
Therefore the transformer expands the open specifications after step 5 finds that number.

Step 7 is necessary because the renderer renders each element of a slide. A `pause`
entity holds no content, and it has no render function. The transformer removes the
entity after the entity gives its value to the counter.

Inside one element, the transformer reads the `at` option first, then each `on` entity in
document order, then each child element. Step 4 writes the list of step numbers into the
`steps` field of the element or of the `on` entity. An element without an `at` option
keeps `nil` in that field, and it shows at each step of its parent. Step 1 gives an `at`
option to an element at the level of the slide when the slide has the `auto_reveal`
option.

`Expresso.Overlay.Expand.slide/1` does the six operations on one `Expresso.Slide` struct,
and it is a pure function. `Expresso.Overlay.Transformer` calls it for each slide of the
DSL state. When the expansion gives an error, the transformer makes a
`Spark.Error.DslError` with the path of the slide.

### The verifier

The verifier gives an error for these conditions:

- A specification refers to a step number that is more than the maximum step number. The
  maximum is the `steps` option of the slide when the slide declares it.
- A specification contains a step number that is less than 1.
- An `on` entity has a specification that no step of the `at` option contains.
- A `pause` entity is inside a container element.
- A child element has a step that its parent does not contain.

The first condition needs a maximum step number that comes from a different source than
the specifications. If each slide calculates its own maximum from its specifications, an
absolute step number always raises the maximum, and the condition is unreachable. The
`steps` option of the slide is that source. See the decisions.

The transformer reports the first condition, because the expansion of an open
specification needs the maximum. `Expresso.Overlay.Check.slide/1` reports the other four
conditions on one expanded `Expresso.Slide` struct, and it is a pure function.
`Expresso.Overlay.Verifier` calls it for each slide. The DSL does not accept a `pause`
inside an element, and `Expresso.Overlay.new/1` does not accept a step below 1. Therefore
the check of those two conditions applies to a slide that a script builds.

Spark runs a verifier in an `@after_verify` callback of the module. Elixir reports an
error from that callback as a compile warning, and `mix compile --warnings-as-errors`
then fails. A test collects the error with `Spark.Test.dsl_errors/1`. An error from a
transformer is different. Spark raises it at compile time, and `assert_raise/2` catches it.

### The warnings of the properties

The verifier of the steps gives an error only. `Expresso.Overlay.PropertyVerifier` is a
second verifier, and it gives a warning for three conditions of a custom property:

- The `state` option, or a key of the `set` option, names a property that the theme does
  not use. The renderer writes the property, and no rule of the theme reads it. Therefore
  the value has no effect. This condition catches a key with a spelling mistake, and it
  catches a key that no theme reads.
- The `state` option names a property that the theme gives a value of a type that is not
  a number. The state `dur` is an example, because the theme gives `--dur` the value
  `300ms`. Each transition of the deck then takes no time.
- The `state` option names a property that the theme registers with a different syntax
  than a number. The state `x` is an example, because the theme registers `--x` as a
  length.

The compiler registers each state as a number with the initial value 0. A registration
replaces the registration of the theme, and it makes a value of a different type invalid.
The theme then loses the property. A value that is a number, such as `--alert: 0`, stays
valid, and it gets no warning.

`Expresso.Theme` reads `assets/style.css` at compile time, and it gives the names of the
theme. A name after two hyphens is a name that the theme uses. CSS holds a custom property
name in that one form, in an `@property` rule, in a declaration and in a `var()` function.
Therefore a property that the theme reads with a fallback, such as `var(--alert, 0)`, is a
name that the theme uses.

The test is the name, and not the `@property` rule. The theme uses `--dur` and `--ease`
and registers neither. A test on the `@property` rule alone gives a warning for a correct
deck.

`Expresso.Overlay.Properties.slide/1` makes the messages for one slide, and it is a pure
function. Each message holds the path of the slide, and Spark gives it the line of the
`on` entity.

A warning is not an error. The deck compiles, and the renderer writes the property. Elixir
reports the warning of a verifier as a compile warning. Therefore
`mix compile --warnings-as-errors` fails for a deck module in `lib/` with such a property.
Spark gives the same result for an error of a verifier, so a different severity gives no
more leniency. Only a transformer can stop a compile.

A false warning is rare, and it is not a fault. The renderer always writes
`assets/style.css`, and a deck from the DSL cannot select a template. The text of a text
area goes into the document as raw HTML, so a deck can write a `style` element in that
text. `Expresso.Theme` does not read the text of a deck, and a property of such a style
element then gets a warning. The deck still compiles, and a script that `mix expresso`
reads is correct. A deck module inside a project that runs
`mix compile --warnings-as-errors` fails, and that project must move the CSS into the
theme. A later version that gives a deck its own theme must also give the verifier the
names of that theme.

### The type

Use `{:custom, Expresso.Overlay, :new, []}` for the type of the `at` option. This
type accepts each form of the table, and it puts the form into the struct. Spark reports
an error for a different term, with the name of the entity and the option, and the
message lists the accepted forms.

Put the `at` option into one shared schema. Merge that schema into the schema of each
element entity.

## The CSS contract

The renderer writes these attributes:

- Each `section` element gets a `data-step` attribute. The value is the current step
  number.
- Each element with an overlay gets a `data-on` attribute. The value is a list of step
  numbers with a space between each number.
- Each `section` element gets a `data-max-step` attribute. The value is the maximum step
  number of the slide.
- Each element with an `on` entity gets a `data-el` attribute. The value is unique in the
  document.

The JavaScript code reads `data-max-step`. Without this attribute the code cannot know when
a slide reaches its last step, and it cannot move to the next slide.

A rule for step 3 looks like this:

```css
section[data-step="3"] [data-on~="3"] {
  opacity: 1;
}
```

The `~=` operator matches a complete word in a list. Therefore the value `13` does not
match the selector `[data-on~="3"]`. The renderer writes one rule for each step number to
the maximum step number of the deck.

The base rule must hide each element with an overlay. If the base rule does not hide the
element, each element is visible before its first step.

```css
[data-on] {
  opacity: 0;
}
```

The JavaScript code writes the `data-step` attribute. It does no other operation.

`Expresso.Overlay.Render` writes this contract. `identify/1` gives each element with an
`on` entity its `data-el` value, in the `el` field of the struct. `attributes/1` makes the
two attributes of one element, and the render function of the element puts them on its
root tag. `style/1` makes the generated style block. The base rule and the registration
of `--x` and `--y` are in `assets/style.css`, because the theme owns them. The base rule
also sets `visibility: hidden`, and the reveal rule sets `visibility: visible`, so a
hidden element is not in the accessibility tree.

### The identity of an element

The `data-on` attribute is not sufficient for the `on` entity. Two elements can show at
the same step and can hold different values. A selector on `data-on` alone applies both
values to both elements.

Therefore the renderer gives a `data-el` attribute to each element with an `on` entity.
The value is unique in the document. The renderer makes the value from the number of the
slide and the position of the element in the tree. Therefore the value is stable between
two renders of the same deck. A rule for one `on` entity uses this attribute:

```css
section[data-step="4"] [data-el="s2-e1"] {
  --x: 400px;
}
```

The renderer writes the rules for the `on` entities in document order. Two rules with the
same specificity can set the same property. CSS then applies the last rule, and document
order gives a stable result.

The renderer writes one rule for each `on` entity, with one selector for each step of the
entity. The rule sets `--<state>: 1` for the `state` option and `--<key>: <value>` for
each pair of the `set` option. The renderer escapes `<` in a value, so a value cannot
close the `style` element. The theme reads a state with a fallback, such as
`var(--alert, 0)`, because a deck without that state registers no property for it.

### Nested elements

An element can contain a different element, and both elements can have an `at` option. The
rule is that an element shows only when the element and each of its ancestors show.

The base rule gives this result without more work. A parent with `opacity: 0` hides its
children, and a parent with `display: none` removes them from the layout.

A child with a step that its parent does not contain is a defect. The verifier must give an
error for this condition.

### Custom properties

The browser holds an unregistered custom property as a text value. The browser cannot
calculate intermediate values for a text value, and the transition is abrupt. Therefore
the theme must register each custom property that it animates, with the `@property`
at-rule and a `syntax` descriptor. A property that the theme reads with no transition,
such as `--dur`, needs no registration. See "The warnings of the properties".

```css
@property --x {
  syntax: "<length>";
  inherits: false;
  initial-value: 0px;
}

section[data-step="4"] [data-el="s2-e1"] {
  --x: 400px;
}
```

The element reads the property in a base rule:

```css
.text-box {
  transform: translate(var(--x), var(--y));
  transition: transform var(--dur) var(--ease);
}
```

The `@property` at-rule became available in all major browsers in July 2024. Chrome 85,
Safari 16.4 and Firefox 128 support it. The floor of this design is that date, and not
the Chrome version. A construction that each engine gave before July 2024 is inside the
floor. `color-mix()` is an example: Chrome 111, Safari 16.2 and Firefox 113 support it.

### Duration and easing

The duration and the easing function are properties of the element or of the theme. The
`on` entity does not set them. The DSL gives the state. The theme gives the movement.

## Accessibility

The design needs these constructions:

- A `prefers-reduced-motion` block that sets each duration to zero. `assets/style.css`
  has this block, and it sets `--dur` to zero.
- A handout view for a screen reader and for a printer. The code does not have this view.

The handout view is not a simple override of the base rule. An override that shows each
element at the same time puts the elements of all the steps on one page. An element that
moves with `set` then holds one position only, and the page loses the sequence.

Therefore the handout view is a second render. The renderer writes one `section` with the
class `handout-page` for each step of each slide, and it puts `data-step` on that
`section`. The generated rules of the overlays then apply to the page with no addition,
because each rule starts with `section[data-step="<step>"]`. A page shows the state of
its own step only. This second render is safe, because the handout view needs no
transition.

The two views go into the same document. `assets/style.css` hides the handout view, and
two constructions show it:

- A `@media print` block. It hides the present view and shows the handout view. A printer
  gets one page for each step. The block gives the page a landscape orientation and a
  smaller base font size, and it gives each page the full height of the paper. Therefore
  a page keeps the proportions of a slide, with the header at the top and the footer at
  the bottom.
- The attribute `data-view` on the `body`. The presenter writes `handout` into it for the
  key `p`. A screen reader then reads each step of each slide.

A `data-el` value is unique in one view. The handout view holds the same value as the
present view. A rule keeps its correct element, because the `data-step` of the `section`
selects one page. A `section` of the handout view does not get the class
`slide` or an identifier, because `dom.ts` counts the class and reads the identifier.

The `aria-hidden` attribute is not part of this design. An attribute is not a CSS
property, and CSS cannot write it. Only JavaScript can write it, and the design gives
JavaScript one operation only. A theme that hides an element with `display: none` removes
the element from the accessibility tree, and the attribute is not necessary. A theme that
hides an element with `opacity: 0` keeps the element in the accessibility tree. Such a
theme must also set `visibility: hidden` after the transition.

## Changes to the current code

This section lists the work that this design made necessary. Each item is done, and the
section "Progress" gives the date of each. The handout view of the section
"Accessibility" is the one open item.

### The extension

`Expresso.Extension` lists `Expresso.Overlay.Transformer` in its `transformers` option
and `Expresso.Overlay.Verifier` in its `verifiers` option. It imports nothing, because a
specification is a term.

The extension contains a `pause` entity and an `on` entity. The `pause` entity has a
struct target, because Spark builds a struct for each entity.

The `slide` entity takes an optional name as its first argument. Therefore the examples in
this document, which write `slide "pipeline" do`, are correct.

### The slide metadata

The transformer writes the maximum step number into `slide.metadata.max_step`. The `slide`
entity has no `metadata` option, and the struct default is `nil`. The transformer accepts
`nil`, and it writes a map. `Expresso.parse/1` then puts the heading and the slide number
into that map.

### The elements

Each element struct has an `at` field, an `on` field, a `steps` field and an `el` field.
The `at` field and the `on` field hold the specifications. The transformer writes the
step numbers into the `steps` field, and `Expresso.Overlay.Render.identify/1` writes the
`data-el` value into the `el` field. An `on` entity has the first three fields.

`Expresso.Template.render_elements/1` reads the assigns of each element with
`module.get_assigns/1`. It then calls `module.render/1`. `get_assigns/1` puts the result
of `Expresso.Overlay.Render.attributes/1` under the key `overlay`, and `render/1` puts
the list on the root tag with `rest!: @overlay`. A custom element must do the same.

The attributes go on the root tag of the element. An element around the root tag breaks
the layout, because `.text-box` and `.text-area` are flex children.

A block element inside the root tag is different, and a text area needs one. The theme
makes `.text-area` a flex container. Therefore the render function puts the text in one
block element. `docs/architecture.md` gives the rule in the section "The elements".

### The renderer

`Expresso.Renderer` reads `assets/style.css` with `File.read!/1` at compile time. The step
rules depend on the deck, and the module attribute cannot hold them. Therefore the
renderer writes a third `style` element, after the fonts and the theme. It holds the
result of `Expresso.Overlay.Render.style/1`.

The renderer writes `data-step="1"` and `data-max-step` on each `section` element. A slide
from the imperative API has no `max_step` in its metadata, and its maximum is 1.

### The JavaScript code

The presenter is in `assets/src/`. `state.ts` holds the number of the current slide and
the number of the current step, and the first of each is 1. `dom.ts` shows and hides a
slide with the inline `style.display` property, and it writes the step number into the
`data-step` attribute of the current `section`. Each rule below has a test in
`assets/test/state.test.ts`.

The rules are:

- The limits hold the maximum step number of each slide. `dom.ts` reads each from the
  `data-max-step` attribute of the `section`.
- `j` moves to the next step first. It moves to the first step of the next slide only
  after the last step.
- `k` moves to the previous step first. At the first step, it moves to the last step of
  the previous slide.
- `p` changes between the present view and the handout view. `dom.ts` writes the view
  into the `data-view` attribute of the `body`.

### The imperative API

`Expresso.Deck.add_slide/4` and `Expresso.Element.TextBox.new/1` make a deck without the
DSL. `examples/demo.exs` uses this API. These functions have no parameter for an overlay,
and no transformer runs for them. The design must say whether this API keeps parity with
the DSL, or whether overlays need the DSL.

## The test plan

The code has each test below. The tests of `Expresso.Overlay` and of its four modules
are in `test/expresso/overlay_*_test.exs`, and the tests of the presenter are in
`assets/test/state.test.ts`.

- Tests for `Expresso.Overlay`. Each row of the table in "The specification" is one test
  of `new/1`, and a different term gives an error. `resolve_next/2`, `max_step/1` and
  `steps/2` get a test for each rule of the counter and of an open range.
- Transformer tests. A slide with a `pause` and a `+` gives the correct step number for each
  element. An open range expands to the maximum step number of the slide. The transformer
  removes each `pause` entity.
- Verifier tests. Each condition in the section "The verifier" gives an error.
- Render tests. Floki is a dependency of this project. A test parses the HTML and asserts
  the value of `data-step`, `data-max-step`, `data-on` and `data-el`.
- A CSS test. A test asserts that the generated style block contains one rule for each step
  number of the deck.

## Progress

- Slice 1, done on 2026-09-14: `Expresso.Overlay`, with `new/1`, `resolve_next/2`,
  `max_step/1` and `steps/2`, and its tests. No entity accepts the `at` option yet.
- Slice 2, done on 2026-09-14: the `at` option on each element, and the `on`, `pause`
  and `steps` entities. Each is in the DSL, and the structs hold the specifications. The
  renderer skips a `pause` until the transformer removes it, and it ignores `at` and `on`.
- Slice 3, done on 2026-09-14: `Expresso.Overlay.Expand` and `Expresso.Overlay.Check`,
  which are pure functions on a slide, and `Expresso.Overlay.Transformer` and
  `Expresso.Overlay.Verifier`, which run them for each deck module. Each element holds
  its step numbers in the `steps` field, and the slide metadata holds `max_step`. The
  renderer does not read either field yet.
- Slice 4, done on 2026-09-14: `Expresso.Overlay.Render`, the `el` field, the attributes
  on each `section` and on each element, the generated style block, and the base rules in
  `assets/style.css`. The presenter does not write `data-step` yet, so a browser shows
  step 1 of each slide.
- Slice 5, done on 2026-09-14: the step number in `assets/src/state.ts` and `dom.ts`,
  with a test for each rule, and a slide with overlays in `examples/dsl_deck.exs`.
- Slice 6, done on 2026-09-14: the handout view. The renderer writes one page for each
  step of each slide. A `@media print` block selects that view, and the key `p` changes
  between the two views.
- The property warnings, done on 2026-09-17. `Expresso.Theme` reads the names of the
  theme, `Expresso.Overlay.Properties` makes the messages for one slide, and
  `Expresso.Overlay.PropertyVerifier` gives them to the compiler.
- The `auto_reveal` option, done on 2026-09-17. `Expresso.Overlay.Expand.slide/1` gives the
  implicit specification to each element at the level of the slide. The rule of this
  document changed at the same time, from each element to each element of the slide.

## The decisions

The maintainer decided each item below on 2026-09-13. The decisions are settled. A later
change needs a new decision, and this document then records it.

### Does `pause` operate on the elements after it, or on one level of the tree? (decided)

Each slide has one counter, and the transformer reads the tree in document order, depth
first. A `pause` increments the counter for each element after it, at each level of the
tree. An author reads the file from the top to the bottom, and a `+` gives the next number
in that order. This is the behavior of `\pause` in Beamer. A counter for each level of the
tree can give the same step number to two elements in two subtrees. A slide has one
sequence of steps.

The first version permits a `pause` at the slide level only, and the verifier gives an
error for a `pause` inside a container element. The reason is the rule for nested
elements. A container at `[from: 5]` with a `pause` at counter 2 gives its later children
step 3. The verifier then rejects the children, because a child cannot show on a step
that its parent does not contain. The author wrote nothing wrong and gets an error. A
later version can permit a `pause` in a container. Such a version needs a rule, for
example "the first step of a container seeds the counter of its subtree". That rule needs
its own design.

### Can an `on` entity contain a specification that is outside the `at` option? (decided)

No. The verifier gives an error. A step that does not show the element cannot show a state
of the element. Such an `on` entity makes CSS rules that no step applies, and in practice
it is a slip after a change to the step numbers. The verifier already reads each step
range, and this condition is one more in the same list.

One use exists for a state outside the `at` option. An element at `2..4` with
`on 5, state: :slide_out` could leave in a different way from the default of the
theme. This use is rare, and a permissive rule lets the slip pass in silence. If a later
version needs this, add an explicit `leave` option. Do not loosen this rule.

### How does the `on` entity apply a state? (decided)

The maintainer decided this on 2026-09-13. The `on` entity does not apply a class. It
writes a custom property, `--<state>: 1`, and the theme owns the appearance. The section
"The state option" gives the contract. The JavaScript code writes `data-step` only.

The evidence is in `docs/research/overlay-class-report.md`, which answers the prompt in
`docs/research/overlay-class-prompt.md`. The findings that gave the decision:

- No construction of CSS applies a named class to an element on a condition, at the floor
  of this design. `@mixin` and `@apply` are in no browser, and they inline declarations
  that the author of the deck writes, not the declarations of the theme.
- `if()` with `style()` applies a value on the condition of a custom property of the
  same element. Chrome 137 has it. Firefox and Safari do not, as of September 2026. It
  is not usable at the floor.
- `@container style()` applies to descendants only, and it needs Safari 18 and Firefox
  151. It raises the floor by more than one year.
- reveal.js, impress.js, Slidev, Marp and Spectacle apply a state with a class toggle in
  JavaScript. None does it in CSS. The limit is a limit of CSS, not of this design.

The report ranks a custom-property contract first and a class toggle in the JavaScript
code second. Its example of the contract puts the colors of the theme into the generated
rule, and the design forbids this. The contract above corrects it. The generated rule
writes a number, and the theme maps the number to values.

The JavaScript code does not toggle a class. A class toggle is a known alternative for a
theme that must apply a class that it cannot express as custom properties. The report
gives its cost. The change to `data-step` and the change to the class list must be in one
synchronous function. The initial state must be in the HTML, or the page shows a flash
before the script runs.

### Is the specification a term or a text format? (decided)

The maintainer decided this on 2026-09-14. A specification is an Elixir term, and not a
text format. An earlier version of this design gave a `~o` sigil with a grammar in the
style of Beamer, such as `~o"2,5-"`. The extension imported the sigil.

Each form of that grammar has a term. `2..4` is a closed range, `[from: 2]` is an open
range, `:next` is the counter, and a list is a union. Only two forms have no literal, the
open range and the counter, and a keyword and an atom give them.

A term removes the parser, the sigil macro and the `imports` option of the extension.
Spark validates the option at compile time, and its error names the entity and the
option. A term also works in the imperative API, where no import exists. The cost is
length. `[2, from: 5]` is longer than `"2,5-"`, and an author from Beamer learns a new
form.

### Does the deck declare the maximum step number? (decided)

Each slide calculates its own maximum step number. The maximum step number of the deck is
the largest maximum step number of its slides. The renderer uses the deck maximum for the
number of generated CSS rules. This is the behavior of Beamer, which counts the
overlays of each frame from its content.

A maximum for the deck would make `[from: 2]` run to the largest step of the deck. Each
slide
with fewer steps then gets empty steps, and the presenter gets a key press that does
nothing on each such slide. The presenter also needs the maximum of each slide, and
`data-max-step` on each `section` gives it. A number for the deck adds nothing that the
presenter reads.

The `slide` entity gets an optional `steps` option. It declares the maximum step number of
one slide, and it has two uses. An author can add an empty step at the end of a slide. And
it makes the first condition of the verifier possible, because a specification above a
declared maximum is an error. Without a declared maximum, a large step number raises the
maximum, and nothing reports it.
