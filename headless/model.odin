// Copyright (c) Andreas Flakstad and Kvist contributors
// SPDX-License-Identifier: MIT

package ui_headless

import ui "../reconcile"

// Deterministic, platform-free backend for the data-driven UI contract.
//
// The reconciler remains responsible for description ownership and keyed
// lifecycle. This backend retains a second, observable instance tree so tests,
// REPL probes, and future non-native consumers can exercise the exact same
// structural protocol as AppKit without knowing any product tags.

Instance :: struct {
	id:          int,
	description: ui.Node,
	children:    [dynamic]^Instance,
}

Context :: struct {
	next_id:    int,
	live_count: int,
}

Renderer :: struct {
	state:      Context,
	reconciler: ui.Reconciler,
}

@(private)
create :: proc(ctx: rawptr, node: ^ui.Node) -> rawptr {
	state := cast(^Context)ctx
	state.next_id += 1
	state.live_count += 1
	instance := new(Instance)
	instance.id = state.next_id
	instance.description = ui.node_clone_shallow(node^)
	instance.children = make([dynamic]^Instance, 0, len(node.children))
	return cast(rawptr)instance
}

@(private)
apply :: proc(
	_ctx: rawptr,
	raw_instance: rawptr,
	_previous, next: ^ui.Node,
) {
	instance := cast(^Instance)raw_instance
	ui.node_destroy_shallow(&instance.description)
	instance.description = ui.node_clone_shallow(next^)
}

@(private)
destroy :: proc(ctx: rawptr, raw_instance: rawptr, _node: ^ui.Node) {
	state := cast(^Context)ctx
	instance := cast(^Instance)raw_instance
	assert(len(instance.children) == 0,
		"headless instances must release children before their parent")
	ui.node_destroy_shallow(&instance.description)
	delete(instance.children)
	state.live_count -= 1
	free(instance)
}

@(private)
insert_child :: proc(
	_ctx: rawptr,
	raw_parent: rawptr,
	_parent: ^ui.Node,
	raw_child: rawptr,
	_child: ^ui.Node,
	index: int,
) {
	parent := cast(^Instance)raw_parent
	child := cast(^Instance)raw_child
	assert(index >= 0 && index <= len(parent.children))
	append(&parent.children, child)
	for position := len(parent.children) - 1; position > index; position -= 1 {
		parent.children[position] = parent.children[position - 1]
	}
	parent.children[index] = child
}

@(private)
remove_child :: proc(
	_ctx: rawptr,
	raw_parent: rawptr,
	_parent: ^ui.Node,
	raw_child: rawptr,
	_child: ^ui.Node,
	index: int,
) {
	parent := cast(^Instance)raw_parent
	child := cast(^Instance)raw_child
	assert(index >= 0 && index < len(parent.children))
	assert(parent.children[index] == child)
	ordered_remove(&parent.children, index)
}

@(private)
move_child :: proc(
	_ctx: rawptr,
	raw_parent: rawptr,
	_parent: ^ui.Node,
	raw_child: rawptr,
	_child: ^ui.Node,
	from, to: int,
) {
	parent := cast(^Instance)raw_parent
	child := cast(^Instance)raw_child
	assert(from >= 0 && from < len(parent.children))
	assert(to >= 0 && to < len(parent.children))
	assert(parent.children[from] == child)
	if from == to do return
	if from > to {
		for position := from; position > to; position -= 1 {
			parent.children[position] = parent.children[position - 1]
		}
	} else {
		for position := from; position < to; position += 1 {
			parent.children[position] = parent.children[position + 1]
		}
	}
	parent.children[to] = child
}

backend :: proc() -> ui.Backend {
	return {
		create = create,
		apply = apply,
		destroy = destroy,
		insert_child = insert_child,
		remove_child = remove_child,
		move_child = move_child,
	}
}

renderer_init :: proc(renderer: ^Renderer) {
	assert(renderer != nil)
	renderer^ = {}
	ui.reconciler_init(
		&renderer.reconciler, backend(), cast(rawptr)&renderer.state)
}

renderer_destroy :: proc(renderer: ^Renderer) {
	if renderer == nil do return
	ui.reconciler_destroy(&renderer.reconciler)
	assert(renderer.state.live_count == 0)
	renderer^ = {}
}

renderer_reconcile :: proc(renderer: ^Renderer, next: ^ui.Node) -> bool {
	if renderer == nil do return false
	return ui.reconcile(&renderer.reconciler, next)
}

renderer_root :: proc(renderer: ^Renderer) -> ^Instance {
	if renderer == nil || renderer.reconciler.root == nil do return nil
	return cast(^Instance)renderer.reconciler.root.instance
}

renderer_instance :: proc(renderer: ^Renderer, key: string) -> ^Instance {
	if renderer == nil do return nil
	raw_instance := ui.reconciler_instance(&renderer.reconciler, key)
	if raw_instance == nil do return nil
	return cast(^Instance)raw_instance
}

renderer_instance_id :: proc(
	renderer: ^Renderer,
	key: string,
) -> (int, bool) {
	instance := renderer_instance(renderer, key)
	if instance == nil do return 0, false
	return instance.id, true
}

renderer_stats :: proc(renderer: ^Renderer) -> ui.Stats {
	if renderer == nil do return {}
	return renderer.reconciler.stats
}

renderer_live_count :: proc(renderer: ^Renderer) -> int {
	if renderer == nil do return 0
	return renderer.state.live_count
}

instance_matches :: proc(instance: ^Instance, node: ^ui.Node) -> bool {
	if instance == nil || node == nil do return instance == nil && node == nil
	if !ui.node_shallow_equal(&instance.description, node) ||
	   len(instance.children) != len(node.children) {
		return false
	}
	for child, index in instance.children {
		if !instance_matches(child, &node.children[index]) do return false
	}
	return true
}

renderer_matches :: proc(renderer: ^Renderer, node: ^ui.Node) -> bool {
	if renderer == nil do return false
	return instance_matches(renderer_root(renderer), node)
}

// Emit one event against the currently mounted description. The returned
// action is owned by the caller and deliberately remains uninterpreted: Ro,
// another application, or a test harness decides what the semantic id means.
renderer_emit :: proc(
	renderer: ^Renderer,
	key, event: string,
	event_value: ^ui.Value = nil,
) -> (ui.Action, bool) {
	instance := renderer_instance(renderer, key)
	if instance == nil do return {}, false
	return ui.node_resolve_action(&instance.description, event, event_value)
}
