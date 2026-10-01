# A talk about the page https://rellen.github.io/iso-factories/line-4/index.html, an
# isometric factory in one HTML file. The deck uses each feature of Expresso: the
# deck and slide templates, a theme from a map, the css option with a new effect
# and a new state, each element, each overlay option, goto links and notes.
#
# Run the command from the root of the repository, because each path is relative
# to the working directory:
#
#     mix expresso examples/line4/line4.exs /tmp/line4.html
#
# The code on the slides comes from the script of the page. Long lines have line
# breaks, and "…" marks lines that the slide leaves out.

defmodule Line4.DeckTemplate do
  use Expresso.Template.Deck

  def header(_assigns) do
    temple do
      div do
        span class: "header" do
          "Northside Works · Line 4"
        end
      end
    end
  end

  def footer(_assigns) do
    temple do
      div do
        span class: "footer" do
          "rellen.github.io/iso-factories/line-4 · app.js, 4340 lines"
        end
      end
    end
  end
end

# The slide template of the cover and of the start of each part. The name of the
# slide is the small line above the heading.
defmodule Line4.PartTemplate do
  use Expresso.Template

  def render(assigns) do
    temple do
      div class: "slide-body part" do
        p class: "part-name" do
          @name
        end

        h2 class: "part-heading" do
          Map.get(@metadata, :heading, "")
        end

        div class: "slide-main" do
          c(&Expresso.Template.render_elements(&1), elements: @elements)
        end
      end
    end
  end
end

