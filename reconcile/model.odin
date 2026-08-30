// Copyright (c) Andreas Flakstad and Kvist contributors
// SPDX-License-Identifier: MIT

package ui_reconcile

import "core:strings"

// Platform-neutral retained UI description and reconciliation mechanics.
// This is the native contract of the standalone Kvist UI package.
//
// Kvist view functions author Hiccup-shaped immutable Data and decode it into
// this explicit native boundary. Backends retain real widgets and receive
// only the smallest structural operations required to make the mounted tree
// match the next description. This package knows no AppKit, GTK, Ro snapshot,
// or product intent meaning.

Value_Kind :: enum {
	None,
	Bool,
	Int,
	Float,
	Text,
	Keyword,
}

Value :: struct {
	kind:        Value_Kind,
	bool_value:  bool,
	int_value:   i64,
	float_value: f64,
	text:        string,
}

Property :: struct {
	name:  string,
	value: Value,
}

// Events and actions remain data. The backend connects one stable native
// dispatcher and interprets the action id and scalar arguments when the event
// occurs; view descriptions never close over mutable application state.
Action :: struct {
	event: string,
	id:    string,
	args:  [dynamic]Value,
}

Node :: struct {
	tag:      string,
	key:      string,
	props:    [dynamic]Property,
	actions:  [dynamic]Action,
	children: [dynamic]Node,
}

Decode_Error :: struct {
	path:    string,
	message: string,
}

value_clone :: proc(value: Value) -> Value {
	result := value
	if value.kind == .Text || value.kind == .Keyword {
		result.text = strings.clone(value.text)
	}
	return result
}

value_destroy :: proc(value: ^Value) {
	if value == nil do return
	if value.kind == .Text || value.kind == .Keyword do delete(value.text)
	value^ = {}
}

value_equal :: proc(left, right: Value) -> bool {
	if left.kind != right.kind do return false
	switch left.kind {
	case .None:    return true
	case .Bool:    return left.bool_value == right.bool_value
	case .Int:     return left.int_value == right.int_value
	case .Float:   return left.float_value == right.float_value
	case .Text,
	     .Keyword: return left.text == right.text
	}
	return false
}

property_clone :: proc(property: Property) -> Property {
	return {
		name = strings.clone(property.name),
		value = value_clone(property.value),
	}
}

property_destroy :: proc(property: ^Property) {
	if property == nil do return
	delete(property.name)
	value_destroy(&property.value)
	property^ = {}
}

action_clone :: proc(action: Action) -> Action {
	args := make([dynamic]Value, 0, len(action.args))
	for value in action.args do append(&args, value_clone(value))
	return {
		event = strings.clone(action.event),
		id = strings.clone(action.id),
		args = args,
	}
}

action_destroy :: proc(action: ^Action) {
	if action == nil do return
	delete(action.event)
	delete(action.id)
	for &value in action.args do value_destroy(&value)
	delete(action.args)
	action^ = {}
}

node_clone_shallow :: proc(node: Node) -> Node {
	props := make([dynamic]Property, 0, len(node.props))
	for property in node.props do append(&props, property_clone(property))
	actions := make([dynamic]Action, 0, len(node.actions))
	for action in node.actions do append(&actions, action_clone(action))
	return {
		tag = strings.clone(node.tag),
		key = strings.clone(node.key),
		props = props,
		actions = actions,
	}
}

node_clone :: proc(node: Node) -> Node {
	result := node_clone_shallow(node)
	result.children = make([dynamic]Node, 0, len(node.children))
	for child in node.children do append(&result.children, node_clone(child))
	return result
}

node_destroy_shallow :: proc(node: ^Node) {
	if node == nil do return
	delete(node.tag)
	delete(node.key)
	for &property in node.props do property_destroy(&property)
	delete(node.props)
	for &action in node.actions do action_destroy(&action)
	delete(node.actions)
	node.tag = ""
	node.key = ""
	node.props = nil
	node.actions = nil
}

node_destroy :: proc(node: ^Node) {
	if node == nil do return
	node_destroy_shallow(node)
	for &child in node.children do node_destroy(&child)
	delete(node.children)
	node^ = {}
}

decode_error_destroy :: proc(err: ^Decode_Error) {
	if err == nil do return
	delete(err.path)
	delete(err.message)
	err^ = {}
}

