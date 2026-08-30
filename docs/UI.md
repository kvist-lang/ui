# Declarative UI

This package provides a small Replicant-shaped contract for describing
retained user interfaces as data in Kvist. It is renderer-independent:
applications choose their native, terminal, web, or test backend and retain
ownership of product state and action interpretation.

The package family has three parts:

- `ui` provides the Hiccup decoder and `ui.for` fragment macro.
- `ui/reconcile` provides the native `Node`, `Value`, `Action`, keyed
  reconciler, structural statistics, and six-callback backend contract.
- `ui/headless` provides an optional deterministic instance tree for
  tests, REPL probes, and renderer-independent consumers.

## Descriptions

View functions return ordinary immutable `Data`:

```clojure
(import ui "deps/ui")

(defn counter-view [label: string] -> Data
  [:ui/vstack {:key :counter :gap :control}
   [:ui/text {:key :value :text label}]
   [:ui/button
    {:key :increment
     :label "Increment"
     :on {:activate [:counter/increment]}}]])
```

Every node has an explicit key. Sibling keys must be unique. A stable key and
tag preserve the mounted instance across content changes and reorderings.
Events are semantic action vectors rather than closures over renderer state.

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

(let [renderer (headless.Renderer {})]
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

Key validation and sibling lookup are intentionally simple in the initial
contract and become nonlinear for very large flat trees. Keep large product
collections behind native virtualization or windowing. The description API
does not imply allocating a native widget for every item in a large logical
collection.
