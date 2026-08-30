// Copyright (c) Andreas Flakstad and Kvist contributors
// SPDX-License-Identifier: MIT

package odin_counter

import "core:fmt"
import headless "../../headless"
import ui "../../reconcile"

counter_view :: proc(builder: ^ui.Builder, label: string) -> ui.Node {
	return ui.node(builder, ui.TAG_STACK, "counter", {
		props = []ui.Property_Spec{
			ui.property(
				ui.PROP_ORIENTATION,
				ui.keyword(ui.ORIENTATION_VERTICAL),
			),
			ui.property(ui.PROP_GAP, ui.keyword(":control")),
		},
		children = []ui.Node{
			ui.node(builder, ui.TAG_TEXT, "value", {
				props = []ui.Property_Spec{
					ui.property(ui.PROP_TEXT, ui.text(label)),
				},
			}),
			ui.node(builder, ui.TAG_BUTTON, "increment", {
				props = []ui.Property_Spec{
					ui.property(ui.PROP_LABEL, ui.text("Increment")),
				},
				actions = []ui.Action_Spec{
					ui.action(
						ui.EVENT_ACTIVATE,
						":counter/increment",
					),
				},
			}),
		},
	})
}

main :: proc() {
	descriptions: ui.Builder
	ui.builder_init(&descriptions)
	defer ui.builder_destroy(&descriptions)

	renderer: headless.Renderer
	headless.renderer_init(&renderer)
	defer headless.renderer_destroy(&renderer)

	first := counter_view(&descriptions, "0")
	assert(headless.renderer_reconcile(&renderer, &first))

	// The renderer retained what it needs, so the description arena is ready
	// for the next immutable view.
	ui.builder_reset(&descriptions)
	next := counter_view(&descriptions, "1")
	assert(headless.renderer_reconcile(&renderer, &next))

	stats := headless.renderer_stats(&renderer)
	fmt.printf(
		"%s: %d node updated, %d created\n",
		next.tag,
		stats.applied,
		stats.created,
	)
}
