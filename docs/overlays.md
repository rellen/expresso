# Overlay specifications

This document gives a design for overlays. The code does not contain this design yet. The
section "Changes to the current code" lists the work that this design makes necessary.

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

### The sigil

The `~o` sigil accepts a specification in the style of Beamer. The extension imports the
sigil with the `imports` option of `Spark.Dsl.Extension`.

| Specification | Meaning |
| --- | --- |
| `~o"3"` | Step 3 only. |
| `~o"2-4"` | Step 2 to step 4. |
| `~o"2-"` | Step 2 and each step after step 2. |
| `~o"-3"` | Each step to step 3. |
| `~o"2,5-"` | Step 2, and step 5 and each step after step 5. |
| `~o"+"` | The current value of the slide counter. |
| `~o"+-"` | The current value of the slide counter, and each step after it. |

The sigil cannot give a list of step numbers. Two of the forms need data that only the
transformer holds. A `+` needs the counter of the slide. An open range needs the maximum
step number of the slide. Therefore the sigil returns an `Expresso.Overlay` struct. The
struct holds the parts of the specification. The transformer expands the struct later.

### Plain terms

The `at` option also accepts plain Elixir terms. The sigil is not necessary for a simple
specification.

| Term | Equivalent sigil |
| --- | --- |
| `3` | `~o"3"` |
| `2..4` | `~o"2-4"` |
| `[2, 5]` | `~o"2,5"` |

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
`data-on` attribute for such an element.

Therefore a `pause` entity alone reveals no element. A `pause` changes the counter only. An
element must contain a `+` to read the new value of the counter. This behavior is different
from `\pause` in Beamer, which reveals the content after it.

The proposal is to keep this explicit rule. An author who wants the behavior of Beamer
writes `at: ~o"+-"` on each element. A later version can add an `auto_reveal` option to the
`slide` entity. This option gives an implicit `at: ~o"+-"` to each element without an `at`
option.

```elixir
slide "pipeline" do
  text_box at: ~o"+-" do
    on ~o"+", class: "alert"

    text_area do
      text "This box appears at one step. It becomes prominent at the next step."
    end
  end

  pause

  text_box at: 3 do
    text_area do
      text "This box uses an absolute step number."
    end
  end
end
```

## Per-step state

The `on` entity gives a state to an element for a set of steps. The `on` entity accepts
the same specification forms as the `at` option.

The `on` entity can change two things only:

- `class` adds one or more class names.
- `set` writes custom properties. The compiler maps the key `x` to the property `--x`.

```elixir
text_box at: ~o"2-" do
  on ~o"3", class: "alert"
  on ~o"4-", set: [x: "400px", dim: 0.3]

  text_area do
    text "..."
  end
end
```

### The limit of the class option

CSS cannot add a class name to an element. A selector matches an element, and the rule
then sets properties. No CSS construction copies the declarations of a class into a
different rule. Therefore the generated CSS cannot apply `class: "alert"` at step 3.

This design does not solve this problem. The open decisions give three options and a
proposal.

The `set` option does not have this problem. A generated rule writes a custom property
directly, and the property has a value at the step that the rule selects.

### Why the set is small

The `on` entity cannot change the text, the child elements or the element type. A change
of this kind needs a second render of the element. A second render puts a second element
into the document. The transition then stops, because CSS cannot calculate intermediate
values between two different elements. The templates must also read the step index, and
this makes each template more complex.

The values stay open, but the mechanism stays closed. The DSL does not contain a list of
permitted keys for `set`. The theme owns the custom properties. A verifier can give a
warning for a key that no theme registers.

### Content that changes

Use two sibling elements with separate specifications. This construction is equivalent to
`\only<1>{}` and `\only<2>{}` in Beamer.

