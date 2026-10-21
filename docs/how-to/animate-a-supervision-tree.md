# Animate a supervision tree

This guide shows how to animate a supervision tree of Elixir with the `tree` element. The
example deck shows the strategies of a `Supervisor`, a `DynamicSupervisor` and a
`PartitionSupervisor`, with workers that start, crash and start again. For each option, see
[The tree element](../reference/tree-element.md).

## Show the tree of an application

A supervision tree is a hierarchy, so the `tree` element shows it as an org chart. Give each
process a `node` entity:

- The name of the node is the name of the process, such as `MyApp.Sessions`.
- The `detail` option tells the kind of the process, such as `DynamicSupervisor`, or its PID.
- The `icon` option gives the kind of the process a symbol, such as `"layers"` for a
  `DynamicSupervisor`.

`reveal :levels` shows the application one level at each step. `stack_from 3` puts the
children of each supervisor in a column under it, so that the tree stays narrow.

## Show a crash and a restart with frames

Put the whole tree into a `frame` entity for each event. The name of a node is its identity
across the frames. At the step of each frame, the box of a process changes to its new
state:

| Event | The node in the frame | The animation |
| --- | --- | --- |
| A child starts | A new node | The new box fades in, and the other boxes move to make space. |
| A child crashes | `color :danger`, the icon `"skull"` and the exit reason as the detail | The box fades to red. |
| The supervisor stops a child | `color :warning`, the icon `"circle-x"` and `exit: :shutdown` | The box fades to orange. |
| The supervisor starts a child again | `color :success`, the icon `"refresh-cw"` and a new PID | The box fades to green with the new PID. |
| A child stops for all time | The frame does not hold the node | The box fades out, and the other boxes move. |

The label of each frame shows under the tree, so it tells the audience what occurs.

## The example deck

The deck has one slide for the tree of the application, three slides for the strategies of
a `Supervisor`, and one slide each for a `DynamicSupervisor` and a `PartitionSupervisor`:

