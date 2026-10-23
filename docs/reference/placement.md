# The places of the elements

This page gives the elements that each element can hold. The compiler gives an error for an
element in a place that this page does not give.

## The rules

| Element | Holds |
| --- | --- |
| `slide` | `text_box`, `columns`, `callout`, `toc`, `footnote`, `shape`, `pause` and each element of a text box |
| `text_box` | `columns`, `callout`, `toc` and each element of a text box |
| `columns` | `column` |
| `column` | `callout`, `toc` and each element of a text box |
| `callout` | each element of a text box |
| `list` | `item` |
| `item` | `list` |
| `table` | `row` |
| `diagram` | `part` |
| `chart` | `series`, `point`, `flow` and `node`, and `frame` in `timeline` |
| `frame` | `series` and `flow` |
| `tree` | one `node` |
| `node` in a `tree` | `node` |

The elements of a text box are `text_area`, `image`, `list`, `table`, `quotation`, `spacer`,
`code`, `math`, `diagram`, `embed`, `video`, `audio`, `qr_code`, `chart`, `tree`, `stat` and
`icon`.
Each other element holds no elements. Each element holds its `on` entities.

These rules give some facts:

- A `footnote`, a `shape` and a `pause` go at the level of the slide only.
- A callout holds no callout and no `columns`.
- A column holds no `columns` and no `text_box`. A text box holds no `text_box`.
- A list nests to each depth: an item holds a list, and that list holds items.
- A `node` entity goes in a chart or in a tree. A frame holds no `node`.
- A tree nests to each depth: a node of a tree holds nodes.

## The error

The error gives the slide, the element, its parent and the elements that the parent holds:

```text
** (Spark.Error.DslError) [MyDeck]
deck -> slide -> s :
  a columns is inside a callout, and a callout holds text_area, image, list, table, ...
```

The error stops the compile.

A `pause` inside an element gives the error of the overlays. See
[The overlay options](overlay-options.md).

`Expresso.Builder.deck/2` raises the same `Spark.Error.DslError` when it makes the deck.
A deck struct that a script makes without `Expresso.Builder` does not go through the
compiler, and it gets no error.

## A limit of the check

An element in the block of an element that holds no elements gets no error, and the deck
does not show it. An example is a `text_area` in the block of a `code` element. Spark keeps
only the children of the keys that an element declares, and the check reads the deck that
Spark makes.

## Why the DSL needs a check

In a nested block, the macros of the outer blocks stay in scope. For example, the `columns`
macro of the slide is in scope in the block of a callout. Therefore the DSL compiles an
element in a wrong place, and `Expresso.PlacementTransformer` then refuses it. The check is a
transformer, so its error stops the compile. The error of a `pause` inside an element also
stops the compile. `docs/architecture.md` tells the reason in "The definitions of the
elements".
