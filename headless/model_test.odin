#+feature dynamic-literals

// Copyright (c) Andreas Flakstad and Kvist contributors
// SPDX-License-Identifier: MIT

package ui_headless

import "core:testing"
import ui "../reconcile"

@(test)
headless_backend_retains_exact_keyed_tree :: proc(t: ^testing.T) {
	renderer: Renderer
	renderer_init(&renderer)
	defer renderer_destroy(&renderer)

	first_children := [dynamic]ui.Node{
		{tag = ":ui/text", key = ":title"},
		{tag = ":ui/button", key = ":save"},
		{tag = ":ui/button", key = ":cancel"},
	}
	defer delete(first_children)
	first := ui.Node{
		tag = ":ui/surface", key = ":root", children = first_children,
	}
	testing.expect(t, renderer_reconcile(&renderer, &first))
	testing.expect(t, renderer_matches(&renderer, &first))
	testing.expect_value(t, renderer_live_count(&renderer), 4)
	title_id, title_found := renderer_instance_id(&renderer, ":title")
	save_id, save_found := renderer_instance_id(&renderer, ":save")
	testing.expect(t, title_found && save_found)

	next_title_props := [dynamic]ui.Property{
		{name = ":text", value = {kind = .Text, text = "Changed"}},
	}
	defer delete(next_title_props)
	next_children := [dynamic]ui.Node{
		{tag = ":ui/button", key = ":save"},
		{tag = ":ui/text", key = ":title", props = next_title_props},
		{tag = ":ui/text", key = ":detail"},
	}
	defer delete(next_children)
	next := ui.Node{
		tag = ":ui/surface", key = ":root", children = next_children,
	}
	testing.expect(t, renderer_reconcile(&renderer, &next))
	testing.expect(t, renderer_matches(&renderer, &next))
	testing.expect_value(t, renderer_live_count(&renderer), 4)
	next_title_id, next_title_found := renderer_instance_id(&renderer, ":title")
	next_save_id, next_save_found := renderer_instance_id(&renderer, ":save")
	testing.expect(t, next_title_found && next_save_found)
	testing.expect_value(t, next_title_id, title_id)
	testing.expect_value(t, next_save_id, save_id)
	stats := renderer_stats(&renderer)
	testing.expect_value(t, stats.created, 1)
	testing.expect_value(t, stats.applied, 1)
	testing.expect_value(t, stats.moved, 1)
	testing.expect_value(t, stats.removed, 1)
	testing.expect_value(t, stats.destroyed, 1)
}

@(test)
headless_events_resolve_data_without_product_knowledge :: proc(t: ^testing.T) {
	renderer: Renderer
	renderer_init(&renderer)
	defer renderer_destroy(&renderer)

	args := [dynamic]ui.Value{
		{kind = .Keyword, text = ":event/value"},
		{kind = .Text, text = "stable"},
	}
	defer delete(args)
	actions := [dynamic]ui.Action{
		{event = ":change", id = ":example/set", args = args},
	}
	defer delete(actions)
	node := ui.Node{
		tag = ":ui/text-field", key = ":field", actions = actions,
	}
	testing.expect(t, renderer_reconcile(&renderer, &node))
	payload := ui.Value{kind = .Text, text = "typed"}
	action, ok := renderer_emit(&renderer, ":field", ":change", &payload)
	defer ui.action_destroy(&action)
	testing.expect(t, ok)
	testing.expect_value(t, action.id, ":example/set")
	testing.expect_value(t, len(action.args), 2)
	testing.expect_value(t, action.args[0].text, "typed")
	testing.expect_value(t, action.args[1].text, "stable")
	testing.expect_value(t, args[0].text, ":event/value")
}
