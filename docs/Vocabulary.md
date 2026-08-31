# Standard UI vocabulary

UI descriptions use semantic, renderer-neutral names. Whether produced by the
Kvist Hiccup decoder or the Odin authoring API, a tag says what a node means to
the application; the backend decides which native widget, DOM element,
terminal region, or test instance realizes it.

The decoder intentionally accepts any keyword tag and scalar properties. This
keeps the package extensible: the vocabulary below is a portable convention,
not a closed widget enum. Applications may add namespaced tags, while reusable
views and backends should prefer these standard names where they fit.
Odin callers may use the `TAG_*`, `PROP_*`, `EVENT_*`, and orientation constants
from `reconcile/vocabulary.odin`; their values are the same strings shown here.

## Structure and presentation

| Tag | Meaning | Common properties |
| --- | --- | --- |
| `:ui/dialog` | A transient dialog surface | `:open?`, `:title`, `:help` |
| `:ui/drawer` | A panel attached to an application edge or flow | `:open?`, `:title`, `:help` |
| `:ui/stack` | Ordered layout along one axis | `:orientation` (`:vertical` or `:horizontal`), `:gap`, `:align`, `:grow?` on children |
| `:ui/spacer` | Flexible or fixed separation | `:size` |
| `:ui/text` | Read-only textual content | `:text`, `:role`, `:style`, `:wrap?`, `:selectable?` |
| `:ui/validation-message` | Validation feedback associated with input | `:text`, `:invalid?` |

`:ui/dialog` deliberately does not say “sheet”, “window”, or “popover”. Those
are backend decisions. Likewise, one `:ui/stack` plus `:orientation` composes
across renderers without encoding a toolkit's horizontal and vertical stack
classes in the tag set.

## Input and actions

| Tag | Meaning | Common properties and events |
| --- | --- | --- |
| `:ui/button` | An activatable action | `:label`, `:enabled?`, `:role`, `:event-value-key`, `:on {:activate ...}` |
| `:ui/text-field` | Single-line text input | `:value` or `:default-value`, `:placeholder`, `:on {:change ...}` |
| `:ui/text-editor` | Multi-line text editing | `:value` or `:default-value`, `:placeholder`, `:on {:change ...}` |
| `:ui/toggle-field` | Boolean input | boolean `:value` or `:default-value`, `:label`, `:on {:change ...}` |
| `:ui/date-field` | Date or instant input | `:value` or `:default-value`, `:include-time?`, `:required?`, `:label`, `:on {:change ...}` |
| `:ui/choice-field` | Selection from a bounded set | `:value`, `:label`, `:on {:change ...}` |
| `:ui/option` | One choice within a choice field | `:value`, `:label`, `:enabled?` |
| `:ui/form-actions` | Semantic group of form actions | child buttons |

Use `:value` for controlled state. Use `:default-value` when the backend owns
ephemeral editing state such as text composition, selection, undo, or calendar
interaction until it emits an action.

An action normally receives a native control's scalar value through
`:event/value`. A separate action control may declare `:event-value-key` with
the stable key of another mounted value-owning node. This is useful for a
Submit button that should dispatch the current text, toggle, choice, or date
without forcing the application to mirror an in-progress native draft.

Editable text controls may declare `:delete-empty` when an empty Backspace has
product meaning such as returning to the previous prompt. `:focus` and `:blur`
are the corresponding portable focus-boundary events. Backends only emit these
events when the platform interaction actually occurs.

## Command collections

| Tag | Meaning | Common properties and events |
| --- | --- | --- |
| `:ui/command-list` | Navigable, optionally virtualized command collection | `:selected-key`, `:focus-key` |
| `:ui/command-group` | Labeled grouping within a command list | `:label` |
| `:ui/command` | One command row | `:label`, `:detail`, `:shortcut`, `:enabled?`, `:on {:select ... :activate ...}` |

The description is logical, not an instruction to allocate one native widget
per command. A backend may virtualize a command list and query only visible
rows while preserving the same data and actions.

## Shared conventions

- Every node has a stable, explicit `:key`; sibling keys are unique.
- `:enabled?`, `:required?`, and `:open?` are booleans.
- `:align` uses `:start`, `:center`, or `:end`; `:grow?` lets a child consume
  remaining layout space without naming a toolkit constraint API.
- `:accessibility-label` supplies a spoken label when visible content is not
  sufficient.
- Standard button roles are `:primary`, `:secondary`, and `:destructive`.
- Event names describe interaction (`:activate`, `:change`, `:select`,
  `:submit`, `:cancel`); action vectors describe product intent.
- Renderer-specific needs belong in a renderer namespace, for example
  `:appkit/control-size`, and should not be required by portable views.

A backend implements only the tags it needs. Unsupported standard tags should
produce a clear renderer error; they must not change the meaning of the shared
description language.
