<!-- This file is the result of the prompt in overlay-class-prompt.md, from a
deep-research tool on 2026-09-13. The text is that of the tool, and the prose style
of CLAUDE.md does not apply to it. docs/overlays.md records the decision that follows
from it. -->

# Applying a Named Group of Declarations to an Element Conditionally on a Step Index — in Pure CSS

## TL;DR
- **There is no pure-CSS mechanism, shipped or drafted, that applies an author-*named* group of declarations (like the theme's opaque `.alert`) to the *same* element conditionally, at your committed browser floor (Chrome 85 / Safari 16.4 / Firefox 128).** CSS can select an element and set properties or substitute values; it cannot say "apply the declarations of `.alert` here" without either knowing those declarations (`@mixin`/`@apply`, not shipped anywhere) or selecting by custom-property value (`if()`, Chrome-only; style queries, descendant-only and above your floor).
- **The floor-compatible, pure-CSS answer is your Option 1, reframed: compile `class: "alert"` to a step-gated custom property and have the theme express `.alert` via `var()`.** This reuses the exact machinery your `set:` form already uses and proves works. Its only real cost is that theme authors write `background: var(--alert-bg, …)` instead of a bare `.alert { … }` block.
- **Option 2 (JS class toggle) is a legitimate, low-cost fallback, not a compromise of your animation model** — the "one render, CSS computes intermediate states" invariant is preserved; only the weaker "script writes exactly one attribute" purity claim is broken. Rank: **Option 1 (reframed) first; Option 2 as the pragmatic escape hatch for truly opaque theme classes; `if()` as a Chrome-only progressive enhancement; style queries only if you accept a much higher floor.**

## Key Findings

1. **`if()` with `style()` conditions does exactly what you asked — an element branches on *its own* custom property — but it is Chromium-only and below your cross-browser floor.** It shipped in Chrome/Edge 137 (stable May 20/27, 2025); it is not in Firefox or Safari as of September 2026, and Safari has it only on a roadmap.
2. **Style queries (`@container style()`) are descendant-only by deliberate design; an element cannot query itself.** They are supported in Chrome/Edge 111, Safari 18, [moderncsstools](https://moderncsstools.com/guides/container-queries/) and Firefox 151 — but Safari 18 and Firefox 151 are well *above* your committed floor, so adopting them raises the floor by roughly 1.5–2 years.
3. **`@mixin`/`@apply` — the one feature that would literally "apply a named block of declarations" — is not shipped in any browser and is the least-baked part of its spec.** Even if it shipped, it would not solve your blocker, because `@apply --alert` inlines declarations *you* wrote, not the theme's opaque `.alert`.
4. **Typed `attr()` can drive a property value from a data attribute, but it cannot apply a class's declarations.** It is useful plumbing (Chrome 133, Feb 2025; Firefox 155), not a solution to the blocker.
5. **Every mainstream framework — reveal.js, impress.js, Slidev, Marp, Spectacle — implements per-fragment state with JavaScript class/state toggling, not pure CSS.** Your `data-step` + attribute-selector approach is actually *purer* than all of them.

## Details

### Mechanism × engine × version × spec status

| Mechanism | Chrome/Edge | Safari | Firefox | Spec status | Solves the blocker? |
|---|---|---|---|---|---|
| **`if()` + `style()`** (branch a declaration on the element's own custom property) | 137 (May 2025) | Not shipped (roadmap 2026–27) | Not shipped (bug 1981485) | CSS Values & Units L5, editor's draft (`#if-notation`) | **Yes, functionally** — but Chromium-only, below floor |
| **`@container style()`** (query custom property) | 111 (2023) | 18.0 (Sept 2024) | 151 (~mid-2026) | CSS Containment L3 | Partially — descendant-only; can't style the element itself; raises floor |
| **`@function`** | 139 (Aug 5, 2025) | Not shipped (TP 226+) | Not shipped (bug 1953973) | CSS Functions & Mixins L1, FPWD 15 May 2025 | No — returns a *value*, not style rules |
| **`@mixin` / `@apply`** | Canary behind flag only | No | No | Same module; "mixins expected to be defined later" | No — inlines declarations you wrote, not the theme's opaque class |
| **Typed `attr()`** | 133 (Feb 2025) | TP only, not stable | 155 (late Aug 2026) | CSS Values & Units L5 | No — drives a value, not a named declaration group |
| **`revert-layer` / cascade layers** | Broadly supported | Broadly supported | Broadly supported | CSS Cascade L5 | No — can't gate a layer on an attribute at author time without knowing selectors |
| **`:state()` / `@scope` / `:has()` / `:where()`** | Supported (varies) | Supported (varies) | `@scope` in 146 | Various | No — selection tricks; none apply an opaque named declaration set |

Your committed floor: **Chrome 85, Safari 16.4, Firefox 128 (July 2024 baseline)** — chosen for `@property`, which became Baseline "Newly available" in July 2024.

### 1a. `if()` — the closest fit, but Chromium-only

`if()` is the one shipped feature that lets a declaration on an element branch on a custom property *set on that same element*. MDN states the key advantage plainly: using style queries inside `if()` "has an advantage over `@container` queries — you can target an element with styles directly, based on whether a custom property is set on it, rather than having to check set styles on a container parent element." That is precisely your need: `--alert: 1` on step 3, and a theme rule `background-color: if(style(--alert: 1): var(--alert-bg); else: transparent)`.

Shipping reality as of September 2026:
- **Chrome/Edge 137**, stable May 20, 2025 (developer.chrome.com gives May 27 for the general stable-channel post; CSS-Tricks, June 24, 2025: "the CSS `if()` function officially shipped in Chrome 137"). It is part of the draft CSS Values and Units Module Level 5 and, per MDN, has "limited availability" and "is not Baseline because it does not work in some of the most widely-used browsers." [mozilla](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Values/if)
- **Firefox: not shipped** — caniuse shows no support through the current release (155/156–158), tracked in bug 1981485.
- **Safari: not shipped** — no stable or Technology Preview support through Safari 26.6/TP; described as "on the roadmap for 2026–2027." As one independent tracker (blog.simon-hu.org, Nov 20 2025) put it: "not yet supported by Safari and Firefox! … Chrome/Edge 137+ and Opera 121+."

**Transition behaviour (critical for your design):** A targeted investigation confirmed the mechanics. `if()` is an *arbitrary substitution function resolved at computed-value time* (like `var()`), per the CSS Values 5 editor's draft — it has no animation type of its own. The condition flip itself is discrete (a custom property is either `1` or not — there is no "halfway"). **But the property that receives the resulting value transitions normally** if (a) a `transition` is declared on it, (b) its animation type is interpolable ("by computed value" per the CSS Transitions "transitionable" rule), and (c) both branch values interpolate. This is exactly the same model your `set:` form already relies on with `@property`-registered custom properties. So `if()` is *compatible* with your "CSS computes intermediate states" model — you just cannot ease *across* the boolean threshold, only the resulting interpolable value. (There is an open CSSWG request, issue #6581, to interpolate across query states; it does not exist natively today. No WPT test or release note asserts "if() output is transitionable" in one line, so verify empirically before relying on it.)

**Verdict:** `if()` is the technically correct pure-CSS answer, but it fails your cross-browser floor by two entire engines. Viable only as a Chrome-only enhancement behind `@supports`.

### 1b. Style queries — descendant-only, and they raise your floor

The descendant-only limitation is confirmed repeatedly and is deliberate, not an oversight. MDN and the OddBird explainer both note that although *any* element can be a style container without setting `container-type` (there is no circular-dependency risk for style, unlike size — "there is already no way in CSS for descendant styles to have an impact on the computed styles of an ancestor"), the query still applies to **descendants of the container, never the container itself**. To style the element on the basis of its own custom property you would have to wrap it in a container div and style a child — awkward for arbitrary overlay elements and adds markup.

Shipping status:
- Style queries on custom properties: **Chrome/Edge 111** (2023); **Safari 18.0** (Sept 2024); **Firefox 151** (per caniuse, first supported at 151; Firefox for Android 152). Base container-query support (for context) is Safari 16 / Firefox 110.
- Safari 18 is *above* your Safari 16.4 floor; Firefox 151 is far above your Firefox 128 floor. Adopting style queries would raise your effective floor by roughly 1.5 years (Safari) and about 2 years (Firefox) — directly contradicting the design's stated commitment.

**Verdict:** Style queries could work only with a wrapper element *and* only if you abandon the committed floor. Not recommended.

### 1c. `@mixin` / `@apply` and `@function` — the "apply a named block" dream, unshipped and insufficient

The CSS Functions and Mixins Module reached First Public Working Draft on **15 May 2025** (editor's draft updated 21 Oct 2025). Its two halves have very different maturity:
- **`@function`** (returns a value) shipped in **Chrome/Edge 139**, released **August 5, 2025** (Edge 139 on Aug 7); not in Firefox or Safari (vendor positions unknown). It returns a *value*, not a block of style rules — it cannot apply `.alert`.
- **`@mixin` / `@apply`** (returns *style rules*) is **not supported in any browser**; MDN states flatly: "Currently, only CSS custom functions have browser support. CSS mixins are not currently supported in any browser." [mozilla](https://developer.mozilla.org/en-US/docs/Web/CSS/Guides/Custom_functions_and_mixins) The editor's draft warns the mixin feature "is experimental and under active development, and is much less stable than `@function`. Expect things to change frequently." The spec itself notes it "only defines custom functions" at this time and "It is expected that it will define 'mixins' later."

Even in a hypothetical future where `@mixin`/`@apply` ships everywhere, it would **not** solve your blocker. `@apply --alert` substitutes the declarations of a mixin *you define* (`@mixin --alert { … }`). It does not, and cannot, reach into the theme's opaque `.alert` class and pull its declarations. Your constraint — "the generator doesn't know `.alert`'s declarations and must not parse the theme" — is fundamentally incompatible with any inlining mechanism. State this plainly: **the feature that superficially matches the request would still require exactly the thing you've ruled out.**

The old `@apply` rule (Chrome 51-era, behind a flag) was removed years ago and is dead, as you noted.

### 1d. Typed `attr()` — useful plumbing, not a solution

Typed `attr()` (CSS Values & Units L5) lets a data attribute feed a typed value into any property: `--x: attr(data-x type(<length>), 0px)`. It shipped in **Chrome/Edge 133** (Feb 2025, per Chrome 133 release notes: it "allows types besides… use in all CSS properties") and **Firefox 155** [mozilla](https://bugzilla.mozilla.org/show_bug.cgi?id=2038940) (late August 2026; present but off by default in 152–154, per bug 2038940); Safari has it in Technology Preview only, not stable. It could let your generator drive per-step numeric properties directly from attributes instead of emitting per-step rules — a genuine simplification for the `set:` form — but it cannot apply the declarations of a named class. It does not touch the blocker.

### 1e. Cascade layers / `revert-layer`

`revert-layer` rolls a property back to the value in a lower cascade layer, and cascade layers are broadly supported. But there is no way to gate a whole layer on an element's attribute at authoring time: as the OddBird cascade-layers polyfill notes, "it is not possible in the build step to know which selectors will apply to any given element." [oddbird](https://www.oddbird.net/2022/06/21/cascade-layers-polyfill/) You cannot write "activate the theme's `.alert` layer only on step 3 for this element" without a selector hook — which returns you to the same problem. Not a solution.

### 2. The "theme authors against an attribute/property" reframing — the recommended contract

The least-surprising, floor-compatible contract is: **`class: "alert"` compiles to the same custom-property assignment your `set:` form already emits, and the theme expresses its alert appearance through `var()` with sensible fallbacks.** This keeps everything in the machinery you have already proven works, requires no new browser features, and transitions correctly because the values land in `@property`-registered custom properties.

**Before (what authors wish they could write; requires the impossible feature):**

```css
/* Theme owns .alert — generator must not read it */
.alert {
  background: #fee;
  color: #900;
  outline: 2px solid #900;
}
```
```
# DSL
on ~o"3", class: "alert"   # "apply .alert on step 3" — the blocker
```

**After (recommended pure-CSS contract):** The theme defines its alert *once*, keyed on custom properties, and applies it to the element itself (not a descendant):

```css
/* Theme, authored once. These are the element's OWN properties. */
[data-el] {
  background: var(--alert-bg, transparent);
  color:      var(--alert-fg, inherit);
  outline:    var(--alert-outline, none);
  transition: background 200ms, color 200ms, outline-color 200ms;
}

/* The theme's "alert" look, expressed as a named group of custom-property values */
@property --alert-bg { syntax: "<color>"; inherits: false; initial-value: transparent; }
/* …register the others similarly so they transition and have real fallbacks… */
```

The generator emits, for step 3, exactly the kind of rule it already emits for `set:`:

```css
section[data-step="3"] [data-el="s2-e1"] {
  --alert-bg: #fee;
  --alert-fg: #900;
  --alert-outline: 2px solid #900;
}
```

**What it costs the theme author versus plain class names:** they can no longer drop an opaque `.alert { … }` block and have it "just work" per step. They must (a) decide which properties an overlay state can touch and expose them as custom properties, and (b) write `var(--token, fallback)` in the element's base rule. In exchange they get: pure CSS at the floor, automatic transitions, and a single source of truth. For a *slide theme* — a deliberately small, closed vocabulary of states (alert, dim, highlight) — this is a modest, one-time cost and arguably better design than scattering opaque classes.

A middle path that keeps bare class-*name* ergonomics for authors: the DSL can accept `class: "alert"` and the *theme* can publish a companion convention — e.g. the generator sets a boolean custom property `--alert: 1` and the theme writes its alert rule using `if()` **as a Chrome-only enhancement** with a `var()`-driven fallback for the floor. But because `if()` is Chromium-only, the robust cross-browser primitive remains the `var()` token approach above.

### 3. Prior art — how the frameworks actually do it

**None of the major tools implement per-fragment state in pure CSS. All use JavaScript (or a framework runtime) to toggle classes or component state; CSS then handles only the transition.** This is strong evidence that your pure-CSS `data-step` approach is genuinely novel and that the class problem is inherent, not a gap in your design.

- **reveal.js** — fragments start hidden (`opacity: 0; visibility: hidden`) via CSS. The `fragments.js` controller *adds and removes* the `.visible` and `.current-fragment` classes as you navigate (state table: Hidden `.fragment` → Visible `.fragment.visible` → Current `.fragment.visible.current-fragment`, per `js/controllers/fragments.js`). Custom effects are authored as `.fragment.effectname` / `.fragment.effectname.visible`. Pure JS class toggling; CSS only styles the states.
- **impress.js** — the runtime adds `.future` / `.present` / `.past` classes (and `.active`, and a body-level `impress-on-*` class) [github](https://github.com/East196/impress-show) on step enter/leave via `impress:stepenter` / `impress:stepleave` events; [github](https://github.com/boyofgreen/impress.js) CSS transitions animate between them. Explicitly JS-driven classes.
- **Slidev** — Vue directives (`v-click`, `v-after`, `v-clicks`, `v-switch`) attach `slidev-vclick-target`, `slidev-vclick-hidden`, [deepwiki](https://deepwiki.com/slidevjs/slidev/4.2-animation-and-transitions) `slidev-vclick-current`, and `slidev-vclick-prior` classes; the default is a `transition: opacity 100ms ease`. Runtime (Vue reactivity) class toggling.
- **Marp / Marpit** — the `*` list marker compiles to elements carrying a `data-marpit-fragment` attribute; the bespoke HTML output reveals them one at a time via its runtime. Attribute-tagged, JS-revealed. (Notably, Marpit refuses implicit DOM manipulation to avoid breaking theme CSS — a philosophy close to yours.)
- **Spectacle** — React: `<Appear priority={n}>` and the `useSteps` hook drive `activeStyle` / `inactiveStyle`; [github](https://github.com/FormidableLabs/spectacle/commit/4b6084c339b40b131a16775dd0836f4639493766) state lives in React, not CSS.

**Documented pitfalls relevant to you:**
- **Print / handout modes.** reveal.js prints each fragment step as a *separate* page by default; `pdfSeparateFragments: false` collapses them to one page showing all fragments in their visible states. Because your renderer already writes *every* state into the document, your print story is actually simpler — you can print the final (all-revealed) state or one page per step from the same DOM, without re-rendering.
- **`prefers-reduced-motion`.** The CSSWG's standing position (per public-css-archive discussion, 2020) is that browsers "don't know enough about the effects" to auto-neutralize author animations and that authors should provide reduced-motion alternatives. Because you animate with `transition`, wrap the transition declarations in `@media (prefers-reduced-motion: no-preference)` (or zero them under `reduce`) so steps snap instantly for users who ask for that.
- **View transitions (`document.startViewTransition`).** This is a JS API and orthogonal to your model; it is not required and would reintroduce a scripted timeline. Skip it. (Note the incidental Safari-only trick that `view-transition-name: auto` uses an element's `id` — irrelevant unless you opt into view transitions.)
- **Flicker on element replacement** (seen in Slidev issue #1810) occurs when elements are *replaced* rather than *restyled*. [github](https://github.com/slidevjs/slidev/issues/1810) Your model keeps element identity stable and only changes properties/classes, which avoids this class of bug.

### 4. A fair costing of Option 2 (JS class toggling)

Your renderer emits `data-class="3:alert 5:dim"`; a ~10-line script adds/removes classes on step change. Honest assessment:

- **Interaction with transitions when the class changes in the same frame as `data-step`.** If the script mutates `data-step` *and* toggles the classes inside the **same synchronous event handler**, the browser coalesces all style/layout work into a single frame. The "before-change style" and "after-change style" are computed once, so transitions fire exactly once with no intermediate frame. This is well-defined behaviour, not luck.
- **Atomicity.** The only way to get a glitch is to split the two mutations across separate tasks/frames (e.g. `data-step` now, classes after a `setTimeout`/`await`). Keep both writes in one synchronous function and atomicity is guaranteed by frame coalescing.
- **`requestAnimationFrame` batching.** Not needed for step navigation. rAF is only necessary when you must force a reflow *between* removing and re-adding a class to *restart* a transition on the same element; step changes don't require that.
- **Flash on initial load (FOUC).** This is the real risk. If classes are applied by JS only after first paint, the initial step can flash unstyled. Mitigations: (a) have the renderer write the initial step's classes into the static HTML (you already write every state, so this is cheap), or (b) run the class-init in a synchronous `<script>` in `<head>` before first paint. Either removes the flash.
- **Accessibility.** Class toggling is a11y-neutral in itself. The relevant concern — that not-yet-revealed content should be hidden from assistive tech — applies equally to your pure-CSS approach and is solved the same way (e.g. `visibility: hidden` / `display: none` on hidden states, which also removes them from the accessibility tree). No new a11y cost.
- **Does it compromise the model?** No, not in substance. The document is still rendered **once**; CSS still computes every intermediate frame via `transition`; element identity is unchanged so transitions keep working (as you noted). What breaks is only the narrow purity claim that "the script writes exactly one attribute." The deeper invariant — *no second render, no scripted timeline, CSS owns the tweening* — is fully intact. Toggling a class is the same *kind* of discrete boolean write as toggling `data-step`; it is an implementation detail, not an architectural regression.

### 5. Recommendation and ranking

**Ranked options given the Chrome 85 / Safari 16.4 / Firefox 128 floor:**

1. **Option 1, reframed (theme authors against custom properties): recommended default.** Pure CSS, works at the floor today, reuses the exact `set:`/`@property` machinery you've already validated, and transitions correctly. Cost: theme authors expose overlay-mutable properties as `var()` tokens instead of dropping opaque classes. For a closed theme vocabulary this is a small, one-time, arguably-cleaner cost.
2. **Option 2 (JS class toggle): the pragmatic escape hatch** for the specific case where a theme genuinely ships an opaque `.alert` you must not touch and cannot re-express as tokens. ~10 lines, no architectural compromise if writes are atomic and the initial state is server-rendered. Use it as a bounded, opt-in fallback, not the primary path.
3. **`if()` as a Chrome-only progressive enhancement.** Where Chromium-only rendering is acceptable, or layered behind `@supports` with a `var()`-token fallback, `if()` gives you exactly the element-self-styling-from-its-own-custom-property behaviour the blocker describes. Do not rely on it cross-browser: it is absent from Firefox and Safari as of September 2026, i.e. **two engines and an unknown number of years short of your floor.**
4. **Style queries: only if you consciously raise the floor.** They need a wrapper (descendant-only) *and* push your floor up to Safari 18 / Firefox 151 — roughly 1.5–2 years above your commitment. Not recommended given your stated constraints.

**Progressive-enhancement pattern**, if you want the best of both: ship the `var()`-token contract as the universal baseline; detect `if()` and enhance only where present:

```css
/* Baseline: works at the floor, Option 1 */
[data-el] { background: var(--alert-bg, transparent); }

/* Enhancement: only in engines with if() */
@supports (background: if(style(--x: 1): red; else: blue)) {
  /* optionally richer per-element conditional logic */
}
```

A JS fallback should be triggered *only* when the pure-CSS route cannot express the needed state — in practice that is rare if you adopt the token contract, so most decks would ship zero JavaScript for overlays.

**Benchmarks that would change this recommendation:**
- If **`if()` reaches Baseline** (shipped in Firefox *and* Safari stable, with dates at or below your floor), promote it to the primary mechanism for `class:`-style per-step states and retire the JS fallback entirely.
- If **`@mixin`/`@apply` ships in all three engines** *and* you relax the "must not parse the theme" rule so the generator can define mixins, revisit — but note this still cannot reference a theme's opaque class, so it likely never fully replaces the token contract.
- If you decide to **raise the floor to Safari 18 / Firefox 151+**, style queries become viable and you can drop the wrapper-free `if()` requirement.

## Caveats
- **Browser-version specifics are fast-moving and version-dependent.** `if()` Chrome-137 status (May 2025) and its continued absence from Firefox/Safari are confirmed via caniuse and MDN as of September 2026, but Safari's "2026–2027 roadmap" is a projection, not a shipped fact — treat it as such.
- **The claim that `if()` output transitions smoothly rests on spec architecture (arbitrary substitution function + the CSS Transitions "transitionable" rule), corroborated by MDN and web.dev, but no single WPT test or release note asserts "if() output is transitionable" in one line.** If you build on `if()`, empirically verify the interpolable-destination case in Chrome 137+ before relying on it.
- **Exact Firefox release dates for style queries (151) are approximate** — inferred from Firefox's roughly monthly cadence around the September 2026 releases (155). Confirm against Mozilla release notes before making floor decisions.
- **`@function` shipped in Chrome 139 on August 5, 2025** (an earlier draft of this report said July; the enricher corrected it). **`@mixin`/`@apply` is explicitly unstable** per its own editor's draft; any status here could change quickly, though "shipped in a stable browser" is not imminent.
- The recommendation assumes your theme vocabulary of overlay states is small and closed (typical for a slide theme). If a theme needed to apply *arbitrary, unbounded* opaque classes per step, the token contract becomes impractical and Option 2 (JS) rises in priority.