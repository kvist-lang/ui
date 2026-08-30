# Kvist UI

A small Replicant-shaped contract for describing retained user interfaces as
data in [Kvist](https://github.com/kvist-lang/kvist).

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
[the renderer-neutral standard vocabulary](docs/Vocabulary.md). Run the tests
with:

```sh
kvist test tests/ui-tests.kvist --track-memory
odin test reconcile -define:ODIN_TEST_THREADS=1
odin test headless -define:ODIN_TEST_THREADS=1
```
