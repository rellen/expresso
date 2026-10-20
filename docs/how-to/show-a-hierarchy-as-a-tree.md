# Show a hierarchy as a tree

This guide shows how to draw a hierarchy as boxes and lines with the `tree` element: an org
chart, the use of a disk by folders, and a change of a team. For each option, see
[The tree element](../reference/tree-element.md).

## Draw an org chart and show it level by level

Write a `tree` element with a `title` for a screen reader. Put one `node` entity into it,
the root, and nest the nodes under each node. A node with nodes under it gives its options
in its block, such as `detail "Production"`. A node at the end of a branch can give its
options after its name.

`color :branch` gives each branch under the root a color of the palette. `reveal :levels`
shows one level at each step, and the effect `:grow` draws each line from its parent:

```elixir
defmodule Examples.TreeOrg do
  use Expresso

  slide "the plant" do
    heading "The plant"

    tree do
      title "The teams of the plant"
      color :branch
      reveal :levels
      effect :grow

      node "Ana" do
        detail "Plant manager"
        icon "factory"

        node "Ben" do
          detail "Production"
          icon "wrench"
          node "Cy", detail: "Press"
          node "Di", detail: "Paint"
        end

        node "Eve" do
          detail "Quality"
          icon "flask-conical"
          node "Gus", detail: "Lab"
        end

        node "Hal" do
          detail "Logistics"
          icon "truck"
          node "Ivy", detail: "Shipping"
        end
      end
    end
  end
end

Examples.TreeOrg
```

![An org chart shows the plant manager, then the three teams, then the people of each team, in a color for each team](https://raw.githubusercontent.com/rellen/expresso/media/tree-org.gif)

The icon of a node is the name of an icon of [the icon element](../reference/icon-element.md).
An `image` option shows a photo in a circle in its place. To show the nodes of one branch
at each step, write `reveal :branches`. To give a step to one node, give it the `at` option.

## Show the use of a disk from a CSV file

A CSV file gives a large tree. In the path form, the file has a `path` column, and the
other columns have the names of the options of a node:

```
path,value
/home/photos,412000000000
/home/video,268000000000
/home/code,38000000000
/home/mail,6000000000
/home/notes,1000000000
/var/log,24000000000
/var/cache,9000000000
```

A folder with no row of its own gets the sum of the values under it. These options make
the tree easy to read:

- `layout :left_right` puts the levels in columns, so a long tree fits the slide.
- `value_format :bytes` shows a size such as `412 GB`.
- `sort :value` puts the largest folder first.
- `limit 2` keeps the two largest folders under each folder, and one more node holds the
  total of the rest.
- `bar true` adds a bar along the bottom of each box, with its part of the whole disk.

The `highlight` option then puts one branch in focus at each step, and the rest of the tree
dims. `whole_first true` shows the whole tree first:

```elixir
defmodule Examples.TreeDisk do
  use Expresso

  root __DIR__

  slide "the disk" do
    heading "Where the space goes"

    tree do
      title "The use of the disk, by folder"
      src "disk.csv"
      layout :left_right
      box [[width: 200, height: 80], [width: 240, height: 80]]
      value_format :bytes
      sort :value
      limit 2
      bar true
      highlight [branch("home"), branch("var")]
      whole_first true
    end
  end
end

Examples.TreeDisk
```

![A tree of the folders of a disk from left to right, with a bar in each box, and the home folder and then the var folder in focus](https://raw.githubusercontent.com/rellen/expresso/media/tree-disk.gif)

A file in the parent form has the columns `id` and `parent` in place of `path`. Use this
form for an export from a list of people. See [the data](../reference/tree-element.md#the-data).

## Show a change of a team with frames

Put a whole tree into each `frame` entity. The name of a node is its identity across the
frames. At the step of the next frame, a box moves to its new place, a new box fades in, and
a box with a new detail fades to that detail:

```elixir
defmodule Examples.TreeReorg do
  use Expresso

  slide "the reorg" do
    heading "The new quality team"

    tree do
      title "The teams of the plant"

      frame "Before" do
        node "Ana" do
          detail "Plant manager"

          node "Ben" do
            detail "Production"
            node "Cy", detail: "Press"
            node "Di", detail: "Paint"
          end

          node "Eve" do
            detail "Quality"
            node "Gus", detail: "Lab"
          end
        end
      end

      frame "After" do
        node "Ana" do
          detail "Plant manager"

          node "Ben" do
            detail "Production"
            node "Cy", detail: "Press"
          end

          node "Eve" do
            detail "Quality and paint"
            node "Di", detail: "Paint"
            node "Gus", detail: "Lab"
            node "Kim", detail: "Audit"
          end
        end
      end
    end
  end
end

Examples.TreeReorg
```

![A team before a change, then Di moves under Eve, Eve gets a new detail and Kim joins the team](https://raw.githubusercontent.com/rellen/expresso/media/tree-reorg.gif)

The label of each frame shows under the tree. The handout view and paper show each frame as
a small tree in a grid. A CSV file gives frames too: the `frames` option names the column of
the frame of each row.
