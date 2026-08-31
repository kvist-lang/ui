// Copyright (c) Andreas Flakstad and Kvist contributors
// SPDX-License-Identifier: MIT

package flat_tree_benchmark

import "core:fmt"
import "core:time"
import headless "../../headless"
import ui "../../reconcile"

ITERATIONS :: 200

measure_unchanged_tree :: proc(row_count: int) -> f64 {
	builder: ui.Builder
	ui.builder_init(&builder)
	defer ui.builder_destroy(&builder)
	children := make([dynamic]ui.Node, 0, row_count)
	defer delete(children)
	for index in 0..<row_count {
		key := fmt.aprintf("row-%d", index)
		append(&children, ui.node(
			&builder, ui.TAG_TREE_ITEM, key, {
				props = []ui.Property_Spec{
					ui.property(ui.PROP_LABEL, ui.text(key)),
				},
			},
		))
		delete(key)
	}
	tree := ui.node(&builder, ui.TAG_TREE, "tree", {children = children[:]})

	renderer: headless.Renderer
	headless.renderer_init(&renderer)
	defer headless.renderer_destroy(&renderer)
	assert(headless.renderer_reconcile(&renderer, &tree))

	started := time.tick_now()
	for _ in 0..<ITERATIONS {
		assert(headless.renderer_reconcile(&renderer, &tree))
	}
	elapsed := time.tick_since(started)
	return f64(time.duration_nanoseconds(elapsed)) /
		f64(ITERATIONS) / 1_000_000.0
}

main :: proc() {
	sizes := [4]int{500, 1_000, 2_000, 5_000}
	for size in sizes {
		fmt.printf(
			"unchanged flat tree: rows=%d reconcile=%.3f ms\n",
			size, measure_unchanged_tree(size),
		)
	}
}