properties_equal :: proc(left, right: []Property) -> bool {
	if len(left) != len(right) do return false
	for property in left {
		found := false
		for candidate in right {
			if candidate.name == property.name {
				if !value_equal(property.value, candidate.value) do return false
				found = true
				break
			}
		}
		if !found do return false
	}
	return true
}

actions_equal :: proc(left, right: []Action) -> bool {
	if len(left) != len(right) do return false
	for action in left {
		found := false
		for candidate in right {
			if candidate.event != action.event do continue
			if action.id != candidate.id ||
			   len(action.args) != len(candidate.args) {
				return false
			}
			for value, value_index in action.args {
				if !value_equal(value, candidate.args[value_index]) do return false
			}
			found = true
			break
		}
		if !found do return false
	}
	return true
}

node_shallow_equal :: proc(left, right: ^Node) -> bool {
	if left == nil || right == nil do return left == right
	return left.tag == right.tag && left.key == right.key &&
		properties_equal(left.props[:], right.props[:]) &&
		actions_equal(left.actions[:], right.actions[:])
}

node_equal :: proc(left, right: ^Node) -> bool {
	if !node_shallow_equal(left, right) ||
	   len(left.children) != len(right.children) {
		return false
	}
	for &child, index in left.children {
		if !node_equal(&child, &right.children[index]) do return false
	}
	return true
}

node_property :: proc(node: ^Node, name: string) -> (Value, bool) {
	if node == nil do return {}, false
	for property in node.props {
		if property.name == name do return property.value, true
	}
	return {}, false
}

node_text :: proc(node: ^Node, name: string, fallback := "") -> string {
	value, ok := node_property(node, name)
	if !ok || (value.kind != .Text && value.kind != .Keyword) do return fallback
	return value.text
}

node_bool :: proc(node: ^Node, name: string, fallback := false) -> bool {
	value, ok := node_property(node, name)
	if !ok || value.kind != .Bool do return fallback
	return value.bool_value
}

node_int :: proc(node: ^Node, name: string, fallback: i64 = 0) -> i64 {
	value, ok := node_property(node, name)
	if !ok || value.kind != .Int do return fallback
	return value.int_value
}

node_float :: proc(node: ^Node, name: string, fallback: f64 = 0) -> f64 {
	value, ok := node_property(node, name)
	if !ok do return fallback
	if value.kind == .Float do return value.float_value
	if value.kind == .Int do return f64(value.int_value)
	return fallback
}

node_action :: proc(node: ^Node, event: string) -> (^Action, bool) {
	if node == nil do return nil, false
	for &action in node.actions {
		if action.event == event do return &action, true
	}
	return nil, false
}

// Resolve one declared event into an owned action. Reserved renderer payloads
// are substituted without mutating the immutable description; callers destroy
// successful results with action_destroy. Unknown or missing renderer
// placeholders fail closed so a backend cannot accidentally dispatch them as
// product keywords.
node_resolve_action :: proc(
	node: ^Node,
	event: string,
	event_value: ^Value = nil,
) -> (Action, bool) {
	declared, found := node_action(node, event)
	if !found do return {}, false
	result := Action{
		event = strings.clone(declared.event),
		id = strings.clone(declared.id),
		args = make([dynamic]Value, 0, len(declared.args)),
	}
	for argument in declared.args {
		if argument.kind == .Keyword &&
		   strings.has_prefix(argument.text, ":event/") {
			if argument.text != ":event/value" || event_value == nil {
				action_destroy(&result)
				return {}, false
			}
			append(&result.args, value_clone(event_value^))
		} else {
			append(&result.args, value_clone(argument))
		}
	}
	return result, true
}

node_valid :: proc(node: ^Node) -> bool {
	if node == nil || len(node.tag) == 0 || len(node.key) == 0 do return false
	for property, index in node.props {
		if len(property.name) == 0 do return false
		for candidate in node.props[index + 1:] {
			if candidate.name == property.name do return false
		}
	}
	for action, index in node.actions {
		if len(action.event) == 0 || len(action.id) == 0 do return false
		for candidate in node.actions[index + 1:] {
			if candidate.event == action.event do return false
		}
	}
	for &child, index in node.children {
		if !node_valid(&child) do return false
		for &candidate in node.children[index + 1:] {
			if candidate.key == child.key do return false
		}
	}
	return true
}

