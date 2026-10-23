# Waterfall charts

This document gives the design for the chart kind `:waterfall`, and the record of its
progress. A waterfall chart shows how a start value changes through a list of increases and
decreases, with total columns between them. The document records ten decisions, and each is
settled. Its section "The progress" tells the state of each pull request of the stack. Issue
#411 holds the same plan.

## The problem

A talk often explains how one number becomes another number: the cash at the start of a year,
the income and the costs, and the cash at the end. A waterfall chart shows this. Each change
is a floating column that starts where the column before it ends, and a total column shows
the running total.

A bar chart of Expresso cannot draw a floating column or a running total. The author must
calculate each base by hand and hide a series under it, and then the totals cannot grow with
the changes.

## The constraints

- The output stays one HTML file. The compiler calculates each place, and the presenter
  script calculates no layout.
- A waterfall chart obeys the overlay contract: `at`, `on`, `effect`, `reveal`, `dim`,
  `class` and `morph`. See `docs/overlays.md`.
- The handout view and paper show the last step, as for the other kinds.
- A screen reader gets each column with its change and its running total.
- The theme gives each color, so each theme and its dark variant work.

## An example

```elixir
chart :waterfall do
  title "Cash in 2025"
  categories ["Start", "Sales", "Services", "Mid year", "Grants", "Interest", "Costs", "End"]
  series "Cash", [50, 40, 30, :total, 10, 20, -50, {:total, 100}]
  reveal true
end
```

The first value is the start, and it draws as a total. Each other number is a change. The
atom `:total` marks a total column, and the render calculates its value from the changes
before it. `{:total, 100}` also gives the value that the author expects, and the compiler
refuses the chart when the sum is different.

With `reveal true`, the chart takes these steps:

| Step | Shows | Mid year | End |
| --- | --- | --- | --- |
| 1 | Start (50) and each total | 50 | 50 |
| 2 | Sales (+40) | grows to 90 | grows to 90 |
| 3 | Services (+30) | grows to 120 | grows to 120 |
| 4 | Grants (+10) | 120 | grows to 130 |
| 5 | Interest (+20) | 120 | grows to 150 |
| 6 | Costs (-50) | 120 | shrinks to 100 |

## The decisions

| Number | Question | Decision |
| --- | --- | --- |
| 1 | The mark of a total | The atom `:total` in the series, and the cell `total` in a CSV file. The series holds the whole story in its order. |
| 2 | The spans over the chart | Part of this work, with the option `spans true`. |
| 3 | A total column before its changes | An option for both stories: `totals :grow`, the default, and `totals :complete`. |
| 4 | The direction | `direction :vertical`, the default, draws columns. `direction :horizontal` draws bars from left to right. |
| 5 | Frames | A waterfall takes `frame` entities, as a bar chart does. With `reveal true`, the changes of the first frame show one step each, and each later frame then takes one step and moves the whole chart. |
| 6 | The base of the value axis | The axis holds zero by default. The option `value_range` cuts the axis, such as `value_range {900, 1050}`. |
| 7 | A cut axis | A break mark, a small zigzag, goes on the value axis and at the base of each total column. |
| 8 | The value that the author expects | `{:total, 120}` in the series, and the cell `total 120` in a CSV file. The compiler refuses a total that does not agree with the sum. |
| 9 | The agreement of a total | The compiler rounds the sum to the most decimals of the numbers of the series, so the sum of `0.1` and `0.2` agrees with `0.3`, and `119.5` does not agree with `120`. |
| 10 | The code | A new family `:waterfall` in `Expresso.Element.Chart.Kinds`, and a new module `Expresso.Element.Chart.Waterfall`. `Expresso.Element.Chart` sends each function of a waterfall to that module, so the code of the other kinds does not change. |

## The design

- **The data.** `Expresso.Element.Chart.Waterfall` checks the one series and calculates the
  base, the end and the running total of each column. A change starts at the running total
  before it. A total starts at zero, or at the low end of `value_range`.
- **The colors.** A total takes `--waterfall-total`, an increase `--waterfall-up` and a
  decrease `--waterfall-down`. The style sheet sets them to `--accent`, `--success` and
  `--danger`, so a deck can change them with its own rule.
