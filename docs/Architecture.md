# Language and package architecture

This repository is an Odin UI package with a first-class Kvist authoring
layer. The distinction is deliberate:

- Odin owns the reusable native contract: data structures, ownership,
  validation, reconciliation, renderer interfaces, and renderer
  implementations.
- Kvist owns the Hiccup-shaped `Data` facade because immutable vectors, maps,
  keywords, fragments, and data-driven actions are the natural way to author
  that language.

Kvist compiles to Odin, but an Odin application must not need Kvist in order to
use the package. The native packages are independently importable, testable,
documented, and designed with explicit Odin ownership.

## Package rule

Reusable systems and rendering work should have an idiomatic Odin API first.
This includes the reconciliation core and future reusable AppKit, GTK,
Windows, terminal, or custom-surface packages. An application-specific renderer
may begin inside its application while the boundary is being proven, but the
reusable mechanics should not depend on that application's state or commands.

A small Kvist facade belongs on top when the public language is genuinely best
expressed as immutable data. Hiccup UI trees are the motivating case here.
Other examples in the wider ecosystem include Datalog queries and transaction
data. Kvist should add composition and a data language; it should not be a
wrapper required merely to call an otherwise ordinary native procedure.

This yields one shared substrate with multiple authoring paths:

```text
Kvist Hiccup Data ── decode ──┐
                             ├── Odin Node/Action model ── reconciler ── backend
Odin description builder ────┘
```

The package's location under a language-oriented GitHub organization does not
change this contract. Repository ownership can move later without changing
package semantics or forcing a language dependency.

## Current boundary

`reconcile/` is already the complete Odin substrate. It defines owned values,
properties, actions and nodes, validation, event payload resolution, keyed
reconciliation, lifecycle statistics, and the six-callback backend interface.
`headless/` is an Odin backend and deterministic renderer.

`ui.kvist` is the Kvist facade. It validates Hiccup-shaped `Data`, flattens
fragments, and establishes native ownership exactly once at the boundary.

Odin programs can construct `Node` values today, but direct construction is a
low-level API: callers must understand which strings and dynamic arrays are
owned. Before presenting description authoring as polished for general Odin
applications, the package should add:

- safe property, action, child, and node construction;
- a builder or arena with one obvious lifetime;
- an idiomatic Odin example matching the Kvist counter;
- memory-tracked construction, reset, reconciliation, and teardown tests;
- optional vocabulary constants that preserve extensible string tags rather
  than closing the language into a widget enum.

The reconciler and backend interfaces remain the same whichever authoring path
produces the next immutable description.

## Renderer packages

Renderer packages should depend on the Odin contract, not on Kvist Hiccup.
They map semantic tags and properties to their toolkit, retain toolkit-native
editing and focus state, and emit declared action data. An AppKit renderer may
use an `NSTableView`, a GTK renderer a `GtkListView`, and a terminal renderer a
cell-buffer list while consuming the same description.

Toolkit integration, layout measurement, input, accessibility, and native
editing necessarily remain renderer-specific. Product state transitions,
command meaning, and application policy do not belong in a reusable renderer.
Applications may write those views and policies in Kvist or Odin independently
of the renderer's implementation language.