```elixir
text_box at: ~o"1" do
  text_area do
    text "before"
  end
end

text_box at: ~o"2" do
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

1. Read the elements of the slide in document order.
2. Increment the counter at each `pause` entity.
3. Replace each `+` with the current value of the counter, and increment the counter.
4. Expand each specification into an explicit list of step numbers.
5. Write the maximum step number into `slide.metadata`.
6. Remove each `pause` entity from the elements of the slide.

An open specification, such as `~o"2-"`, needs the maximum step number of the slide.
Therefore the transformer expands the open specifications after step 4 finds that number.

Step 6 is necessary because the renderer renders each element of a slide. A `pause`
entity holds no content, and it has no render function. The transformer removes the
entity after the entity gives its value to the counter.

### The verifier

The verifier gives an error for these conditions:

- A specification refers to a step number that is more than the maximum step number.
- A specification contains a step number that is less than 1.
- An `on` entity has a specification that no step of the `at` option contains.

The first condition needs a maximum step number that comes from a different source than
the specifications. If each slide calculates its own maximum from its specifications, an
absolute step number always raises the maximum, and the condition is unreachable. See the
open decisions for the proposal that makes this condition possible.

### The type

Use `{:custom, Expresso.Overlay, :validate, []}` for the type of the `at` option. This
type accepts the sigil and the plain terms. It also gives control of the error message.

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

The JavaScript code writes the `data-step` attribute. It does no other operation, except
the operation that the open decision about the class can add.

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
the theme must register each custom property with the `@property` at-rule and a `syntax`
descriptor.

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
Safari 16.4 and Firefox 128 support it.

### Duration and easing

The duration and the easing function are properties of the element or of the theme. The
`on` entity does not set them. The DSL gives the state. The theme gives the movement.

## Accessibility

The renderer must write these constructions:

- A `prefers-reduced-motion` block that sets each duration to zero.
- A handout view for a screen reader and for a printer.

The handout view is not a simple override of the base rule. An override that shows each
element at the same time puts the elements of all the steps on one page. An element that
moves with `set` then holds one position only, and the page loses the sequence.

The proposal is that the handout view is a second render. The renderer writes one page for
each step of each slide. This second render is safe, because the handout view needs no
transition. The first render and the handout render go into the same document, and a
`@media print` block selects one of them.

A smaller first version writes the last step of each slide only. This version keeps one
render and gives a correct page for most slides.

The `aria-hidden` attribute is not part of this design. An attribute is not a CSS
property, and CSS cannot write it. Only JavaScript can write it, and the design gives
JavaScript one operation only. A theme that hides an element with `display: none` removes
the element from the accessibility tree, and the attribute is not necessary. A theme that
hides an element with `opacity: 0` keeps the element in the accessibility tree. Such a
theme must also set `visibility: hidden` after the transition.

## Changes to the current code

The current code does not contain the constructions that this design needs. This section
lists the work.

### The extension

`Expresso.Extension` has an empty `imports` option and an empty `transformers` option. The
extension must import the sigil module. It must also list the overlay transformer and the
overlay verifier.

The extension must contain a `pause` entity and an `on` entity. The `pause` entity needs a
struct target, because Spark builds a struct for each entity.

The `slide` entity has no `args` option at this time. Therefore the examples in this
document, which write `slide "pipeline" do`, need `args: [:name]` on the entity.

### The slide metadata

The transformer writes the maximum step number into `slide.metadata`. A slide that comes
from the DSL holds `nil` in this field, because the `slide` entity has no `metadata`
option and the struct default is `nil`. The transformer must put a map into the field
before it writes the maximum step number.

This field has a second defect at this time. `Expresso.Builtins.Templates.Slides.Default`
reads `@metadata.heading`, and a DSL slide gives an error. A correction to the metadata of
the DSL slide is a prerequisite for the transformer.

### The elements

`Expresso.Template.render_elements/1` reads the assigns of each element with
`module.get_assigns/1`. It then calls `module.render/1`. The overlay data must pass through
both functions.

The proposal is:

- Add an `overlay` field and an `on` field to each element struct.
- Put both fields into the map that `get_assigns/1` returns.
- Add a shared function, such as `Expresso.Overlay.attributes/1`. This function makes the
  `data-on` attribute and the `data-el` attribute from the assigns.
- Call this function in the render function of each element.

The attributes must go on the root tag of the element. A wrapper element breaks the
layout, because `.text-box` and `.text-area` are flex children.

### The renderer

`Expresso.Renderer` reads `assets/style.css` with `File.read!/1` at compile time. The step
rules depend on the deck, and the module attribute cannot hold them. The renderer must
write a second `style` element. This element holds the generated rules for each step
number to the maximum step number of the deck.

The renderer must also write `data-step="1"` on each `section` element.

### The JavaScript code

`assets/main.js` holds one slide index. It shows and hides a slide with the inline
`style.display` property. The code must also hold a step index for each slide.

The necessary changes are:

- Hold the current step index and the maximum step index of the current slide.
- Move to the next step first. Move to the next slide only after the last step.
- Move to the previous slide at the first step, and show the last step of that slide.
- Read the maximum step index from the `data-max-step` attribute of the current `section`.
- Write the step index into the `data-step` attribute of the current `section`.
- Apply the class names of the current step, if the open decision about the class takes
  option 2.
- Show all the steps of all the slides for the print key.

### The imperative API

`Expresso.Deck.add_slide/4` and `Expresso.Element.TextBox.new/1` make a deck without the
DSL. `examples/demo.exs` uses this API. These functions have no parameter for an overlay,
and no transformer runs for them. The design must say whether this API keeps parity with
the DSL, or whether overlays need the DSL.

## The test plan

The repository contains one test file with a doctest only. This design needs these tests:

- Parser tests for `Expresso.Overlay.validate/1`. Each row of the two tables in the section
  "Syntax" is one test. A malformed specification gives an error.
- Transformer tests. A slide with a `pause` and a `+` gives the correct step number for each
  element. An open range expands to the maximum step number of the slide. The transformer
  removes each `pause` entity.
- Verifier tests. Each condition in the section "The verifier" gives an error.
- Render tests. Floki is a dependency of this project. A test parses the HTML and asserts
  the value of `data-step`, `data-max-step`, `data-on` and `data-el`.
- A CSS test. A test asserts that the generated style block contains one rule for each step
  number of the deck.

## The open decisions

### Does `pause` operate on the elements after it, or on one level of the tree?

The proposal is one counter for each slide, and one document order. The transformer reads
the tree depth first. A `pause` increments the counter for each element after it, at each
level of the tree.

The first version must permit a `pause` at the slide level only. This limit keeps the
order clear while the tree is small. A later version can permit a `pause` in a container
element.

### Can an `on` entity contain a specification that is outside the `at` option?

The proposal is an error. A step that does not show the element cannot show a state of the
element. Such an `on` entity makes CSS rules that no step applies. An error tells the
author about the defect at compile time.

### How does the `on` entity apply a class?

CSS cannot add a class name. The section "The limit of the class option" gives the problem.
There are three options:

1. Remove the `class` option. The `on` entity then holds `set` only. A theme expresses each
   state as a custom property. This option keeps the CSS contract pure, but it makes a
   simple state, such as a highlight, more difficult to write.
2. Let the JavaScript code apply the class names. The renderer writes a `data-class`
   attribute that maps a step number to a class name. The code then adds and removes the
   class names at each change of the step. This option adds a second operation to the
   JavaScript code.
3. Use a CSS style query. The `on` entity writes a custom property, and the theme selects
   the state with `@container style(--alert: 1)`. This option keeps the CSS contract pure,
   but the browser support for a style query is more recent than the support for the
   `@property` at-rule.

The proposal is option 2. A class name is the construction that a theme author expects, and
the code is approximately ten lines. A class change on one element does not stop a
transition, because the element stays the same element. The rule "JavaScript writes the step
index only" becomes "JavaScript writes the step state only".

### Does the deck declare a maximum step number, or does each slide calculate its own?

The proposal is that each slide calculates its own maximum step number. The maximum step
number of the deck is the largest maximum step number of its slides. The renderer uses the
deck maximum for the number of generated CSS rules.

Add an optional `steps` option to the `slide` entity. This option declares a maximum step
number for one slide. The option lets an author add an empty step at the end of a slide.
The option also makes the first condition of the verifier possible, because a declared
maximum can be less than a step number in a specification.