- **The labels.** A total shows its value over its column. A change shows its signed value,
  such as `+40` or `-50`, in its column, and its running total over it in `--muted`.
  `values false` removes the labels.
- **The connectors.** A dashed line goes from the end of each column to the start of the next
  column, at the running total. A connector shows with the column at its right.
- **The states.** Each mark has its place in the channels of
  `Expresso.Element.Chart.Motion`. One state is one set of values of the channels. A chart
  without steps has one state. With `reveal true`, each change adds one state at its step,
  and each later frame adds one state. `Expresso.Element.Chart.Motion.rules/3` writes the
  rules of each state after the first, so one code path moves the totals at a step of a
  change and at a step of a frame.
- **The count.** The value of a total that changes between states is a `chart-count` number,
  so the presenter script counts it as the total grows. The script needs no change.
- **The steps.** With `reveal true`, the check puts the start and each total of
  `totals :grow` into the first group, and each change into its own group. Each group is a
  child of the chart. With `totals :complete`, a later total goes into the group of the
  change before it, at its final value. `dim true` dims each change when a later change
  shows. `effect :grow` grows each change from its base.
- **The highlight.** Each column has a `data-keys` attribute with the key of its category,
  so a group of the `highlight` option names categories and the rules of the highlight of a
  chart dim the other columns.
- **The spans.** With `spans true`, an arrow goes over the columns from one total to the next
  total, with the sum of the changes between them, such as `+70`. A span shows with the total
  at its end, and with `totals :grow` its value counts with that total.
- **The direction.** With `direction :horizontal`, the categories go down the left side and
  the value axis goes along the bottom. The labels, the connectors and the spans turn with
  the chart.
- **The table.** The table for a screen reader has one row for each column, with its
  category, its change and its running total.
- `docs/reference/chart-element.md` gives the options. A how-to guide gives the tasks, with
  example decks and their GIFs.

## The stack

1. This document.
2. The kind `:waterfall`, `:total` and `{:total, value}`, the columns, the colors, the
   connectors, the labels, `value_range` and the break mark, the table, and the errors.
3. The CSV file.
4. The steps: `reveal`, `totals :grow` and `totals :complete`, the count, the effect `:grow`
   and `dim`.
5. The highlight.
6. The spans.
7. The direction `:horizontal`.
8. The frames.
9. The guide, the example decks and their GIFs.

## The progress

| Pull request | State |
| --- | --- |
| 1. This document | Done |
| 2. The columns | Done. A column is a `rect` of one unit, as a box of a treemap, so its channels move each of its ends. The text of a change goes into its column when the column is 22 units high or more, else over the column. The other kinds refuse `value_range` and `:total`. |
| 3. The CSV file | Done. The reader of `Expresso.Element.Chart.Csv` takes the option `cell`, a function that reads one cell, and a waterfall chart gives a function that also reads `total` and `total 120`. The error of a bad cell names the values that a cell can hold. |
| 4. The steps | Done. The start and the totals of `totals :grow` stay outside the groups, so `dim` does not dim them. `Expresso.Element.Chart.lead/1` gives a chart with `reveal` one step before its first change, so the first step shows the start and the totals alone, as the table of the example shows. A browser test makes sure of the height and the count of a total at each step, and of the steps of `totals :complete`. |
| 5. The highlight | Done. The columns of the second pull request already had the `data-keys` of their categories, so the rules of the highlight of a chart dim the other columns with no new code. A browser test makes sure of the opacity of each column at each step. |
| 6. The spans | Done. A span shows with the last column before the total at its end, at its final value, and it does not count. The text of a number that counts has no sign, so a span that counts would lose the sign of a positive sum, and a span of 0 at the first step tells nothing. |
| 7. The direction | Done. The layout has the function `pos` from a value to its place on the value axis, and each function that places a mark has a clause for each direction. The right edge of a horizontal chart holds the labels at the ends of the bars and the spans. |
| 8. The frames | Not started |
| 9. The guide, the example decks and their GIFs | Not started |
