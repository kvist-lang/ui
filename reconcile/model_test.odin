#+feature dynamic-literals

// Copyright (c) Andreas Flakstad and Kvist contributors
// SPDX-License-Identifier: MIT

package ui_reconcile

// These tests exercise the backend contract without a platform toolkit.
import "core:fmt"
import "core:testing"

Fake_Instance :: struct {
	id: int,
}

Fake_Context :: struct {
	next_id: int,
}

fake_create :: proc(ctx: rawptr, node: ^Node) -> rawptr {
	fake_context := cast(^Fake_Context)ctx
	fake_context.next_id += 1
	instance := new(Fake_Instance)
	instance.id = fake_context.next_id
	return instance
}

fake_apply :: proc(ctx: rawptr, instance: rawptr, previous, next: ^Node) {}

fake_destroy :: proc(ctx: rawptr, instance: rawptr, node: ^Node) {
	free(cast(^Fake_Instance)instance)
}

fake_insert :: proc(
	ctx: rawptr,
	parent_instance: rawptr,
	parent: ^Node,
	child_instance: rawptr,
	child: ^Node,
	index: int,
) {}

fake_remove :: proc(
	ctx: rawptr,
	parent_instance: rawptr,
	parent: ^Node,
	child_instance: rawptr,
	child: ^Node,
	index: int,
) {}

fake_move :: proc(
	ctx: rawptr,
	parent_instance: rawptr,
	parent: ^Node,
	child_instance: rawptr,
	child: ^Node,
	from, to: int,
) {}

fake_backend :: proc() -> Backend {
	return {
		create = fake_create,
		apply = fake_apply,
		destroy = fake_destroy,
		insert_child = fake_insert,
		remove_child = fake_remove,
		move_child = fake_move,
	}
}

@(test)
keyed_reconciliation_preserves_instances_and_applies_only_changes :: proc(
	t: ^testing.T,
) {
	fake_context: Fake_Context
	reconciler: Reconciler
	reconciler_init(&reconciler, fake_backend(), &fake_context)
	defer reconciler_destroy(&reconciler)

	first_title_props := [dynamic]Property{
		{name = ":value", value = {kind = .Text, text = "First"}},
	}
	defer delete(first_title_props)
	first_children := [dynamic]Node{
		{tag = ":text", key = ":title", props = first_title_props},
		{tag = ":button", key = ":continue"},
	}
	defer delete(first_children)
	first := Node{
		tag = ":surface", key = ":root", children = first_children,
	}
	testing.expect(t, reconcile(&reconciler, &first))
	testing.expect_value(t, reconciler.stats.created, 3)
	testing.expect_value(t, reconciler.stats.inserted, 2)
	title_instance := reconciler_instance(&reconciler, ":title")
	button_instance := reconciler_instance(&reconciler, ":continue")

	next_title_props := [dynamic]Property{
		{name = ":value", value = {kind = .Text, text = "Changed"}},
	}
	defer delete(next_title_props)
	next_children := [dynamic]Node{
		{tag = ":button", key = ":continue"},
		{tag = ":text", key = ":title", props = next_title_props},
		{tag = ":text", key = ":detail"},
	}
	defer delete(next_children)
	next := Node{
		tag = ":surface", key = ":root", children = next_children,
	}
	testing.expect(t, reconcile(&reconciler, &next))
	testing.expect_value(t, reconciler.stats.created, 1)
	testing.expect_value(t, reconciler.stats.applied, 1)
	testing.expect_value(t, reconciler.stats.inserted, 1)
	testing.expect_value(t, reconciler.stats.moved, 1)
	testing.expect(t,
		reconciler_instance(&reconciler, ":title") == title_instance)
	testing.expect(t,
		reconciler_instance(&reconciler, ":continue") == button_instance)

	testing.expect(t, reconcile(&reconciler, &next))
	testing.expect_value(t, reconciler.stats.created, 0)
	testing.expect_value(t, reconciler.stats.applied, 0)
	testing.expect_value(t, reconciler.stats.unchanged, 4)
}

@(test)
reconciliation_rejects_duplicate_sibling_keys :: proc(t: ^testing.T) {
	fake_context: Fake_Context
	reconciler: Reconciler
	reconciler_init(&reconciler, fake_backend(), &fake_context)
	defer reconciler_destroy(&reconciler)

	children := [dynamic]Node{
		{tag = ":text", key = ":same"},
		{tag = ":button", key = ":same"},
	}
	defer delete(children)
	node := Node{tag = ":surface", key = ":root", children = children}
	testing.expect(t, !reconcile(&reconciler, &node))
	testing.expect(t, reconciler.root == nil)
}

@(test)
large_tree_uses_the_indexed_duplicate_key_path :: proc(t: ^testing.T) {
	children := make([dynamic]Node, 0, 32)
	defer {
		for &child in children do delete(child.key)
		delete(children)
	}
	for index in 0..<32 {
		key := fmt.aprintf("row-%d", index)
		if index == 31 {
			delete(key)
			key = fmt.aprintf("duplicate")
		}
		append(&children, Node{tag = ":ui/tree-item", key = key})
	}
	delete(children[0].key)
	children[0].key = fmt.aprintf("duplicate")
	root := Node{tag = ":ui/tree", key = ":tree", children = children}
	testing.expect(t, !node_valid(&root))
}

