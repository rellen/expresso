# Diagrams from Mermaid

This document gives the plan for a `diagram` that takes the source of a diagram in the
language of Mermaid, and the record of its progress. [Pele](https://pele.run) draws the
diagram in Node, and the deck animates its parts with the parts of the `diagram` element,
as for a graph from Graphviz or D2. The document records ten decisions, and each is
settled. Issue #409 holds the same plan.

## The problem

Many developers write their diagrams in Mermaid, because GitHub, GitLab, Obsidian and many
documentation tools draw it. A deck can take a graph from Graphviz or D2, as
`docs/graph-diagrams.md` tells, but not from Mermaid. The author must draw the diagram again,
or export an SVG with no names for its parts.

Mermaid.js itself is a poor fit for a render outside a browser. It needs a browser to
measure its text, its bundle is approximately 1.6 MB with gzip, and its SVG has generated
ids.

## The constraints

The constraints of `docs/graph-diagrams.md` apply: the output stays one HTML file, a diagram
obeys the overlay contract, the same deck gives the same document, a deck without Mermaid
needs no tool, a missing tool stops the render with a message, and the watch mode renders
again after a change of the source.

## The facts about Pele

These facts come from Pele 1.8.0 in Node 24, in a session on Linux x86_64.

- Pele is a library of the team of Obsidian, with the MIT license. `render()` returns the
  SVG as a string, with one synchronous call and with no dependency.
- Pele supports each diagram type that Mermaid 12.1 builds in: 32 types. It does not support
  ZenUML and the other plugins of Mermaid, or labels of arbitrary HTML.
- Each part of a diagram has the attribute `data-id`. A node of a flowchart has its id from
  the source, such as `web`, and an edge has an id such as `L_web_api_0`. The messages of a
  sequence diagram have their order, such as `i0`.
- The classes give the kind of each part, such as `pele-node`, `pele-cluster` and
  `pele-edge`.
- `parse()` returns the model. An edge holds `start`, `end` and `id`, and a subgraph holds
  the ids of its direct members.
- An edge with a label has a second group for the label, with the same `data-id`. A sequence
  diagram draws each actor at the top and at the bottom, with one `data-id`.
- Each color is a custom property with a fallback, such as `var(--pele-fg, …)`, and a series
  of a chart is `--pele-series-1` and on.
- Outside a browser, Pele estimates the width of a text from a table. The option `measurer`
  takes a function `width(text, size, style)`.
- `dist/pele.js` is one ES module of 680 KB, or 259 KB with gzip, and it imports no other
  file. The output is the same in each run.
- A syntax error throws an error with the line of the error, such as `Parse error on line 3`.

## The decisions

| Number | Question | Decision |
| --- | --- | --- |
| 1 | The runtime | Node on the `PATH`. `EXPRESSO_NODE` gives a different path. A deck without Mermaid needs no Node. |
| 2 | The copy of Pele | `priv/pele/` holds `pele.js`, its license, a `package.json` with the type `module`, and the script `render.mjs`. `package.json` of the project names the same version, so Dependabot proposes a new version, and a test compares the two. |
| 3 | The widths of the text | A measurer that reads the advance widths of the TTF files of the `font` option. |
| 4 | The diagram types | Each type that Pele supports, with tests and an example. |
| 5 | The source | A `.mmd` file, or the text in the deck with the `source` option and `lang: :mermaid`. The option `lang` names the tool, so the same option can later take Graphviz or D2. |
| 6 | The marks of each type | The full marks of a graph for each type, so `edges :follow` and the list for a screen reader work for each type. A type with no edges, such as a pie, has parts of the kind `node`. |
| 7 | The pull requests | A stack, with one pull request for each type. |
| 8 | The guide | A new guide, `docs/how-to/draw-a-diagram-from-mermaid.md`, with example decks. |
| 9 | The name of an edge | The ends and the arrow, such as `web->api`, as for Graphviz and D2, and not the id of Pele, such as `L_web_api_0`. The ends come from the model, because an id such as `L_web_ui_api_0` cannot give its ends safely. An edge with an id in the source, such as `web e1@--> api`, keeps that id. |
| 10 | Two elements with one name | The group of a label and the second drawing of an actor get the same `id` as their part, so a part shows them at the same steps. Only the first element of a name gets the marks, so the list for a screen reader holds each part one time. |

Decision 9 changes the example of issue #409, which named an edge `L_web_api_0`.

## The design

- `Expresso.Element.Diagram.Pele` runs `priv/pele/render.mjs` through
  `Expresso.Element.Diagram.Tool`. The script reads `source.mmd` and `options.json` from a
  private directory, and it writes `graph.json` with the SVG, the type and the model.
  `Tool.run!/5` takes the name of that output file.
- `Pele.name/1` gives each element with a `data-id` its `id` and its marks, with a plan for
  each type. A type without a plan keeps the `data-id` as the name, with no marks.
- `Expresso.Element.Diagram` selects Pele for a `.mmd` file and for `lang: :mermaid`. A
  diagram takes a file or `source`, and not both. Pele has one layout, so a Mermaid diagram
  takes no `layout`.
- The class `diagram-pele` of the style sheet sets the custom properties of Pele from the
  roles of the theme. `colors :tool` leaves them out, so the fallbacks of Pele apply.
- `Expresso.Element.Diagram.Outline` reads the label of an edge from `data-graph-label`,
  because the label of Pele is not inside the group of the edge.
- The tests that run Node have the tag `:mermaid`. The other tests read the output of the
  script in `test/fixtures/mermaid/`.

## The stack

1. The tool: the copy of Pele, the script, the `source` and `lang` options, the flowchart
   with its marks, the colors and the cache.
2. The measurer of the theme font.
3. One pull request for each other type, in this order: sequence, class, state, er, c4,
   architecture, block, mindmap, requirement, usecase, git, gantt, timeline, journey,
   kanban, pie, xychart, quadrant, radar, sankey, treemap, treeview, packet, venn, ishikawa,
   swimlane, eventmodeling, agentflow, cynefin, railroad, wardley.
4. The guide, the example decks and their GIFs.

## The progress

| Pull request | State |
| --- | --- |
| 1. The tool and the flowchart | Done |
| 2. The measurer of the theme font | Done. `Font.advances/2` reads the `cmap` (format 4 or 12), `hmtx`, `hhea` and `head` tables of each style. The script gives Pele a measurer that adds the advance widths, with no kerning. A monospace text and a character that the font does not have take 0.6 of the size for each character. |
| 3. Sequence | Done. A message is an edge between two actors, such as `Customer->Web`, and a note is `note1`. The plans moved into one module for each type, with `Expresso.Element.Diagram.Pele.Plan`. The fixtures of `test/fixtures/mermaid/` hold the output of the script, and `EXPRESSO_MERMAID=write` writes them again. |
| 4. Class | Done. A relation is an edge between two classes, such as `Animal<-Turtle`, with the arrow toward its marker. A class in a namespace has the namespace as its parent, and the line of a note is `note0--Turtle`. |
| 5. State | Done. A transition is an edge between two states, such as `Draft->Submitted`, and the start and the end are `root_start` and `root_end`. A composite state is a container, and a concurrent region has no group, so its states have the composite state as their parent. |
| 6. Entity relationship | Done. A relationship is an edge between two entities, such as `CUSTOMER--ORDER`, with the role as its label. The model gives the ids of the entities, such as `entity-CUSTOMER-0`, and the plan names the ends by the names of the entities. |
| 7. C4 | Done. A relationship is an edge between two aliases, such as `customer->web`. A boundary and a deployment node are containers, and a shape has the boundary of the model as its parent. |
| 8. Architecture | Done. An edge is named by its two ends, such as `web->api`. Pele gives each edge between the same ends one `data-id`, so the function of a plan can take a third argument: the number of earlier elements with the same `data-id` and the same classes. |
| 9. Block | Done. An edge is named by its two ends, such as `server->db`. A composite block is a container, and a block in it has the composite block as its parent. |
| 10. Mindmap | Done. A line is an edge from a node to its child, such as `root--Elements`. Pele draws a line with no `data-id`, so a plan with three arguments gets such an edge with the `data-id` `nil`, and `Pele.name/1` puts a named line into a group with its marks. |
| 11. Requirement | Done. A relationship is an edge from its source to its destination, such as `bundle->fast`, with its type as its label. |
| 12. Use case | Done. A relationship is an edge between two ends, such as `Presenter->Talk`. A system boundary is a container, and a use case in it has the boundary as its parent. |
| 13. Git | Done. A line is an edge from a parent commit to a commit, such as `deck--chart`, and a commit has its branch as its parent. Pele draws each line with no `data-id`: first each line between two branches, then each line on one branch. A test makes sure that each line goes from the circle of its parent to the circle of its commit. |
| 14. Gantt | Done. A task is a node with no edges, such as `write`, and the label of a section keeps the name of the section. The types test takes `follow: nil` for a type with no edges. |
| 15. Timeline | Done. A section and a period are containers, and an event is a node such as `2025/2`. Pele draws an event with no `data-id`, so a plan with three arguments now gets each node with no `data-id` too, with a count of its own. A group with no `data-id` takes its name and its marks itself. |
| 16. User journey | Done. A section is a container, and a task is a node with its section as its parent. The line of the scores is one path, and the faces have no `data-id`, so they show at each step. |
| 17. Kanban | Done. A column is a container, and a card is a node with its column as its parent. |
| 18. Pie | Done. A slice is a node with its label as its name, and its item of the legend gets the same name. Pele draws a slice as a `path`, so `Pele.name/1` now puts each element with marks that is not a group into a group with its name and its marks. |
| 19. XY chart | Done. A series is a node, named by its title, or by its type and number, such as `line1`. Pele gives a series without a title no `data-id`, so a plan with three arguments now gets each series with no `data-id` too. Pele draws each bar series before each line series. |
| 20. Quadrant | Done. A quadrant is a node such as `quadrant-2`, and a point is a node with its text as its name. Pele draws the label of a point with no `data-id`, so a plan with three arguments now gets each label with no `data-id` too. A label counts in its group, and the plan gets the classes of the group, such as `pele-point-labels`. |
| 21. Radar | Done. A curve is a node with its name in the source, and the label of an axis is a node such as `axis-a`. |