```elixir
defmodule Examples.TreeSupervision do
  use Expresso

  slide "the application" do
    heading "A supervision tree"

    tree do
      title "The supervision tree of the application"
      color :branch
      reveal :levels
      effect :grow
      stack_from 3
      box [[width: 300, height: 96], [width: 250, height: 96], [width: 200, height: 56]]

      node "MyApp.Supervisor" do
        detail "one_for_one"
        icon "network"

        node "MyApp.Registry", detail: "Registry", icon: "list-tree"

        node "MyApp.Sessions" do
          detail "DynamicSupervisor"
          icon "layers"
          node "session 1"
          node "session 2"
        end

        node "MyApp.Caches" do
          detail "PartitionSupervisor"
          icon "split"
          node "partition 0"
          node "partition 1"
          node "partition 2"
        end

        node "MyApp.Pipeline" do
          detail "rest_for_one"
          icon "workflow"
          node "Producer"
          node "Consumer"
        end
      end
    end
  end

  slide "one for one" do
    heading "one_for_one"

    tree do
      title "A supervisor with the strategy one_for_one"
      box width: 260, height: 96

      frame "Three workers run" do
        node "Workers" do
          detail "Supervisor, one_for_one"
          icon "network"
          node "worker 1", detail: "#PID<0.211.0>", icon: "cog"
          node "worker 2", detail: "#PID<0.212.0>", icon: "cog"
          node "worker 3", detail: "#PID<0.213.0>", icon: "cog"
        end
      end

      frame "Worker 2 crashes" do
        node "Workers" do
          detail "Supervisor, one_for_one"
          icon "network"
          node "worker 1", detail: "#PID<0.211.0>", icon: "cog"
          node "worker 2", detail: "exit: :boom", icon: "skull", color: :danger
          node "worker 3", detail: "#PID<0.213.0>", icon: "cog"
        end
      end

      frame "The supervisor starts worker 2 again, with a new PID" do
        node "Workers" do
          detail "Supervisor, one_for_one"
          icon "network"
          node "worker 1", detail: "#PID<0.211.0>", icon: "cog"
          node "worker 2", detail: "#PID<0.231.0>", icon: "refresh-cw", color: :success
          node "worker 3", detail: "#PID<0.213.0>", icon: "cog"
        end
      end
    end
  end

  slide "one for all" do
    heading "one_for_all"

    tree do
      title "A supervisor with the strategy one_for_all"
      box width: 260, height: 96

      frame "Three workers run" do
        node "Workers" do
          detail "Supervisor, one_for_all"
          icon "network"
          node "worker 1", detail: "#PID<0.211.0>", icon: "cog"
          node "worker 2", detail: "#PID<0.212.0>", icon: "cog"
          node "worker 3", detail: "#PID<0.213.0>", icon: "cog"
        end
      end

      frame "Worker 2 crashes" do
        node "Workers" do
          detail "Supervisor, one_for_all"
          icon "network"
          node "worker 1", detail: "#PID<0.211.0>", icon: "cog"
          node "worker 2", detail: "exit: :boom", icon: "skull", color: :danger
          node "worker 3", detail: "#PID<0.213.0>", icon: "cog"
        end
      end

      frame "The supervisor stops the other workers" do
        node "Workers" do
          detail "Supervisor, one_for_all"
          icon "network"
          node "worker 1", detail: "exit: :shutdown", icon: "circle-x", color: :warning
          node "worker 2", detail: "exit: :boom", icon: "skull", color: :danger
          node "worker 3", detail: "exit: :shutdown", icon: "circle-x", color: :warning
        end
      end

      frame "The supervisor starts the three workers again" do
        node "Workers" do
          detail "Supervisor, one_for_all"
          icon "network"
          node "worker 1", detail: "#PID<0.241.0>", icon: "refresh-cw", color: :success
          node "worker 2", detail: "#PID<0.242.0>", icon: "refresh-cw", color: :success
          node "worker 3", detail: "#PID<0.243.0>", icon: "refresh-cw", color: :success
        end
      end
    end
  end

  slide "rest for one" do
    heading "rest_for_one"

    tree do
      title "A supervisor with the strategy rest_for_one"
      box width: 260, height: 96

      frame "The children start from the left" do
        node "MyApp.Pipeline" do
          detail "Supervisor, rest_for_one"
          icon "workflow"
          node "Source", detail: "#PID<0.301.0>", icon: "database"
          node "Producer", detail: "#PID<0.302.0>", icon: "cog"
          node "Consumer", detail: "#PID<0.303.0>", icon: "cog"
          node "Sink", detail: "#PID<0.304.0>", icon: "hard-drive"
        end
      end

      frame "The producer crashes" do
        node "MyApp.Pipeline" do
          detail "Supervisor, rest_for_one"
          icon "workflow"
          node "Source", detail: "#PID<0.301.0>", icon: "database"
          node "Producer", detail: "exit: :boom", icon: "skull", color: :danger
          node "Consumer", detail: "#PID<0.303.0>", icon: "cog"
          node "Sink", detail: "#PID<0.304.0>", icon: "hard-drive"
        end
      end

      frame "The supervisor stops the children after the producer" do
        node "MyApp.Pipeline" do
          detail "Supervisor, rest_for_one"
          icon "workflow"
          node "Source", detail: "#PID<0.301.0>", icon: "database"
          node "Producer", detail: "exit: :boom", icon: "skull", color: :danger
          node "Consumer", detail: "exit: :shutdown", icon: "circle-x", color: :warning
          node "Sink", detail: "exit: :shutdown", icon: "circle-x", color: :warning
        end
      end

      frame "The supervisor starts them again, and the source keeps its PID" do
        node "MyApp.Pipeline" do
          detail "Supervisor, rest_for_one"
          icon "workflow"
          node "Source", detail: "#PID<0.301.0>", icon: "database"
          node "Producer", detail: "#PID<0.322.0>", icon: "refresh-cw", color: :success
          node "Consumer", detail: "#PID<0.323.0>", icon: "refresh-cw", color: :success
          node "Sink", detail: "#PID<0.324.0>", icon: "refresh-cw", color: :success
        end
      end
    end
  end

  slide "dynamic supervisor" do
    heading "A DynamicSupervisor"

    tree do
      title "A DynamicSupervisor that starts, restarts and stops sessions"
      box width: 260, height: 96

      frame "The supervisor starts with no children" do
        node "MyApp.Sessions", detail: "DynamicSupervisor", icon: "layers"
      end

      frame "start_child/2 starts session 1" do
        node "MyApp.Sessions" do
          detail "DynamicSupervisor"
          icon "layers"
          node "session 1", detail: "#PID<0.401.0>", icon: "circle-plus", color: :success
        end
      end

      frame "Two more users sign in" do
        node "MyApp.Sessions" do
          detail "DynamicSupervisor"
          icon "layers"
          node "session 1", detail: "#PID<0.401.0>", icon: "users"
          node "session 2", detail: "#PID<0.402.0>", icon: "circle-plus", color: :success
          node "session 3", detail: "#PID<0.403.0>", icon: "circle-plus", color: :success
        end
      end

      frame "Session 2 crashes" do
        node "MyApp.Sessions" do
          detail "DynamicSupervisor"
          icon "layers"
          node "session 1", detail: "#PID<0.401.0>", icon: "users"
          node "session 2", detail: "exit: :boom", icon: "skull", color: :danger
          node "session 3", detail: "#PID<0.403.0>", icon: "users"
        end
      end

      frame "The supervisor starts session 2 again" do
        node "MyApp.Sessions" do
          detail "DynamicSupervisor"
          icon "layers"
          node "session 1", detail: "#PID<0.401.0>", icon: "users"
          node "session 2", detail: "#PID<0.412.0>", icon: "refresh-cw", color: :success
          node "session 3", detail: "#PID<0.403.0>", icon: "users"
        end
      end

      frame "terminate_child/2 stops session 1" do
        node "MyApp.Sessions" do
          detail "DynamicSupervisor"
          icon "layers"
          node "session 2", detail: "#PID<0.412.0>", icon: "users"
          node "session 3", detail: "#PID<0.403.0>", icon: "users"
        end
      end
    end
  end

  slide "partition supervisor" do
    heading "A PartitionSupervisor"

    tree do
      title "A PartitionSupervisor with three partitions, each a DynamicSupervisor"
      stack_from 3
      box [[width: 260, height: 96], [width: 250, height: 96], [width: 240, height: 80]]

      frame "Each partition is a DynamicSupervisor" do
        node "MyApp.Caches" do
          detail "PartitionSupervisor"
          icon "split"

          node "partition 0" do
            detail "#PID<0.501.0>"
            icon "layers"
            node "cache a", detail: "#PID<0.511.0>", icon: "database"
          end

          node "partition 1" do
            detail "#PID<0.502.0>"
            icon "layers"
            node "cache b", detail: "#PID<0.512.0>", icon: "database"
            node "cache c", detail: "#PID<0.513.0>", icon: "database"
          end

          node "partition 2" do
            detail "#PID<0.503.0>"
            icon "layers"
            node "cache d", detail: "#PID<0.514.0>", icon: "database"
          end
        end
      end

      frame "Cache c crashes" do
        node "MyApp.Caches" do
          detail "PartitionSupervisor"
          icon "split"

          node "partition 0" do
            detail "#PID<0.501.0>"
            icon "layers"
            node "cache a", detail: "#PID<0.511.0>", icon: "database"
          end

          node "partition 1" do
            detail "#PID<0.502.0>"
            icon "layers"
            node "cache b", detail: "#PID<0.512.0>", icon: "database"
            node "cache c", detail: "exit: :boom", icon: "skull", color: :danger
          end

          node "partition 2" do
            detail "#PID<0.503.0>"
            icon "layers"
            node "cache d", detail: "#PID<0.514.0>", icon: "database"
          end
        end
      end

      frame "Partition 1 starts cache c again, and the other partitions do not see the crash" do
        node "MyApp.Caches" do
          detail "PartitionSupervisor"
          icon "split"

          node "partition 0" do
            detail "#PID<0.501.0>"
            icon "layers"
            node "cache a", detail: "#PID<0.511.0>", icon: "database"
          end

          node "partition 1" do
            detail "#PID<0.502.0>"
            icon "layers"
            node "cache b", detail: "#PID<0.512.0>", icon: "database"
            node "cache c", detail: "#PID<0.533.0>", icon: "refresh-cw", color: :success
          end

          node "partition 2" do
            detail "#PID<0.503.0>"
            icon "layers"
            node "cache d", detail: "#PID<0.514.0>", icon: "database"
          end
        end
      end

      frame "Partition 2 crashes" do
        node "MyApp.Caches" do
          detail "PartitionSupervisor"
          icon "split"

          node "partition 0" do
            detail "#PID<0.501.0>"
            icon "layers"
            node "cache a", detail: "#PID<0.511.0>", icon: "database"
          end

          node "partition 1" do
            detail "#PID<0.502.0>"
            icon "layers"
            node "cache b", detail: "#PID<0.512.0>", icon: "database"
            node "cache c", detail: "#PID<0.533.0>", icon: "database"
          end

          node "partition 2" do
            detail "exit: :boom"
            icon "skull"
            color :danger
            node "cache d", detail: "exit: :boom", icon: "circle-x", color: :warning
          end
        end
      end

      frame "The new partition 2 starts with no children" do
        node "MyApp.Caches" do
          detail "PartitionSupervisor"
          icon "split"

          node "partition 0" do
            detail "#PID<0.501.0>"
            icon "layers"
            node "cache a", detail: "#PID<0.511.0>", icon: "database"
          end

          node "partition 1" do
            detail "#PID<0.502.0>"
            icon "layers"
            node "cache b", detail: "#PID<0.512.0>", icon: "database"
            node "cache c", detail: "#PID<0.533.0>", icon: "database"
          end

          node "partition 2", detail: "#PID<0.543.0>", icon: "refresh-cw", color: :success
        end
      end
    end
  end
end

Examples.TreeSupervision
```

