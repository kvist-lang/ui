# UI for Odin and Kvist

A small renderer-neutral retained UI contract implemented in Odin, with a
Replicant-shaped Hiccup authoring layer for
[Kvist](https://github.com/kvist-lang/kvist).

The native model, ownership, validation, keyed reconciler, backend contract,
and headless renderer are ordinary Odin packages and do not require Kvist.
Kvist adds the concise immutable `Data` DSL where Hiccup is the natural API.
The project is intended to grow an equally deliberate Odin description-builder
API rather than require Odin applications to construct owned arrays by hand.

Place this repository under your project's dependency folder and import the
Hiccup decoder by relative path:

```clojure
(import ui "deps/ui")
```

Native backends can import the reconciliation contract directly from Odin:

```odin
import reconcile "deps/ui/reconcile"
```

The repository also provides `headless/`, a deterministic backend for contract
tests and platform-free consumers. Product state, action interpretation,
scheduling, effects, layout, and platform widget registries remain application
concerns.

See [the UI guide](docs/UI.md) and
[the renderer-neutral standard vocabulary](docs/Vocabulary.md). The
[language and package architecture](docs/Architecture.md) explains the
Odin-first core and optional Kvist DSL. Run the tests with:

```sh
kvist test tests/ui-tests.kvist --track-memory
odin test reconcile -define:ODIN_TEST_THREADS=1
odin test headless -define:ODIN_TEST_THREADS=1
```
