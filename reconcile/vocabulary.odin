// Copyright (c) Andreas Flakstad and Kvist contributors
// SPDX-License-Identifier: MIT

package ui_reconcile

// Renderer-neutral standard tags. Tags remain strings rather than a closed
// enum so applications and renderers can add namespaced vocabulary.
TAG_SURFACE            :: ":ui/surface"
TAG_DIALOG             :: ":ui/dialog"
TAG_DRAWER             :: ":ui/drawer"
TAG_STACK              :: ":ui/stack"
TAG_SPACER             :: ":ui/spacer"
TAG_TEXT               :: ":ui/text"
TAG_VALIDATION_MESSAGE :: ":ui/validation-message"
TAG_BUTTON             :: ":ui/button"
TAG_TEXT_FIELD         :: ":ui/text-field"
TAG_TEXT_EDITOR        :: ":ui/text-editor"
TAG_TOGGLE_FIELD       :: ":ui/toggle-field"
TAG_DATE_FIELD         :: ":ui/date-field"
TAG_CHOICE_FIELD       :: ":ui/choice-field"
TAG_OPTION             :: ":ui/option"
TAG_FORM_ACTIONS       :: ":ui/form-actions"
TAG_COMMAND_LIST       :: ":ui/command-list"
TAG_COMMAND_GROUP      :: ":ui/command-group"
TAG_COMMAND            :: ":ui/command"

// Common renderer-neutral properties and values.
PROP_ACCESSIBILITY_LABEL :: ":accessibility-label"
PROP_ALIGN               :: ":align"
PROP_DEFAULT_VALUE       :: ":default-value"
PROP_DETAIL              :: ":detail"
PROP_ENABLED             :: ":enabled?"
PROP_EVENT_VALUE_KEY     :: ":event-value-key"
PROP_FOCUS_KEY           :: ":focus-key"
PROP_GAP                 :: ":gap"
PROP_GROW                :: ":grow?"
PROP_HELP                :: ":help"
PROP_INCLUDE_TIME        :: ":include-time?"
PROP_INVALID             :: ":invalid?"
PROP_LABEL               :: ":label"
PROP_OPEN                :: ":open?"
PROP_ORIENTATION         :: ":orientation"
PROP_PLACEHOLDER         :: ":placeholder"
PROP_REQUIRED            :: ":required?"
PROP_ROLE                :: ":role"
PROP_SELECTED_KEY        :: ":selected-key"
PROP_SHORTCUT            :: ":shortcut"
PROP_SIZE                :: ":size"
PROP_SELECTABLE          :: ":selectable?"
PROP_STYLE               :: ":style"
PROP_TEXT                :: ":text"
PROP_TITLE               :: ":title"
PROP_VALUE               :: ":value"
PROP_WRAP                :: ":wrap?"

ORIENTATION_HORIZONTAL :: ":horizontal"
ORIENTATION_VERTICAL   :: ":vertical"

ALIGN_START  :: ":start"
ALIGN_CENTER :: ":center"
ALIGN_END    :: ":end"

ROLE_PRIMARY     :: ":primary"
ROLE_SECONDARY   :: ":secondary"
ROLE_DESTRUCTIVE :: ":destructive"

EVENT_ACTIVATE :: ":activate"
EVENT_BLUR     :: ":blur"
EVENT_CANCEL   :: ":cancel"
EVENT_CHANGE   :: ":change"
EVENT_DELETE_EMPTY :: ":delete-empty"
EVENT_FOCUS    :: ":focus"
EVENT_SELECT   :: ":select"
EVENT_SUBMIT   :: ":submit"

// Renderer-provided payload placeholder used in action argument data.
EVENT_VALUE :: ":event/value"