Create_Proc :: proc(ctx: rawptr, node: ^Node) -> rawptr
Apply_Proc :: proc(ctx: rawptr, instance: rawptr, previous, next: ^Node)
Destroy_Proc :: proc(ctx: rawptr, instance: rawptr, node: ^Node)
Insert_Child_Proc :: proc(
	ctx: rawptr,
	parent_instance: rawptr,
	parent: ^Node,
	child_instance: rawptr,
	child: ^Node,
	index: int,
)
Remove_Child_Proc :: proc(
	ctx: rawptr,
	parent_instance: rawptr,
	parent: ^Node,
	child_instance: rawptr,
	child: ^Node,
	index: int,
)
Move_Child_Proc :: proc(
	ctx: rawptr,
	parent_instance: rawptr,
	parent: ^Node,
	child_instance: rawptr,
	child: ^Node,
	from, to: int,
)

Backend :: struct {
	create:       Create_Proc,
	apply:        Apply_Proc,
	destroy:      Destroy_Proc,
	insert_child: Insert_Child_Proc,
	remove_child: Remove_Child_Proc,
	move_child:   Move_Child_Proc,
}

backend_valid :: proc(backend: Backend) -> bool {
	return backend.create != nil && backend.apply != nil &&
		backend.destroy != nil && backend.insert_child != nil &&
		backend.remove_child != nil && backend.move_child != nil
}

Stats :: struct {
	created:   int,
	applied:   int,
	inserted:  int,
	removed:   int,
	moved:     int,
	destroyed: int,
	unchanged: int,
}

Mounted_Node :: struct {
	description: Node,
	instance:    rawptr,
	children:    [dynamic]^Mounted_Node,
}

Reconciler :: struct {
	backend: Backend,
	ctx:     rawptr,
	root:    ^Mounted_Node,
	stats:   Stats,
}

reconciler_init :: proc(
	reconciler: ^Reconciler,
	backend: Backend,
	ctx: rawptr,
) {
	assert(reconciler != nil && backend_valid(backend))
	reconciler^ = {backend = backend, ctx = ctx}
}

mounted_create :: proc(
	reconciler: ^Reconciler,
	node: ^Node,
) -> ^Mounted_Node {
	mounted := new(Mounted_Node)
	mounted.description = node_clone_shallow(node^)
	mounted.instance = reconciler.backend.create(reconciler.ctx, node)
	assert(mounted.instance != nil, "UI backend failed to create a node")
	mounted.children = make([dynamic]^Mounted_Node, 0, len(node.children))
	reconciler.stats.created += 1
	for &child, index in node.children {
		child_mounted := mounted_create(reconciler, &child)
		append(&mounted.children, child_mounted)
		reconciler.backend.insert_child(
			reconciler.ctx,
			mounted.instance,
			&mounted.description,
			child_mounted.instance,
			&child,
			index,
		)
		reconciler.stats.inserted += 1
	}
	return mounted
}

mounted_destroy :: proc(
	reconciler: ^Reconciler,
	mounted: ^Mounted_Node,
) {
	if mounted == nil do return
	for index := len(mounted.children) - 1; index >= 0; index -= 1 {
		child := mounted.children[index]
		reconciler.backend.remove_child(
			reconciler.ctx, mounted.instance, &mounted.description,
			child.instance, &child.description, index)
		reconciler.stats.removed += 1
		mounted_destroy(reconciler, child)
	}
	delete(mounted.children)
	reconciler.backend.destroy(
		reconciler.ctx, mounted.instance, &mounted.description)
	reconciler.stats.destroyed += 1
	node_destroy_shallow(&mounted.description)
	free(mounted)
}

mounted_child_index :: proc(
	mounted: ^Mounted_Node,
	key: string,
	from: int,
) -> int {
	if mounted == nil do return -1
	for index in from..<len(mounted.children) {
		if mounted.children[index].description.key == key do return index
	}
	return -1
}

mounted_children_insert :: proc(
	children: ^[dynamic]^Mounted_Node,
	index: int,
	child: ^Mounted_Node,
) {
	assert(children != nil && index >= 0 && index <= len(children^))
	append(children, child)
	for position := len(children^) - 1; position > index; position -= 1 {
		children^[position] = children^[position - 1]
	}
	children^[index] = child
}