@(test)
large_property_sets_use_indexed_equality_and_validation :: proc(t: ^testing.T) {
	left := make([dynamic]Property, 0, 24)
	right := make([dynamic]Property, 0, 24)
	defer {
		for &property in left do delete(property.name)
		for &property in right do delete(property.name)
		delete(left)
		delete(right)
	}
	for index in 0..<24 {
		append(&left, Property{
			name = fmt.aprintf(":property-%d", index),
			value = {kind = .Int, int_value = i64(index)},
		})
		reversed := 23 - index
		append(&right, Property{
			name = fmt.aprintf(":property-%d", reversed),
			value = {kind = .Int, int_value = i64(reversed)},
		})
	}
	testing.expect(t, properties_equal(left[:], right[:]))
	node := Node{tag = ":ui/tree-item", key = ":row", props = left}
	testing.expect(t, node_valid(&node))
	delete(left[23].name)
	left[23].name = fmt.aprintf(":property-0")
	testing.expect(t, !node_valid(&node))
}

@(test)
property_and_action_map_order_is_not_semantic :: proc(t: ^testing.T) {
	left_args := [dynamic]Value{{kind = .Int, int_value = 1}}
	defer delete(left_args)
	right_args := [dynamic]Value{{kind = .Int, int_value = 1}}
	defer delete(right_args)
	left_props := [dynamic]Property{
		{name = ":title", value = {kind = .Text, text = "Save"}},
		{name = ":enabled?", value = {kind = .Bool, bool_value = true}},
	}
	defer delete(left_props)
	right_props := [dynamic]Property{
		{name = ":enabled?", value = {kind = .Bool, bool_value = true}},
		{name = ":title", value = {kind = .Text, text = "Save"}},
	}
	defer delete(right_props)
	left_actions := [dynamic]Action{
		{event = ":change", id = ":field/change"},
		{event = ":activate", id = ":save", args = left_args},
	}
	defer delete(left_actions)
	right_actions := [dynamic]Action{
		{event = ":activate", id = ":save", args = right_args},
		{event = ":change", id = ":field/change"},
	}
	defer delete(right_actions)
	left := Node{
		tag = ":button", key = ":save",
		props = left_props, actions = left_actions,
	}
	right := Node{
		tag = ":button", key = ":save",
		props = right_props, actions = right_actions,
	}
	testing.expect(t, node_shallow_equal(&left, &right))
}

@(test)
declared_event_payload_resolves_without_mutating_description :: proc(
	t: ^testing.T,
) {
	arguments := [dynamic]Value{
		{kind = .Keyword, text = ":event/value"},
		{kind = .Text, text = "stable"},
	}
	defer delete(arguments)
	actions := [dynamic]Action{{
		event = ":change", id = ":field/change", args = arguments,
	}}
	defer delete(actions)
	node := Node{tag = ":ui/text-field", key = ":field", actions = actions}
	payload := Value{kind = .Text, text = "typed"}
	resolved, ok := node_resolve_action(&node, ":change", &payload)
	defer action_destroy(&resolved)
	testing.expect(t, ok)
	testing.expect_value(t, resolved.id, ":field/change")
	testing.expect_value(t, len(resolved.args), 2)
	testing.expect_value(t, resolved.args[0].kind, Value_Kind.Text)
	testing.expect_value(t, resolved.args[0].text, "typed")
	testing.expect_value(t, resolved.args[1].text, "stable")
	testing.expect_value(t, actions[0].args[0].text, ":event/value")
}

@(test)
reserved_event_payloads_fail_closed_when_missing_or_unknown :: proc(
	t: ^testing.T,
) {
	missing_arguments := [dynamic]Value{{
		kind = .Keyword, text = ":event/value",
	}}
	defer delete(missing_arguments)
	missing_actions := [dynamic]Action{{
		event = ":change", id = ":field/change", args = missing_arguments,
	}}
	defer delete(missing_actions)
	missing := Node{
		tag = ":ui/text-field", key = ":missing", actions = missing_actions,
	}
	_, missing_ok := node_resolve_action(&missing, ":change")
	testing.expect(t, !missing_ok)

	unknown_arguments := [dynamic]Value{{
		kind = .Keyword, text = ":event/index",
	}}
	defer delete(unknown_arguments)
	unknown_actions := [dynamic]Action{{
		event = ":select", id = ":field/select", args = unknown_arguments,
	}}
	defer delete(unknown_actions)
	unknown := Node{
		tag = ":ui/list", key = ":unknown", actions = unknown_actions,
	}
	payload := Value{kind = .Int, int_value = 3}
	_, unknown_ok := node_resolve_action(&unknown, ":select", &payload)
	testing.expect(t, !unknown_ok)
}
