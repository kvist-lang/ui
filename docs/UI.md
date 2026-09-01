# Declarative UI

This package provides an Odin-native retained UI contract and a small
Replicant-shaped layer for describing interfaces as data in Kvist. It is
renderer-independent: applications choose their native, terminal, web, or
test backend and retain ownership of product state and action interpretation.

The package family has three parts:

- `ui/reconcile` provides the native `Node`, `Value`, `Action`, keyed
  reconciler, structural statistics, and six-callback backend contract.
- `ui/headless` provides an optional deterministic instance tree for
  tests, REPL probes, and renderer-independent consumers.
- `ui` provides the Kvist Hiccup decoder and `ui.for` fragment macro over that
  native contract.

Both native packages are directly usable from Odin without Kvist. See
[the language and package architecture](Architecture.md) for the criterion
for adding language-specific DSLs.

## Kvist Hiccup descriptions

View functions return ordinary immutable `Data`:

```clojure
(import ui "deps/ui")

(defn counter-view [label: string] -> Data
  [:ui/stack {:key :counter :orientation :vertical :gap :control}
   [:ui/text {:key :value :text label}]
   [:ui/button
    {:key :increment
     :label "Increment"
     :on {:activate [:counter/increment]}}]])
```

Every node has an explicit key. Sibling keys must be unique. A stable key and
tag preserve the mounted instance across content changes and reorderings.
Events are semantic action vectors rather than closures over renderer state.
Tags and properties are renderer-neutral vocabulary. For example, a backend
may realize `:ui/dialog` as an AppKit sheet, a GTK window, a terminal overlay,
or an accessible web dialog. See [the standard vocabulary](Vocabulary.md) for
the portable names applications and reusable backends should share.

Use the reserved `:event/value` scalar when a backend must supply an event
payload:

```clojure
[:ui/text-field
 {:key :query
  :value model.query
  :on {:change [:query/set :event/value]}}]
```

`:value` represents controlled application state. `:default-value` initializes
a backend-owned editable value, allowing a native backend to preserve text
composition, selection, undo, calendar interaction, and similar ephemeral
state until it emits a semantic action.

Structured editors use the same scalar boundary. A `:ui/document-editor`
declares an encoded `:value` or `:default-value`, its `:format`, and optional
`:fallback-text`; the renderer emits the updated encoded document through
`:event/value`. The portable document codec—not the renderer or UI core—owns
validation and derived plain text.

`ui.for` maps a native collection to a child fragment without mounting an
extra wrapper:

```clojure
(ui.for [command: Command commands]
  [:ui/command
   {:key command.id
    :label command.label
    :on {:activate [:commands/accept command.id]}}])
```

`ui.decode` validates a description and returns an owned native node:

```clojure
(let [[node err ok] (ui.decode (counter-view "0"))]
  (defer (reconcile.decode-error-destroy (addr err)))
  (defer (reconcile.node-destroy (addr node)))
  ...)
```

## Odin descriptions

Odin components accept a `^ui.Builder` and return an arena-owned `ui.Node` by
value. `ui.node` immediately copies its borrowed properties and actions into
the builder; child nodes are values produced by the same builder:

```odin
import ui "deps/ui/reconcile"

counter_view :: proc(builder: ^ui.Builder, label: string) -> ui.Node {
    return ui.node(builder, ui.TAG_STACK, "counter", {
        props = []ui.Property_Spec{
            ui.property(
                ui.PROP_ORIENTATION,
                ui.keyword(ui.ORIENTATION_VERTICAL),
            ),
        },
        children = []ui.Node{
            ui.node(builder, ui.TAG_TEXT, "value", {
                props = []ui.Property_Spec{
                    ui.property(ui.PROP_TEXT, ui.text(label)),
                },
            }),
            ui.node(builder, ui.TAG_BUTTON, "increment", {
                props = []ui.Property_Spec{
                    ui.property(ui.PROP_LABEL, ui.text("Increment")),
                },
                actions = []ui.Action_Spec{
                    ui.action(
                        ui.EVENT_ACTIVATE,
                        ":counter/increment",
                    ),
                },
            }),
        },
    })
}
```

The render loop has one explicit description lifetime:

```odin
builder: ui.Builder
ui.builder_init(&builder)
defer ui.builder_destroy(&builder)

view := counter_view(&builder, "0")
assert(ui.node_valid(&view))
assert(renderer_reconcile(&renderer, &view))
ui.builder_reset(&builder)
```

Do not call `node_destroy` on builder-owned nodes or use them after reset. The
reconciler and supplied headless renderer clone what they retain, so reset is
safe immediately after reconciliation. A component may compose other
components and return its `Node` because its strings and arrays live in the
builder rather than its stack frame. Dynamic child collections can be assembled
in an ordinary temporary `[dynamic]ui.Node` and passed to `ui.node` as a slice.

`none`, `boolean`, `integer`, `decimal`, `text`, and `keyword` construct scalar
values; `property` and `action` create borrowed authoring values. Standard
tags, properties, events, and orientations have constants, but the underlying
names remain strings so applications can add renderer-neutral or
renderer-specific vocabulary. See the complete
[Odin counter](../examples/odin-counter/main.odin).

## Reconciliation

The native package is available to both Kvist and handwritten Odin:

```clojure
(import reconcile "deps/ui/reconcile")
```

```odin
import reconcile "deps/ui/reconcile"
```

A backend implements create, apply, destroy, insert-child, remove-child, and
move-child. Reconciliation patches only shallow descriptions that changed and
performs structural work by stable sibling key. An unchanged description has
zero create, apply, insert, remove, move, or destroy operations.

The core deliberately does not define product action dispatch, effects,
subscriptions, scheduling, platform focus, layout, or widget registries. These
belong to the application and backend around the small structural contract.

## Headless backend

The headless backend retains an inspectable instance tree behind the same
contract:

```clojure
(import headless "deps/ui/headless")

(let [renderer (headless.Renderer [])]
  (headless.renderer-init (addr renderer))
  (defer (headless.renderer-destroy (addr renderer)))
  (headless.renderer-reconcile (addr renderer) (addr node))
  (headless.renderer-matches (addr renderer) (addr node)))
```

`renderer-emit` resolves an event against the currently mounted description,
substitutes a supplied `:event/value`, and returns an owned `Action`. It does
not interpret the action id. `renderer-stats`, stable instance ids, and exact
tree matching make lifecycle behavior observable without a platform toolkit.

## Performance boundary

Sibling-key validation is linear in the number of children. Ordinary unchanged
and append-heavy reconciliation is likewise linear; adversarial reordering can
still require many ordered moves. Keep large product collections behind native
virtualization or windowing. The description API does not imply allocating a
native widget for every item in a large logical collection.

The repository includes a repeatable native microbenchmark for description
construction and keyed reconciliation:

```sh
odin run benchmarks/builder -o:speed
odin run benchmarks/flat-tree -o:speed
```

It reports construction separately from construction plus reconciliation and
uses alternating content to ensure the apply path is measured. It is an
investigation tool rather than a machine-dependent pass/fail threshold.
