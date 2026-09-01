package ui_reconcile

import "core:mem"
import "core:strings"

// Property_Spec and Action_Spec are borrowed authoring values.
// Their string and slice storage only needs to remain valid for the duration
// of a node call; Builder establishes native ownership for the resulting tree.
Property_Spec :: struct {
	name:  string,
	value: Value,
}

Action_Spec :: struct {
	event: string,
	id:    string,
	args:  []Value,
}

Node_Options :: struct {
	props:    []Property_Spec,
	actions:  []Action_Spec,
	children: []Node,
}

// Builder owns every string and array produced by node. A built tree
// remains valid until builder_reset or builder_destroy. Reconciliation clones
// the mounted description, so callers may reset the builder immediately after
// a successful reconcile call.
Builder :: struct {
	arena:       mem.Dynamic_Arena,
	allocator:   mem.Allocator,
	initialized: bool,
}

builder_init :: proc(
	builder: ^Builder,
	backing_allocator := context.allocator,
) {
	assert(builder != nil)
	assert(!builder.initialized, "destroy a UI Builder before reinitializing it")
	builder^ = {}
	mem.dynamic_arena_init(
		&builder.arena,
		backing_allocator,
		backing_allocator,
	)
	builder.allocator = mem.dynamic_arena_allocator(&builder.arena)
	builder.initialized = true
}

// Reset invalidates every tree previously returned by node while retaining
// arena blocks for the next description. It is the intended per-render path.
builder_reset :: proc(builder: ^Builder) {
	if builder == nil || !builder.initialized do return
	mem.dynamic_arena_reset(&builder.arena)
}

builder_destroy :: proc(builder: ^Builder) {
	if builder == nil || !builder.initialized do return
	mem.dynamic_arena_destroy(&builder.arena)
	builder^ = {}
}

none :: proc() -> Value {
	return {kind = .None}
}

boolean :: proc(value: bool) -> Value {
	return {kind = .Bool, bool_value = value}
}

integer :: proc(value: i64) -> Value {
	return {kind = .Int, int_value = value}
}

decimal :: proc(value: f64) -> Value {
	return {kind = .Float, float_value = value}
}

text :: proc(value: string) -> Value {
	return {kind = .Text, text = value}
}

keyword :: proc(value: string) -> Value {
	return {kind = .Keyword, text = value}
}

property :: proc(name: string, value: Value) -> Property_Spec {
	return {name = name, value = value}
}

action :: proc(
	event, id: string,
	args: []Value = nil,
) -> Action_Spec {
	return {event = event, id = id, args = args}
}

@(private)
builder_clone_value :: proc(builder: ^Builder, value: Value) -> Value {
	result := value
	if value.kind == .Text || value.kind == .Keyword {
		result.text = strings.clone(value.text, builder.allocator)
	}
	return result
}

// node builds one arena-owned node from borrowed options. Child nodes must
// have been built by the same Builder during the current reset generation.
// Returning Node by value makes ordinary Odin component procedures safe and
// composable; their arrays and strings live in the Builder rather than the
// component's stack frame.
node :: proc(
	builder: ^Builder,
	tag, key: string,
	options: Node_Options = {},
) -> Node {
	assert(builder != nil && builder.initialized)
	result := Node{
		tag = strings.clone(tag, builder.allocator),
		key = strings.clone(key, builder.allocator),
		props = make(
			[dynamic]Property,
			0,
			len(options.props),
			builder.allocator,
		),
		actions = make(
			[dynamic]Action,
			0,
			len(options.actions),
			builder.allocator,
		),
		children = make(
			[dynamic]Node,
			0,
			len(options.children),
			builder.allocator,
		),
	}

	for source in options.props {
		append(&result.props, Property{
			name = strings.clone(source.name, builder.allocator),
			value = builder_clone_value(builder, source.value),
		})
	}
	for source in options.actions {
		args := make(
			[dynamic]Value,
			0,
			len(source.args),
			builder.allocator,
		)
		for value in source.args {
			append(&args, builder_clone_value(builder, value))
		}
		append(&result.actions, Action{
			event = strings.clone(source.event, builder.allocator),
			id = strings.clone(source.id, builder.allocator),
			args = args,
		})
	}
	for child in options.children do append(&result.children, child)
	return result
}