mounted_children_move :: proc(
	children: ^[dynamic]^Mounted_Node,
	from, to: int,
) {
	assert(children != nil && from >= 0 && from < len(children^) &&
		to >= 0 && to < len(children^))
	if from == to do return
	value := children^[from]
	if from > to {
		for position := from; position > to; position -= 1 {
			children^[position] = children^[position - 1]
		}
	} else {
		for position := from; position < to; position += 1 {
			children^[position] = children^[position + 1]
		}
	}
	children^[to] = value
}

mounted_children_remove :: proc(
	children: ^[dynamic]^Mounted_Node,
	index: int,
) -> ^Mounted_Node {
	assert(children != nil && index >= 0 && index < len(children^))
	result := children^[index]
	ordered_remove(children, index)
	return result
}

mounted_reconcile :: proc(
	reconciler: ^Reconciler,
	mounted: ^Mounted_Node,
	next: ^Node,
) {
	if !node_shallow_equal(&mounted.description, next) {
		reconciler.backend.apply(
			reconciler.ctx, mounted.instance, &mounted.description, next)
		reconciler.stats.applied += 1
	} else {
		reconciler.stats.unchanged += 1
	}

	for &next_child, next_index in next.children {
		found := mounted_child_index(mounted, next_child.key, next_index)
		if found < 0 {
			child := mounted_create(reconciler, &next_child)
			mounted_children_insert(&mounted.children, next_index, child)
			reconciler.backend.insert_child(
				reconciler.ctx, mounted.instance, &mounted.description,
				child.instance, &next_child, next_index)
			reconciler.stats.inserted += 1
			continue
		}
		if found != next_index {
			child := mounted.children[found]
			reconciler.backend.move_child(
				reconciler.ctx, mounted.instance, &mounted.description,
				child.instance, &child.description, found, next_index)
			mounted_children_move(&mounted.children, found, next_index)
			reconciler.stats.moved += 1
		}
		child := mounted.children[next_index]
		if child.description.tag != next_child.tag {
			reconciler.backend.remove_child(
				reconciler.ctx, mounted.instance, &mounted.description,
				child.instance, &child.description, next_index)
			reconciler.stats.removed += 1
			removed := mounted_children_remove(&mounted.children, next_index)
			mounted_destroy(reconciler, removed)
			replacement := mounted_create(reconciler, &next_child)
			mounted_children_insert(
				&mounted.children, next_index, replacement)
			reconciler.backend.insert_child(
				reconciler.ctx, mounted.instance, &mounted.description,
				replacement.instance, &next_child, next_index)
			reconciler.stats.inserted += 1
		} else {
			mounted_reconcile(reconciler, child, &next_child)
		}
	}

	for len(mounted.children) > len(next.children) {
		index := len(mounted.children) - 1
		child := mounted.children[index]
		reconciler.backend.remove_child(
			reconciler.ctx, mounted.instance, &mounted.description,
			child.instance, &child.description, index)
		reconciler.stats.removed += 1
		removed := mounted_children_remove(&mounted.children, index)
		mounted_destroy(reconciler, removed)
	}

	node_destroy_shallow(&mounted.description)
	mounted.description = node_clone_shallow(next^)
}

reconcile :: proc(reconciler: ^Reconciler, next: ^Node) -> bool {
	if reconciler == nil || !backend_valid(reconciler.backend) ||
	   !node_valid(next) {
		return false
	}
	reconciler.stats = {}
	if reconciler.root == nil {
		reconciler.root = mounted_create(reconciler, next)
		return true
	}
	if reconciler.root.description.key != next.key ||
	   reconciler.root.description.tag != next.tag {
		mounted_destroy(reconciler, reconciler.root)
		reconciler.root = mounted_create(reconciler, next)
		return true
	}
	mounted_reconcile(reconciler, reconciler.root, next)
	return true
}

reconciler_instance :: proc(
	reconciler: ^Reconciler,
	key: string,
) -> rawptr {
	if reconciler == nil || reconciler.root == nil do return nil
	stack := make([dynamic]^Mounted_Node, 0, 16)
	defer delete(stack)
	append(&stack, reconciler.root)
	for len(stack) > 0 {
		index := len(stack) - 1
		mounted := stack[index]
		ordered_remove(&stack, index)
		if mounted.description.key == key do return mounted.instance
		for child in mounted.children do append(&stack, child)
	}
	return nil
}

reconciler_destroy :: proc(reconciler: ^Reconciler) {
	if reconciler == nil do return
	if reconciler.root != nil do mounted_destroy(reconciler, reconciler.root)
	reconciler^ = {}
}
