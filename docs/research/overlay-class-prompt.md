# Research prompt: the state option of the overlay design

This file holds a prompt for a deep-research tool. The prompt asks whether pure CSS can
apply a named set of declarations to an element on one step only. `docs/overlays.md`
gives the problem in the section "Why the on entity does not apply a class". The answer
is in `overlay-class-report.md`, and the decision "How does the `on` entity apply a
state?" in `docs/overlays.md` came from it.

The tool got the text below on 2026-09-13.

---

## Research request

Tell me whether pure CSS can apply a named set of declarations to an element on the
condition of a step index. The document is one HTML file that a renderer writes one time.

### Context

I make a generator of slide decks. Elixir writes one HTML file that stands alone. An
overlay is a step inside one slide, in the style of Beamer. The renderer runs one time,
and it writes each state of a slide into the document. A small script holds the number of
the current step only, and it writes the number to `section[data-step="N"]`. CSS then
selects the state for that step, and it animates the change between two steps with
`transition`. There is no second render, and there is no timeline.

Each overlay element has `data-on="2 3 4"`, which lists the steps that show it, and a
unique `data-el="s2-e1"`. The generated style sheet holds rules of this form:

```css
section[data-step="3"] [data-on~="3"] { opacity: 1; }
section[data-step="4"] [data-el="s2-e1"] { --x: 400px; }
```

The `@property` at-rule registers each custom property, so a property interpolates. The
DSL gives an author two forms of per-step state:

- `on ~o"4-", set: [x: "400px", dim: 0.3]` compiles to custom-property assignments.
  This form works.
- `on ~o"3", class: "alert"` must apply the rules of `.alert` from the theme on step 3
  only. This form is the problem.

### The problem

A CSS rule selects an element and sets properties. I know no construction that lets a
generated rule say "on step 3, apply the declarations of `.alert` to this element". The
theme owns `.alert`. The generator does not know its declarations, and it must not read
the theme. The old `@apply` rule is gone. I see three options:

1. Remove `class` from the DSL. Per-step state is custom properties only, and a theme
   expresses a state with `var()`. This is pure CSS, but a state such as "make this
   prominent on step 3" is more difficult to write.
2. Let the presenter script toggle class names. The renderer writes `data-class="3:alert
   5:dim"`, and the script adds and removes the classes at each step. This is
   approximately ten lines of JavaScript. The transitions continue, because the element
   stays the same element. This breaks the rule that the script writes one attribute only.
3. Use a CSS style query. The generated rule sets `--alert: 1` on the step, and the theme
   writes `@container style(--alert: 1) { … }`. A style query applies to the descendants
   of the container and not to the container, and the browser support is newer than the
   floor below.

### The browser floor

The design commits to the browsers that support `@property`: Chrome 85, Safari 16.4 and
Firefox 128, which is the July 2024 baseline. Name each construction that needs a newer
engine, with the version and the date.

### The questions

Give a citation for each answer. Prefer the specifications, the release notes of the
browsers, caniuse, the browser compatibility data of MDN, and the results of the web
platform tests.

1. Does pure CSS apply a named group of declarations to the same element on a condition?
   Include each mechanism in a browser, and each mechanism in a working draft. For each
   mechanism below, give the status in each engine and the maturity of the specification:
   - The `if()` function with a `style()` condition, from CSS Values 5. Can a declaration
     on an element branch on a custom property of the same element? Which engines have
     it, and since when?
   - `@container style()` queries. Make sure of the limit to descendants. Can an element
     be its own container for its own style?
   - The CSS Mixins and Functions module, with `@mixin`, `@apply` and `@function`. What
     is in a browser, what is in a draft, and will `@mixin` arrive?
   - `attr()` with a type, from CSS Values 5. Can a data attribute give a property its
     value, and does that help?
   - `:state()`, custom element states, `@scope`, `:has()` and `:where()`. Is there a
     pattern that lets the theme write a usual `.alert { … }` rule? The generator must
     gate the rule for each step, and it must not know the content of the rule.
   - Cascade layers and `revert-layer`. Can an attribute gate one layer?
2. Suppose that `class: "alert"` compiles to an attribute or a custom property that the
   step gates, and the theme reads it. What is the contract that surprises a theme author
   the least? What does it cost the author, in comparison with a plain class name? Give
   the CSS before and after.
3. How do reveal.js, impress.js, Slidev, Marp, Spectacle and the tools that convert
   Beamer to HTML apply per-fragment state? Which of them use pure CSS, and which toggle a
   class with JavaScript, and why? Report each known problem with transitions,
   `prefers-reduced-motion`, view transitions and print modes.
4. Give the cost of option 2 in full. Include these points:
   - The interaction with CSS transitions when a class changes in the same frame as
     `data-step`.
   - The risk of a flash at the first load.
   - The behavior when the two changes are not atomic.
   - The need for `requestAnimationFrame`.
   - The effect on accessibility.
   - Whether the option breaks the model "one render, CSS computes the intermediate
     states".
5. Rank the options for the browser floor above. If a route in pure CSS needs a newer
   engine, say how much newer. Say whether a fallback is possible, with `@supports` or
   with JavaScript only where `if()` and style queries are absent.

### The format of the output

Give a structured report with these parts:

- A summary verdict.
- A table of mechanisms by engine, with the version, the date and the specification
  status.
- The CSS and the HTML for each usable pattern.
- The comparison of the tools.
- The cost of the JavaScript option.
- A recommendation with the trade-offs.

Flag each uncertain point and each version-dependent point. Prefer primary sources to
blog posts.
