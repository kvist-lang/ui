package ui_reconcile

import "core:mem"
import "core:strings"
import "core:testing"

counter_node :: proc(builder: ^Builder, label: string) -> Node {
	return node(builder, TAG_STACK, "counter", {
		props = []Property_Spec{
			property(PROP_ORIENTATION, keyword(ORIENTATION_VERTICAL)),
			property(PROP_GAP, keyword(":control")),
		},
		children = []Node{
			node(builder, TAG_TEXT, "value", {
				props = []Property_Spec{
					property(PROP_TEXT, text(label)),
				},
			}),
			node(builder, TAG_BUTTON, "increment", {
				props = []Property_Spec{
					property(PROP_LABEL, text("Increment")),
				},
				actions = []Action_Spec{
					action(EVENT_ACTIVATE, ":counter/increment"),
				},
			}),
		},
	})
}

@(test)
odin_builder_authors_owned_renderer_neutral_trees :: proc(t: ^testing.T) {
	builder: Builder
	builder_init(&builder)
	defer builder_destroy(&builder)

	root := counter_node(&builder, "0")
	testing.expect(t, node_valid(&root))
	testing.expect_value(t, root.tag, TAG_STACK)
	testing.expect_value(t, root.key, "counter")
	testing.expect_value(t, len(root.children), 2)
	testing.expect_value(
		t,
		node_text(&root.children[0], PROP_TEXT),
		"0",
	)
	declared, found := node_action(&root.children[1], EVENT_ACTIVATE)
	testing.expect(t, found)
	if found {
		testing.expect_value(t, declared.id, ":counter/increment")
	}
}

@(test)
builder_copies_borrowed_action_arguments :: proc(t: ^testing.T) {
	builder: Builder
	builder_init(&builder)
	defer builder_destroy(&builder)

	borrowed_text := strings.clone("stable")
	args := [2]Value{keyword(EVENT_VALUE), text(borrowed_text)}
	field := node(&builder, TAG_TEXT_FIELD, "field", {
		actions = []Action_Spec{
			action(EVENT_CHANGE, ":field/change", args[:]),
		},
	})
	delete(borrowed_text)

	payload := text("typed")
	resolved, ok := node_resolve_action(&field, EVENT_CHANGE, &payload)
	defer action_destroy(&resolved)
	testing.expect(t, ok)
	testing.expect_value(t, resolved.id, ":field/change")
	testing.expect_value(t, resolved.args[0].text, "typed")
	testing.expect_value(t, resolved.args[1].text, "stable")
}

@(test)
builder_authors_optional_time_as_portable_date_data :: proc(t: ^testing.T) {
	builder: Builder
	builder_init(&builder)
	defer builder_destroy(&builder)

	field := node(&builder, TAG_DATE_FIELD, "review-date", {
		props = []Property_Spec{
			property(PROP_DEFAULT_VALUE, text("2026-09-01")),
			property(PROP_INCLUDE_TIME, boolean(false)),
			property(PROP_TIME_OPTIONAL, boolean(true)),
			property(PROP_REQUIRED, boolean(false)),
		},
	})
	testing.expect(t, node_valid(&field))
	testing.expect(t, node_bool(&field, PROP_TIME_OPTIONAL))
	testing.expect(t, !node_bool(&field, PROP_INCLUDE_TIME))
}

@(test)
builder_reset_supports_the_render_reconcile_reset_loop :: proc(t: ^testing.T) {
	builder: Builder
	builder_init(&builder)
	defer builder_destroy(&builder)

	fake_context: Fake_Context
	reconciler: Reconciler
	reconciler_init(&reconciler, fake_backend(), &fake_context)
	defer reconciler_destroy(&reconciler)

	first := counter_node(&builder, "0")
	testing.expect(t, reconcile(&reconciler, &first))
	value_instance := reconciler_instance(&reconciler, "value")
	button_instance := reconciler_instance(&reconciler, "increment")

	builder_reset(&builder)
	next := counter_node(&builder, "1")
	testing.expect(t, reconcile(&reconciler, &next))
	testing.expect_value(t, reconciler.stats.created, 0)
	testing.expect_value(t, reconciler.stats.applied, 1)
	testing.expect(
		t,
		reconciler_instance(&reconciler, "value") == value_instance,
	)
	testing.expect(
		t,
		reconciler_instance(&reconciler, "increment") == button_instance,
	)
}

@(test)
builder_destroy_releases_all_arena_memory :: proc(t: ^testing.T) {
	tracker: mem.Tracking_Allocator
	mem.tracking_allocator_init(&tracker, context.allocator)
	backing := mem.tracking_allocator(&tracker)

	builder: Builder
	builder_init(&builder, backing)
	labels := [4]string{"0", "1", "2", "3"}
	for label in labels {
		root := counter_node(&builder, label)
		testing.expect(t, node_valid(&root))
		builder_reset(&builder)
	}
	builder_destroy(&builder)

	testing.expect_value(t, tracker.current_memory_allocated, 0)
	testing.expect_value(t, len(tracker.allocation_map), 0)
	mem.tracking_allocator_destroy(&tracker)
}

@(test)
builder_rejects_invalid_descriptions_without_manual_cleanup :: proc(
	t: ^testing.T,
) {
	builder: Builder
	builder_init(&builder)
	defer builder_destroy(&builder)

	invalid := node(&builder, TAG_STACK, "root", {
		children = []Node{
			node(&builder, TAG_TEXT, "same"),
			node(&builder, TAG_BUTTON, "same"),
		},
	})
	testing.expect(t, !node_valid(&invalid))
}