### The tree of the application

The first slide shows the root supervisor, then its four children, then their children.
`color :branch` gives each child of the root a color:

![The root supervisor shows, then a registry, a DynamicSupervisor, a PartitionSupervisor and a pipeline under it, then the children of each one](https://raw.githubusercontent.com/rellen/expresso/media/tree-supervision.gif)

### The strategy one_for_one

When a child crashes, the supervisor starts only that child again. The other workers keep
their PIDs:

![Worker 2 crashes and turns red, then it starts again in green with a new PID, and workers 1 and 3 do not change](https://raw.githubusercontent.com/rellen/expresso/media/tree-one-for-one.gif)

### The strategy one_for_all

When a child crashes, the supervisor stops each other child, and then it starts all of
them again:

![Worker 2 crashes, the supervisor stops workers 1 and 3, then the three workers start again with new PIDs](https://raw.githubusercontent.com/rellen/expresso/media/tree-one-for-all.gif)

### The strategy rest_for_one

When a child crashes, the supervisor stops the children that started after it, and then it
starts them again. The children before it keep their PIDs:

![The producer crashes, the supervisor stops the consumer and the sink, then the three start again and the source keeps its PID](https://raw.githubusercontent.com/rellen/expresso/media/tree-rest-for-one.gif)

### A DynamicSupervisor

A `DynamicSupervisor` starts with no children. `DynamicSupervisor.start_child/2` adds a
child at run time, and `DynamicSupervisor.terminate_child/2` stops one. Each new node fades
in, and the node that stops fades out:

![Three sessions start one by one, session 2 crashes and starts again, then session 1 stops and its box goes away](https://raw.githubusercontent.com/rellen/expresso/media/tree-dynamic-supervisor.gif)

### A PartitionSupervisor

A `PartitionSupervisor` starts a number of copies of one child, and each copy is a
partition. Here each partition is a `DynamicSupervisor`. A crash of a cache stays in its
partition. When a partition crashes, its children stop with the same exit reason. The
`PartitionSupervisor` starts the partition again, but the dynamic children of the old
partition do not come back:

![Cache c crashes and partition 1 starts it again, then partition 2 crashes and starts again with no children](https://raw.githubusercontent.com/rellen/expresso/media/tree-partition-supervisor.gif)

The handout view and paper show the frames of each slide as small trees in a grid.