defmodule Line4.Deck do
  use Expresso

  name "Line 4: how the factory works"
  template Line4.DeckTemplate
  duration 40
  slide_numbers true
  progress true
  transition :slide
  handout :last
  print_notes true
  effect :fade
  easing :ease_out

  # The colors of the page itself: the background, the ink, the safety yellow of
  # the floor lines and the colors of the status lights.
  theme %{
    base00: "#1b232c",
    base01: "#222c37",
    base02: "#33404d",
    base03: "#93a0ae",
    base04: "#93a0ae",
    base05: "#e6ebf0",
    base06: "#f0f4f7",
    base07: "#ffffff",
    base08: "#ff6b6b",
    base09: "#ffb13b",
    base0A: "#f0d12a",
    base0B: "#5cf58a",
    base0C: "#9dc4d6",
    base0D: "#e8b83a",
    base0E: "#7fb0ff",
    base0F: "#c8a061"
  }

  css ~S"""
  .slide-heading-container h1 {
    font-size: 1.1rem;
    text-transform: none;
    color: var(--accent);
  }
  .code pre {
    font-size: 0.46rem;
  }
  .math {
    font-size: 0.8rem;
  }
  .table {
    font-size: 0.5rem;
  }
  .list {
    font-size: 0.7rem;
  }
  .text-area {
    font-size: 0.7rem;
  }
  .part {
    justify-content: center;
    text-align: center;
  }
  .part .slide-main,
  .part .text-area {
    flex-grow: 0;
  }
  .part-name {
    margin: 0;
    font-size: 0.5rem;
    letter-spacing: 0.2em;
    text-transform: uppercase;
    color: var(--muted);
  }
  .part-heading {
    margin: 0.25rem 0 0.5rem;
    font-size: 1.6rem;
    color: var(--accent);
  }

  /* The effect :conveyor: the element comes in from the left, as a box on a belt. */
  [data-effect="conveyor"] {
    --enter-x: -8rem;
  }

  /* The effect :beacon: the element grows past its size and back, as a lamp that comes on. */
  @keyframes beacon {
    0% { transform: scale(0.4); }
    60% { transform: scale(1.12); }
    100% { transform: scale(1); }
  }
  [data-effect="beacon"] {
    --enter-animation: beacon;
  }

  /* The state :lit: a band of safety yellow behind a row or an item. */
  .row,
  .item {
    background-color: color-mix(in srgb, var(--accent) calc(var(--lit, 0) * 30%), transparent);
  }
  """

  # ---------------------------------------------------------------- 1
  slide "Northside Works" do
    heading "Line 4: how the factory works"
    template Line4.PartTemplate
    notes "The page is one HTML file. Open it next to the deck, and let it run during the talk."

    text_area(text: "An isometric factory in one HTML file, and the code that runs it")

    image "examples/line4/line4.png" do
      alt "Line 4 after 12 seconds: belts, robot arms, a paint booth, forklifts and the status panel"
      width "62%"
      effect :blur
      speed :slow
    end
  end

  # ---------------------------------------------------------------- 2
  slide "route" do
    heading "The route through the factory"
    notes "Each item is a link. The talk follows the order of the list."

    list do
      ordered true
      effect :conveyor
      reveal true
      speed 450

      item "The picture: boxes, a projection and a paint order" do
        goto slide: 4
      end

      item "The line: the frame, the stations and the state machines" do
        goto slide: 14
      end

      item "Trouble: faults, people and the physics check" do
        goto slide: 24
      end

      item "The numbers and the small things" do
        goto slide: 29
      end

      item "This deck, in the DSL of Expresso" do
        goto slide: 36
      end
    end
  end

  # ---------------------------------------------------------------- 3
  slide "one file" do
    heading "One file, one canvas, no libraries"
    notes "The page has no build step. View the source of the page to see all of it."

    columns do
      column do
        width "48%"

        list do
          reveal true
          dim true
          effect :fly_left
          item "One IIFE in strict mode, 4340 lines"
          item "No modules, no WebGL, no images"
          item "Canvas 2D for each pixel"
          item "Each frame rebuilds the scene as boxes"
          item "About 2262 boxes in a frame"
        end
      end

      column do
        table do
          header true
          row ["Lines", "Section"]
          row ["31–53", "projection"]
          row ["81–274", "boxes and the paint order"]
          row ["276–679", "render cache"]
          row ["852–1251", "simulation state, faults"]
          row ["1253–1398", "robot arms"]
          row ["2060–2922", "route graph, people, robots"]
          row ["2924–3377", "line simulation"]
          row ["4187–4229", "OEE"]
          row ["4287–4340", "main loop"]
        end
      end
    end
  end

  # ---------------------------------------------------------------- 4
  slide "Part 1" do
    heading "The picture"
    template Line4.PartTemplate
    transition :zoom
    notes "Part 1 tells how the page draws the factory."

    text_area(text: "Every thing on the screen is a box with three visible faces.")
  end

  # ---------------------------------------------------------------- 5
  slide "axes" do
    heading "Every thing is a box"

    notes """
    Step 1: x goes down to the right, y goes down to the left, z goes up.
    Steps 2 to 4: the three faces that the viewer sees, with their shade factors.
    Step 5: the viewer is toward +x, +y and +z, so a larger value is nearer.
    """

    diagram "examples/line4/axes.svg" do
      width "80%"

      part "face-top" do
        at from: 2
        effect :grow
      end

      part "face-y1" do
        at from: 3
        effect :fly_right
      end

      part "face-x1" do
        at from: 4
        effect :fly_left
      end

      part "viewer" do
        at from: 5
        effect :fly_up
        easing :spring
      end
    end
  end

  # ---------------------------------------------------------------- 6
  slide "projection" do
    heading "Three numbers to a point on the screen"

    notes "One unit along x or y is U pixels long on the screen. resize() sets U so that the hall fills 96% of the canvas."

    code "js" do
      reveal [1..4, 6..10, 11..12]
      dim true

      text ~S"""
      // World: x runs screen down-right, y runs screen down-left, z is up.
      // The viewer sits toward +x, +y, +z, so larger x / y / z means "closer".
      const COS30 = Math.sqrt(3) / 2, SIN30 = 0.5, EPS = 1e-4;
      let U = 28, ox = 0, oy = 0;

      function resize() {
        // …
        const sw = (XMAX - XMIN + D) * COS30, sh = (XMAX + D) * SIN30 + HMAX;
        U = Math.min(w / sw, h / sh) * 0.96;
      }
      const px = (x, y) => ox + (x - y) * COS30 * U;
      const py = (x, y, z) => oy + (x + y) * SIN30 * U - z * U;
      """
    end

    math ~S"""
    <math display="block"><mtable>
      <mtr><mtd><msub><mi>s</mi><mi>x</mi></msub><mo>=</mo><msub><mi>o</mi><mi>x</mi></msub><mo>+</mo><mo>(</mo><mi>x</mi><mo>−</mo><mi>y</mi><mo>)</mo><mo>·</mo><mi>cos</mi><mn>30°</mn><mo>·</mo><mi>U</mi></mtd></mtr>
      <mtr><mtd><msub><mi>s</mi><mi>y</mi></msub><mo>=</mo><msub><mi>o</mi><mi>y</mi></msub><mo>+</mo><mo>(</mo><mi>x</mi><mo>+</mo><mi>y</mi><mo>)</mo><mo>·</mo><mi>sin</mi><mn>30°</mn><mo>·</mo><mi>U</mi><mo>−</mo><mi>z</mi><mo>·</mo><mi>U</mi></mtd></mtr>
    </mtable></math>
    """ do
      at from: 3
      effect :blur
    end
  end

  # ---------------------------------------------------------------- 7
  slide "drawBox" do
    heading "Three faces and a fixed light"

    notes "The top face keeps the color. The y1 face gets 82% and the x1 face gets 60%. A box with no height draws its top face only, which gives the floor lines."

    code "js" do
      reveal [1..5, 6..7, 8..13]
      dim true

      text ~S"""
      const OUTLINE = 'rgba(14,18,24,0.45)';
      function drawBox(b) {
        const { x0, y0, z0, x1, y1, z1, c } = b;
        const st = (Math.max(x1 - x0, y1 - y0, z1 - z0) > 0.1 && !b.ns) ? OUTLINE : null;
        ctx.globalAlpha = b.a === undefined ? 1 : b.a;
        poly([[px(x0, y0), py(x0, y0, z1)], [px(x1, y0), py(x1, y0, z1)],
              [px(x1, y1), py(x1, y1, z1)], [px(x0, y1), py(x0, y1, z1)]], shade(c, 1.0), st);
        if (z1 - z0 > 1e-6) {
          poly([[px(x0, y1), py(x0, y1, z0)], [px(x1, y1), py(x1, y1, z0)],
                [px(x1, y1), py(x1, y1, z1)], [px(x0, y1), py(x0, y1, z1)]], shade(c, 0.82), st);
          poly([[px(x1, y0), py(x1, y0, z0)], [px(x1, y1), py(x1, y1, z0)],
                [px(x1, y1), py(x1, y1, z1)], [px(x1, y0), py(x1, y0, z1)]], shade(c, 0.6), st);
        }
        // … the stripes of a belt
      }
      """
    end
  end

  # ---------------------------------------------------------------- 8
  slide "slabs" do
    heading "A hexagon is three slabs"

    notes "In u = x − y, v = x − z and w = y − z, the screen outline of a box is the intersection of three bands. Two boxes overlap on the screen only when all three intervals overlap."

    diagram "examples/line4/slabs.svg" do
      width "72%"

      part "band-u" do
        at from: 2
        effect :wipe
      end

      part "band-v" do
        at from: 3
        effect :wipe
      end

      part "band-w" do
        at from: 4
        effect :wipe
      end

      part "cube" do
        on [from: 5], set: [opacity: 0.35]
      end

      part "hex" do
        at from: 5
        effect :grow
        speed :slow
        easing :spring
      end
    end
  end

  # ---------------------------------------------------------------- 9
  slide "intervals" do
    heading "Six numbers per box, used two times"

    notes "The sort uses the six numbers to find pairs that overlap. The hover pick uses the same numbers: it inverts the projection and tests the point against the three intervals."

    code "js" do
      reveal [1..3, 4..6, 7..8]

      text ~S"""
      for (let i = 0; i < n; i++) {
        const b = bs[i];
        const x0 = b.x0, y0 = b.y0, z0 = b.z0, x1 = b.x1, y1 = b.y1, z1 = b.z1;
        U0[i] = x0 - y1; U1[i] = x1 - y0;
        V0[i] = x0 - z1; V1[i] = x1 - z0;
        W0[i] = y0 - z1; W1[i] = y1 - z0;
        KEY[i] = x0 + y0 + z0;
        // …
      """
    end

    pause()

    math ~S"""
    <math display="block"><mrow>
      <mi>u</mi><mo>=</mo><mfrac><mrow><msub><mi>s</mi><mi>x</mi></msub><mo>−</mo><msub><mi>o</mi><mi>x</mi></msub></mrow><mrow><mi>cos</mi><mn>30°</mn><mo>·</mo><mi>U</mi></mrow></mfrac>
      <mspace width="1em"/>
      <mi>x</mi><mo>−</mo><mi>z</mi><mo>=</mo><mi>v</mi><mo>+</mo><mfrac><mi>u</mi><mn>2</mn></mfrac>
      <mspace width="1em"/>
      <mi>y</mi><mo>−</mo><mi>z</mi><mo>=</mo><mi>v</mi><mo>−</mo><mfrac><mi>u</mi><mn>2</mn></mfrac>
    </mrow></math>
    """ do
      at from: :next
      effect :fly_up
    end
  end

  # ---------------------------------------------------------------- 10
  slide "paint order" do
    heading "Behind relations, then a topological sort"

    notes "Many isometric renderers sort by x + y + z. This page finds the real 'in front of' relations and sorts them with Kahn's algorithm. A sweep on u0 finds the pairs that overlap. The stack starts with the furthest box, so the nearest box is drawn last."

    columns do
      column do
        width "30%"

        list do
          item "An axis that separates a pair gives an edge" do
            at from: 1
          end

          item "The stack starts with the furthest box" do
            at from: 2
          end

          item "A box with no wait left goes on the stack" do
            at from: 3
          end
        end
      end

      column do
        code "js" do
          reveal [1..4, 5..7, 8..17]
          dim true

          text ~S"""
          // a is behind b, or b is behind a, along some axis
          const ab = ax1 <= X0[b] + EPS || ay1 <= Y0[b] + EPS || az1 <= Z0[b] + EPS;
          const ba = X1[b] <= ax0 + EPS || Y1[b] <= ay0 + EPS || Z1[b] <= az0 + EPS;
          if (ab) { PO.efrom[m] = a; PO.eto[m] = b; indeg[b]++; }
          // Kahn's algorithm with a stack, seeded furthest-first
          for (let i = 0; i < n; i++) if (indeg[i] === 0 && softIn[i] === 0) q[qn++] = i;
          q.subarray(0, qn).sort((i, j) => (KEY[j] - KEY[i]) || (i - j));
          for (;;) {
            while (qn) {
              const i = q[--qn];
              done[i] = 1; order[on++] = i;
              for (let k = start[i], end = start[i + 1]; k < end; k++) {
                const j = adj[k];
                if (adjSoft[k]) softIn[j]--; else indeg[j]--;
                if (indeg[j] === 0 && softIn[j] === 0 && !done[j]) q[qn++] = j;
              }
            }
          """
        end
      end
    end
  end

  # ---------------------------------------------------------------- 11
  slide "cycles" do
    heading "When no order is possible"

    notes "Boxes can make a loop of behind relations along different axes. The code walks back until the walk repeats, and releases the member whose broken edges hide the least screen area. D waits behind the cycle, and it is not drawn early."

    handout [1, :last]

    diagram "examples/line4/cycle.svg" do
      width "62%"

      part "edge-ab", at: [from: 2]
      part "edge-bc", at: [from: 2]
      part "edge-ca", at: [from: 2]
      part "cost-ab", at: [from: 3]
      part "cost-bc", at: [from: 3]
      part "cost-ca", at: [from: 3]
      part "waiting", at: [from: 3]

      part "release" do
        at from: 4
        effect :beacon
        speed :slow
      end

      part "node-c" do
        on [from: 4], set: [scale: 1.15]
      end
    end

    quotation "Boxes merely waiting behind a cycle are never drawn early; they follow once it is broken." do
      at from: 4
      by "app.js, line 237"
    end
  end

  # ---------------------------------------------------------------- 12
  slide "render cache" do
    heading "Draw only what changed"

    notes "About 92% of the boxes are the same from one frame to the next. A box that looks the same for 45 frames goes into an offscreen layer. The cache finds such a box by a hash of its look, so the scene code marks nothing as static."

    columns do
      column do
        width "70%"

        diagram "examples/line4/cache.svg" do
          part "layer" do
            at from: 2
          end

          part "live" do
            at from: 3
            effect :blur
          end

          part "rule" do
            at from: 4
            effect :fly_up
          end
        end
      end

      column do
        table do
          header true
          reveal true
          row ["Constant", "Value"]
          row ["T, tile size", "32 px"]
          row ["K, frames before the cache", "45"]
          row ["VOLATILE, a blinking light", "240 frames"]
          row ["LIVE_MAX", "0.5"]
        end
      end
    end
  end

  # ---------------------------------------------------------------- 13
  slide "hash" do
    heading "Small tricks that keep the cache fast"

    notes """
    Step 1: the hash reads the bits of each double through a shared buffer. The comment tells why the state is in local variables only.
    Step 2: mix() rounds the blend factor to twelfths, so a light that pulses has at most 13 colors, and the caches stay small.
    """

    code "js" do
      text ~S"""
      // The running state lives in locals only. Kept in variables shared between functions, a 32-bit value
      // is boxed on every store in browsers whose small integers are 31-bit, which made this three times
      // slower in Chrome than in Node.
      const HF = new Float64Array(6), HI = new Int32Array(HF.buffer);
      const m1 = (h, v) => { h = Math.imul(h ^ v, 0x9e3779b1); return (h << 13) | (h >>> 19); };
      const m2 = (h, v) => { h = Math.imul(h ^ v, 0x85ebca77); return (h << 17) | (h >>> 15); };
      """
    end

    code "js" do
      at from: 2
      effect :fly_up

      text ~S"""
      function mix(a, b, k) {                  // quantised so animated colours keep the cache bounded
        k = Math.round(Math.max(0, Math.min(1, k)) * 12) / 12;
        const ch = i => {
          const va = parseInt(a.slice(i, i + 2), 16), vb = parseInt(b.slice(i, i + 2), 16);
          return Math.round(va + (vb - va) * k).toString(16).padStart(2, '0');
        };
        return '#' + ch(1) + ch(3) + ch(5);
      }
      """
    end
  end

  # ---------------------------------------------------------------- 14
  slide "Part 2" do
    heading "The line"
    template Line4.PartTemplate
    transition :zoom
    notes "Part 2 tells how the simulation moves the product from the infeed to the dock."

    text_area(text: "24 machines, 3 arms, 3 robots, 2 forklifts, 2 people and the visitors")
  end

  # ---------------------------------------------------------------- 15
  slide "frame" do
    heading "One frame"

    notes "The step is the real time of the frame, capped at 50 ms. The simulation divides it into sub-steps of at most 34 ms, so that a fast speed keeps the gates and the pick-ups exact. Pause sets dt to 0, and the page still draws each frame, so the hover still works."

    diagram "examples/line4/loop.svg" do
      width "92%"

      part "a1", at: [from: 2]
      part "b-raw", at: [from: 2]
      part "a2", at: [from: 3]
      part "b-dt", at: [from: 3]
      part "a3", at: [from: 4]

      part "b-sub" do
        at from: 4
        effect :grow
        on 4, state: :alert
      end

      part "a4", at: [from: 5]
      part "b-scene", at: [from: 5]
      part "a5", at: [from: 6]
      part "b-render", at: [from: 6]
      part "a6", at: [from: 7]
      part "b-hud", at: [from: 7]

      part "a7" do
        at from: 8
        effect :wipe
        speed 900
        easing :linear
      end
    end
  end

  # ---------------------------------------------------------------- 16
  slide "main loop" do
    heading "frame(now)"

    notes "There is no fixed time step and no accumulator. At 4× speed and a frame of 50 ms, dt is 0.2 s and n is 6."

    code "js" do
      reveal [1..4, 5..11, 12..17, 18..21]
      dim true

      text ~S"""
      let last = performance.now();
      function frame(now) {
        const rawDt = Math.min(0.05, (now - last) / 1000);
        last = now;
        const dt = paused ? 0 : rawDt * speed;
        if (dt > 0) {
          // sub-step the simulation so fast speeds keep gates and pick-ups exact
          const n = Math.ceil(dt / 0.034);
          for (let i = 0; i < n; i++) {
            updateLine(dt / n);
            for (const a of actors) updateActor(a, dt / n);
          }
        }
        buildScene();
        RC.frame++;
        let order = null;
        if (orderInput.checked || !RC.on || !renderCached()) {
          // … a full frame: clear, drawFloor(), paintOrder(boxes), drawBox() for each box
        }
        // … paint-order labels, plasma discs, speech bubbles, the hover outline
        updateHud();
        requestAnimationFrame(frame);
      """
    end
  end

  # ---------------------------------------------------------------- 17
  slide "plan" do
    heading "From a blank widget to a pallet on the dock"
    handout [1, 4, :last]

    notes """
    Step 1: Rocky puts a blank widget on belt A1.
    Step 2: the paint booth paints it from one of the four tanks.
    Step 3: the dryer sets the paint. Wet paint that waits more than 25 s goes stale.
    Step 4: the fan sends it into one of three lanes, and the packer takes a row of three.
    Step 5: six widgets make a carton.
    Step 6: belt B takes the carton south.
    Step 7: the palletizer stacks 5 cartons in each layer, 4 layers.
    Steps 8 to 10: the wrapper, the labeller and the dock.
    """

    diagram "examples/line4/line.svg" do
      width "100%"

      # A part that hides by a change of its opacity keeps its place. A part
      # with an `at` option goes back to its start while it fades out.
      part "widget" do
        speed :slow
        easing :ease_in_out
        on 2, set: [x: "129.2px"]
        on 3, set: [x: "248.2px"]
        on [from: 4], set: [x: "402.9px"]
        on [from: 2], set: [color: "#e23b3b"]
        on [from: 5], set: [opacity: 0]
      end

      part "carton" do
        at from: 5
        effect :grow
        speed :slow
        on [from: 6], set: [y: "122.4px"]
        on [from: 7], set: [opacity: 0]
      end

      part "pallet" do
        at from: 7
        effect :grow
        speed :slow
        easing :spring
        on 8, set: [x: "163.2px"]
        on 9, set: [x: "234.6px"]
        on [from: 10], set: [x: "319.6px", opacity: 0.3]
      end

      part "st-booth" do
        on 2, state: :alert
      end

      part "st-dryer" do
        on 3, state: :alert
      end

      part "st-packer" do
        on 4..5, state: :alert
      end

      part "belt-b" do
        on 6, state: :alert
      end

      part "st-palletizer" do
        on 7, state: :alert
      end

      part "st-wrapper" do
        on 8, state: :alert
      end

      part "st-labeller" do
        on 9, state: :alert
      end

      part "st-dock" do
        on 10, state: :alert
      end
    end
  end

  # ---------------------------------------------------------------- 18
  slide "stations" do
    heading "Some of the 23 stations"
    notes "Each row is a station of the table in the report. The times are at 1× speed."

    table do
      header true
      reveal true
      dim true
      effect :conveyor
      row ["Station", "Rule"]
      row ["Infeed", "pallets roll at 1.3 u/s; a new blank pallet when fewer than 3 wait"]
      row ["De-strapper", "2.5 s for each pallet; 2 straps go into the strap bin"]
      row ["Rocky and Bullwinkle", "1.50 s for each widget, 2.30 s for each board"]
      row ["Quality tester", "3% of the blanks fail; a pusher sweeps them out in 0.8 s"]
      row ["Paint booth", "a random color from a tank with at least 2% paint"]
      row ["Final tester", "stale paint and 2% at random fail"]
      row ["Packer", "6 widgets in a carton; 4% glue; 4% of the cartons have an open flap"]
      row ["Palletizer", "5 cartons in a layer, 4 layers; 2.57 s for each carton"]
      row ["Wrapper, labeller", "7 s and 2.5 s for each pallet"]
    end
  end

  # ---------------------------------------------------------------- 19
  slide "belt A" do
    heading "Each station holds a widget by a cap"

    notes "A widget moves forward to at most 0.5 units behind the widget in front. A station holds it by a limit on its next position nx, and it adds a reason. The reasons become the status text of the line."

    code "js" do
      reveal [1..3, 4..7, 8..11]
      dim true

      text ~S"""
      const segm = beltSegAt(w.x);
      if (off(segm)) { reasons.add(segm.id + 'Down'); note(w.x); continue; }
      let nx = Math.max(w.x, Math.min(w.x + 1.35 * dt, aheadX - 0.5));   // closes up on the one ahead
      if (w.wet && w.x < DRY_IN && sim.t - w.wetSince > STALE_T) w.stale = true;
      if (w.color && !w.tested2 && nx >= TEST2_X) {                     // the final test, after the dryer
        // …
        else { w.tested2 = true; if (w.stale || Math.random() < FINAL_FAIL) w.reject = w.stale ? 'stale' : 'fail'; }
      }
      if (!w.color && nx >= PAINT_X) {
        // … hold the widget when the dryer is down or blocked
        w.color = canPaint[Math.floor(Math.random() * canPaint.length)];
        w.wet = true; w.wetSince = sim.t; sim.tanks[w.color] -= PAINT_COST;
      """
    end
  end

  # ---------------------------------------------------------------- 20
  slide "arm job" do
    heading "An arm job is a list of waypoints"

    notes "Each step has a target point, a time, an optional grip value and an optional callback. The arm eases each step with smoothstep. The item is reserved when the arm sets off, so the two arms never take the same item. The steps add up to 1.50 s."

    code "js" do
      reveal [2..5, 6..7, 8..11]
      dim true

      text ~S"""
      armRun(arm, [
        { p: [P[0], P[1], P[2] + 0.6], t: 0.26, grip: 1 },
        { p: P, t: 0.18 },
        { p: P, t: 0.1, grip: 0, on: () => {
            pal.pending.delete(k); arm.held = { kind: 'widget', color: null }; } },
        { p: [P[0], P[1], P[2] + 0.65], t: 0.18 },
        { p: [Q[0], Q[1], Q[2] + 0.5], t: 0.34 },
        { p: Q, t: 0.18 },
        { p: Q, t: 0.1, grip: 1, on: () => {
            sim.widgets.unshift({ x: dropX, lane1, color: null, wet: false }); arm.held = null; arm.dropLane = null; } },
        { p: [Q[0], Q[1], Q[2] + 0.6], t: 0.16 },
      ]);
      """
    end
  end

  # ---------------------------------------------------------------- 21
  slide "inverse kinematics" do
    heading "Joint angles from the law of cosines"

    notes "Boxes cannot turn, so each link is a row of small cubes along the bone. The wrist keeps the gripper vertical, so the arm solves for the wrist point W above the target T."

    columns do
      column do
        width "60%"

        diagram "examples/line4/ik.svg" do
          part "reach", at: [from: 2]
          part "angle-phi", at: [from: 2]
          part "angle-alpha", at: [from: 3]

          part "link-1" do
            at from: 3
            effect :fly_down
          end

          part "link-2" do
            at from: 4
            effect :fly_down
          end
        end
      end

      column do
        math ~S"""
        <math display="block"><mtable>
          <mtr><mtd><mi>φ</mi><mo>=</mo><mi>atan2</mi><mo>(</mo><mi>d</mi><mi>z</mi><mo>,</mo><mi>r</mi><mo>)</mo></mtd></mtr>
          <mtr><mtd><mi>α</mi><mo>=</mo><mi>arccos</mi><mfrac><mrow><msubsup><mi>L</mi><mn>1</mn><mn>2</mn></msubsup><mo>+</mo><msup><mi>D</mi><mn>2</mn></msup><mo>−</mo><msubsup><mi>L</mi><mn>2</mn><mn>2</mn></msubsup></mrow><mrow><mn>2</mn><msub><mi>L</mi><mn>1</mn></msub><mi>D</mi></mrow></mfrac></mtd></mtr>
          <mtr><mtd><msub><mi>θ</mi><mn>1</mn></msub><mo>=</mo><mi>φ</mi><mo>+</mo><mi>α</mi></mtd></mtr>
        </mtable></math>
        """ do
          at from: 3
        end
      end
    end

    code "js" do
      at from: 4
      effect :fly_up

      text ~S"""
      const Dd = clamp(Math.hypot(r, dz), 0.3, L1 + L2 - 0.02);
      const phi = Math.atan2(dz, r);
      const alpha = Math.acos(clamp((L1 * L1 + Dd * Dd - L2 * L2) / (2 * L1 * Dd), -1, 1));
      const th1 = phi + alpha;
      """
    end
  end

  # ---------------------------------------------------------------- 22
  slide "output track" do
    heading "A pallet on the output track"

    notes "The state of a pallet names the slot that it moves to. A pill is a wait for a free slot, a dashed box is a move, and a green box is work. On the way, a pallet also stays one pallet length behind the pallet in front."

    diagram "examples/line4/track.svg" do
      width "96%"

      part "g-queue" do
        on 1, state: :alert
      end

      part "g-build" do
        on 2, state: :alert
      end

      part "g-wrap" do
        on 3, state: :alert
      end

      part "g-label" do
        on 4, state: :alert
      end

      part "token" do
        speed :slow
        easing :spring
        on 2, set: [x: "760px"]
        on 3, set: [x: "760px", y: "180px"]
        on 4, set: [x: "190px", y: "180px"]
        on [from: 5], set: [x: "0px", y: "180px", opacity: 0.3]
      end
    end
  end

  # ---------------------------------------------------------------- 23
  slide "track code" do
    heading "The states in a switch"

    notes "move(to) closes up on the pallet in front, and it stops when the track section under the pallet is off. It returns true when the pallet is at its slot."

    code "js" do
      reveal [1..5, 6..8, 9..11, 12..17, 18..24]
      dim true

      text ~S"""
      const move = to => {
        if (!off(trackSegAt(p.x))) p.x = Math.max(p.x, Math.min(to, ahead - 1.35, p.x + 0.9 * dt));
        return p.x >= to;
      };
      switch (p.state) {
        case 'q0': if (!sim.pallets.some(q => q.state === 'toQ1' || q.state === 'q1')) p.state = 'toQ1'; break;
        case 'toQ1': if (move(Q1_X)) p.state = 'q1'; break;
        case 'q1': if (!sim.pallets.some(q => q.state === 'toPZ' || q.state === 'pz' || q.state === 'full')) p.state = 'toPZ'; break;
        case 'toPZ': if (move(PZ_X)) p.state = 'pz'; break;
        case 'pz': if (p.cartons.length >= CARTONS_PER_PALLET) p.state = 'full'; break;
        case 'full': if (!sim.pallets.some(q => q.state === 'toWR' || q.state === 'wr' || q.state === 'wrapped')) p.state = 'toWR'; break;
        case 'toWR': if (move(WR_X)) { p.state = 'wr'; p.wrap = 0; } break;
        case 'wr':
          if (!off(machines.wrapper) && sim.film > 0) { p.wrap += dt / 7; /* … the film and the arm */ }
          if (p.wrap >= 1) { p.wrap = 1; p.state = 'wrapped'; }
          break;
        case 'wrapped': if (!sim.pallets.some(q => q.state === 'toLB' || q.state === 'lb')) p.state = 'toLB'; break;
        case 'toLB': if (move(LB_X)) { p.state = 'lb'; p.label = 0; } break;
        case 'lb':
          if (!off(machines.labeller) && sim.labels >= LABEL_COST && sim.toner >= TONER_COST) p.label += dt / 2.5;
          if (p.label >= 1) { p.label = 1; p.state = 'out'; sim.counts.pallets++; /* … */ }
          break;
        case 'out': /* … roll on, fade out and leave at OUT_X */ break;
      }
      """
    end
  end

  # ---------------------------------------------------------------- 24
  slide "Part 3" do
    heading "Trouble"
    template Line4.PartTemplate
    transition :zoom
    notes "Part 3 tells what happens when a machine stops, and who comes to repair it."

    text_area(text: "Faults, power, people, robots and a check for impossible moves")
  end

  # ---------------------------------------------------------------- 25
  slide "faults" do
    heading "Three levels of fault"

    notes "Each machine gets its next fault time from an exponential distribution. No new fault starts while two machines are down. The switchboard and the MCC never get a level 1 fault."

    diagram "examples/line4/faults.svg" do
      width "88%"

      part "lvl-1" do
        at from: 1
        effect :fly_right
      end

      part "lvl-2" do
        at from: 2
        effect :fly_right
      end

      part "lvl-3" do
        at from: 3
        effect :fly_right
        on 4, state: :alert
      end
    end

    math ~S"""
    <math display="block"><mrow><mi>gap</mi><mo>=</mo><mo>−</mo><mi>ln</mi><mo>(</mo><mn>1</mn><mo>−</mo><mi>r</mi><mo>)</mo><mo>·</mo><mn>900</mn><mtext> s</mtext><mo>·</mo><mn>2</mn></mrow></math>
    """ do
      at from: 4
      effect :wipe
    end
  end

  # ---------------------------------------------------------------- 26
  slide "raiseFault" do
    heading "A fault, and the power behind it"

    notes """
    The level comes from the probabilities of LEVELS. The repair time is random inside the band of the level.
    off() is the rule that each station reads: a machine is off when it is down, or when it is not electrical and the MCC has no supply.
    """

    code "js" do
      reveal [1..5, 6..10, 11..15]
      dim true

      text ~S"""
      const LEVELS = [
        { p: 0.5, min: 3, max: 8 },
        { p: 0.35, min: 8, max: 20 },
        { p: 0.15, min: 20, max: 45 },
      ];
      function raiseFault(m, level) {
        const u = Math.random();
        m.level = level || (u < LEVELS[0].p ? 1
          : u < LEVELS[0].p + LEVELS[1].p ? 2 : 3);
        if (m.electrical && m.level === 1) m.level = Math.random() < 0.7 ? 2 : 3;
        const band = LEVELS[m.level - 1];
        m.repairTime = band.min + Math.random() * (band.max - band.min);
        if (m.level === 3) m.callAt = sim.t + 15 + Math.random() * 25;
        // …
      }
      """
    end

    code "js" do
      at from: 4
      effect :fly_left

      text ~S"""
      const powerOut = () => machines.switchboard.down ? machines.switchboard : null;
      const mccOut = () => !!powerOut() || machines.mcc.down;
      const off = m => m.down || (!m.electrical && mccOut());
      """
    end

    text_area do
      text "Each station asks <code>off()</code>."
      at from: 5
      effect :fade
      speed :fast
      on [from: 5], set: [color: "#e8b83a"]
    end
  end

  # ---------------------------------------------------------------- 27
  slide "people" do
    heading "Two people, a break room and a mood"

    notes "The OEE of the last ten minutes moves the mood of both people. A tired person more probably takes coffee. A person in a bad mood more probably takes a biscuit. About a third take sugar, and sugar needs a spoon."

    columns do
      column do
        width "32%"

        list do
          reveal true

          item "The operator and the technician" do
            list do
              item "tired from 0 to 100"
              item "mood from 0 to 100"
            end
          end

          item "A break at tired 80 or mood 25"
          item "Coffee or tea, a biscuit, sugar and a spoon"
        end
      end

      column do
        code "js" do
          reveal [1..3, 4..6, 7..8]
          dim true

          text ~S"""
          let dm = 0.04 * oeeDrift;               // both care how the line is doing
          dm += (h.mood < 60 ? 0.03 : -0.02);     // slow drift back toward a middling mood
          if (h.op && h.task) dm -= 0.08;         // doing the robots' work
          let drink = Math.random() < 0.8
            ? (Math.random() < a.tired / 100 ? 'coffee' : 'tea') : null;
          const biscuit = Math.random() < 0.9 * (100 - a.mood) / 100;
          // about a third take sugar, if there is any — which means finding a spoon
          let sugar = drink !== null && Math.random() < 0.35 && br.sugar > 0;
          """
        end
      end
    end
  end

  # ---------------------------------------------------------------- 28
  slide "physics check" do
    heading "A monitor, not a constraint"

    notes "The check logs each mover that overlaps something solid. At the first tick, it also walks each route edge of the floor and logs an edge that goes through an obstacle. A headless run can then report each layout mistake."

    quotation "Nothing here stops a mover doing something impossible; this just notices when one does." do
      by "app.js, line 4069"
      effect :blur
      speed :slow
    end

    code "js" do
      at from: 2
      effect :fly_up

      text ~S"""
      const tol = 0.12, v = sim.viol, t = sim.t;
      const hits = (x0, y0, x1, y1, o) =>
        x1 > o.x0 + tol && x0 < o.x1 - tol && y1 > o.y0 + tol && y0 < o.y1 - tol;
      for (const f of forklifts) {
        const jobs = [f.task, (f.alc || f.charging || f.x < WX + 2.2) ? 'charge' : null].filter(Boolean);
        for (const o of OBST)
          if (hits(f.x - 0.55, f.y - 0.55, f.x + 0.55, f.y + 0.55, o) && !jobs.some(j => o.allow.includes(j)))
            note(f, o.name, f.x, f.y);
      }
      """
    end
  end

  # ---------------------------------------------------------------- 29
  slide "Part 4" do
    heading "The numbers and the small things"
    template Line4.PartTemplate
    transition :zoom
    notes "Part 4 tells how the page measures the line, and what the page gets wrong."

    text_area(text: "OEE, the hover, the font of the speech bubbles and a robot dance")
  end

  # ---------------------------------------------------------------- 30
  slide "OEE" do
    heading "OEE = Availability × Performance × Quality"

    notes "The bars are an example. A stop counts against Availability only after 60 s. A shorter gap is a Performance loss. Only stale paint counts against Quality."

    diagram "examples/line4/oee.svg" do
      width "90%"

      part "bar-run" do
        at from: 2
        effect :wipe
        speed :slow
        easing :linear
      end

      part "bar-ideal" do
        at from: 3
        effect :wipe
        speed :slow
        easing :linear
      end

      part "bar-good" do
        at from: 4
        effect :wipe
        speed :slow
        easing :linear
      end

      part "product" do
        at from: 5
        effect :beacon
        speed :slow
      end
    end
  end

  # ---------------------------------------------------------------- 31
  slide "oeeFigures" do
    heading "Two samples, one window"

    notes "updateOEE() takes one sample each simulated second. The rolling figure uses the oldest sample inside 600 s and the newest sample. P has no cap, so a depalletizer rate above 1× gives more than 100%."

    code "js" do
      reveal [1..3, 4..5, 6..8]
      dim true

      text ~S"""
      function oeeFigures(from, to) {                // from/to are samples
        const planned = to.t - from.t;
        if (planned < 30) return null;
        const run = Math.max(0, planned - (to.stop - from.stop));
        const total = to.total - from.total, scrap = to.scrap - from.scrap;
        const A = run / planned;
        const P = run > 0 ? IDEAL_CYCLE * total / run : 0;   // not capped
        const Q = total > 0 ? Math.max(0, total - scrap) / total : 1;
        return { A, P, Q, oee: A * P * Q };
      }
      """
    end

    math ~S"""
    <math display="block"><mrow>
      <mi>OEE</mi><mo>=</mo>
      <mfrac><mi>run</mi><mi>planned</mi></mfrac><mo>×</mo>
      <mfrac><mrow><mn>0.78</mn><mtext> s</mtext><mo>×</mo><mi>painted</mi></mrow><mi>run</mi></mfrac><mo>×</mo>
      <mfrac><mrow><mi>painted</mi><mo>−</mo><mi>stale</mi></mrow><mi>painted</mi></mfrac>
    </mrow></math>
    """ do
      at from: 4
      effect :grow
      on 4, set: [color: "#e8b83a"]
    end
  end

  # ---------------------------------------------------------------- 32
  slide "small things" do
    heading "Details that each need a slide"
    auto_reveal true
    effect :fly_up
    notes "Each box comes in at its own step, because the slide has the auto_reveal option."

    text_box do
      text_area(text: "<b>Speech bubbles</b> use a 5 × 7 block font, drawn with fillRect.")
    end

    text_box do
      text_area(
        text: "<b>The robot dance</b> snaps to each pose in the first quarter of its beat."
      )
    end

    text_box do
      text_area(
        text: "<b>The plasma disc</b> is a true circle, with an even-odd clip for each occluder."
      )
    end

    text_box do
      text_area(
        text: "<b>The lightning sign</b> is one tall box for each run of cells in a column."
      )
    end
  end

  # ---------------------------------------------------------------- 33
  slide "dance" do
    heading "The robot"

    notes "Fourteen beats at 75 bpm. The pose of each beat is reached in the first quarter of the beat, and then it is held."

    code "js" do
      text ~S"""
      // Each pose is snapped to in the first quarter of its beat and then held locked,
      // which is what makes it read as "the robot" rather than just moving about.
      const DANCE_BPS = 1.25, DANCE_LEN = 14 / DANCE_BPS;
      function dancePose(a) {
        const t = a.dance.t, beat = Math.floor(t * DANCE_BPS),
          f = t * DANCE_BPS - beat, k = smooth(Math.min(1, f / 0.25));
        // …
        const cur = poseAt(beat), prev = poseAt(Math.max(0, beat - 1));
        const L = key => lerp(prev[key], cur[key], k);
        return { shL: L('shL'), elL: L('elL'), shR: L('shR'), elR: L('elR'),
          squat: L('squat'), face: cur.face };
      }
      """

      on 2, set: [scale: 1.04]
      on 3, set: [rotate: "-1.5deg"]
      on 4, set: [rotate: "1.5deg"]
    end
  end

  # ---------------------------------------------------------------- 34
  slide "accessibility" do
    heading "A canvas with words"

    notes "The canvas is an image with a long label. The status panel is a list of outputs. The page starts paused for a user who asks for reduced motion, but it reads that setting at load only."

    table do
      header true
      reveal true
      row ["Part", "Markup"]
      row ["The canvas", "role=\"img\" and a long aria-label"]
      row ["The status panel", "an aside with a dl of output elements"]
      row ["The paint tanks", "role=\"meter\" with aria-valuenow"]
      row ["The hover text", "an output with aria-live=\"polite\""]
      row ["The pause button", "aria-pressed; the Space key toggles it"]

      row ["Reduced motion", "the page starts paused, at load only"] do
        on 7, state: :dim
      end
    end
  end

  # ---------------------------------------------------------------- 35
  slide "mistakes" do
    heading "What the page gets wrong"

    notes "Each row is a place where a label or a comment does not agree with the code. None of them changes what you see."

    table do
      header true
      row ["Where", "It says", "The code does"]

      row ["The canvas label", "four widgets to a carton", "six, CARTON_CAP = 6"] do
        on 2, state: :lit
      end

      row ["The canvas label", "one unloading arm", "two: Rocky and Bullwinkle"] do
        on 3, state: :lit
      end

      row ["Line 4180, watchdog", "reads bp", "bp is not declared; the branch cannot run"] do
        on 4, state: :lit
      end

      row [
        "Lines 98–101",
        "cycles fall back to a depth key",
        "it breaks a cycle by the least area"
      ] do
        on 5, state: :lit
      end

      row ["The sign comment", "7 × 11 cells", "ROWS has 10 entries"] do
        on 6, state: :lit
      end
    end

    spacer()

    text_area do
      text "Math.random() runs 55 times, with no seed. Each load of the page is a new day."
      at from: 7
      effect :blur
    end
  end

  # ---------------------------------------------------------------- 36
  slide "this deck" do
    heading "This deck, in the DSL of Expresso"

    notes "The deck is examples/line4/line4.exs in the repository of Expresso. This slide shows the plan slide, with fewer parts."

    code "elixir" do
      reveal [1..2, 3..7, 8..12, 13..14]
      dim true

      text ~S"""
      slide "plan" do
        heading "From a blank widget to a pallet on the dock"
        diagram "examples/line4/line.svg" do
          part "widget" do
            on 2, set: [x: "129.2px"]
            on [from: 2], set: [color: "#e23b3b"]
          end
          part "pallet" do
            at from: 7
            effect :grow
            on [from: 10], set: [x: "319.6px", opacity: 0.3]
          end
        end
      end
      """
    end
  end

  # ---------------------------------------------------------------- 37
  slide "The end" do
    heading "Open the page, and watch Line 4 run"
    template Line4.PartTemplate
    transition :fade
    notes "Click the picture to go back to the route."

    image "examples/line4/line4.png" do
      alt "Line 4. Go back to the route through the factory"
      width "48%"
      goto slide: 2
    end

    text_area(text: "rellen.github.io/iso-factories/line-4")
  end
end

Line4.Deck
