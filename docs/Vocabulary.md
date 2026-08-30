# Standard UI vocabulary

Kvist UI descriptions use semantic, renderer-neutral names. A tag says what a
node means to the application; the backend decides which native widget, DOM
element, terminal region, or test instance realizes it.

The decoder intentionally accepts any keyword tag and scalar properties. This
keeps the package extensible: the vocabulary below is a portable convention,
not a closed widget enum. Applications may add namespaced tags, while reusable
views and backends should prefer these standard names where they fit.

## Structure and presentation

| Tag | Meaning | Common properties |
| --- | --- | --- |
| `:ui/dialog` | A transient dialog surface | `:open?`, `:title`, `:help` |
| `:ui/drawer` | A panel attached to an application edge or flow | `:open?`, `:title`, `:help` |
| `:ui/stack` | Ordered layout along one axis | `:orientation` (`:vertical` or `:horizontal`), `:gap` |
| `:ui/spacer` | Flexible or fixed separation | `:size` |
| `:ui/text` | Read-only textual content | `:text`, `:role`, `:style` |
| `:ui/validation-message` | Validation feedback associated with input | `:text`, `:for` |

`:ui/dialog` deliberately does not say “sheet”, “window”, or “popover”. Those
are backend decisions. Likewise, one `:ui/stack` plus `:orientation` composes
across renderers without encoding a toolkit's horizontal and vertical stack
classes in the tag set.

## Input and actions

| Tag | Meaning | Common properties and events |
| --- | --- | --- |
| `:ui/button` | An activatable action | `:label`, `:enabled?`, `:on {:activate ...}` |
| `:ui/text-field` | Single-line text input | `:value` or `:default-value`, `:placeholder`, `:on {:change ...}` |
| `:ui/text-editor` | Multi-line text editing | `:value` or `:default-value`, `:placeholder`, `:on {:change ...}` |
| `:ui/toggle-field` | Boolean input | `:value`, `:label`, `:on {:change ...}` |
| `:ui/date-field` | Date or instant input | `:value`, `:label`, `:on {:change ...}` |
| `:ui/choice-field` | Selection from a bounded set | `:value`, `:label`, `:on {:change ...}` |
| `:ui/option` | One choice within a choice field | `:value`, `:label`, `:enabled?` |
| `:ui/form-actions` | Semantic group of form actions | child buttons |

Use `:value` for controlled state. Use `:default-value` when the backend owns
ephemeral editing state such as text composition, selection, undo, or calendar
interaction until it emits an action.

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
- `:accessibility-label` supplies a spoken label when visible content is not
  sufficient.
- Event names describe interaction (`:activate`, `:change`, `:select`,
  `:submit`, `:cancel`); action vectors describe product intent.
- Renderer-specific needs belong in a renderer namespace, for example
  `:appkit/control-size`, and should not be required by portable views.

A backend implements only the tags it needs. Unsupported standard tags should
produce a clear renderer error; they must not change the meaning of the shared
description language.
