package builder_benchmark

import "core:fmt"
import "core:time"
import headless "../../headless"
import ui "../../reconcile"

ITERATIONS :: 100_000

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

nanoseconds_per_operation :: proc(elapsed: time.Duration) -> f64 {
	return f64(time.duration_nanoseconds(elapsed)) / f64(ITERATIONS)
}

main :: proc() {
	labels := [2]string{"0", "1"}
	checksum: int

	builder: ui.Builder
	ui.builder_init(&builder)
	defer ui.builder_destroy(&builder)

	build_start := time.tick_now()
	for index in 0 ..< ITERATIONS {
		view := counter_view(&builder, labels[index % len(labels)])
		checksum += len(view.children)
		ui.builder_reset(&builder)
	}
	build_elapsed := time.tick_since(build_start)

	renderer: headless.Renderer
	headless.renderer_init(&renderer)
	defer headless.renderer_destroy(&renderer)

	reconcile_start := time.tick_now()
	for index in 0 ..< ITERATIONS {
		view := counter_view(&builder, labels[index % len(labels)])
		assert(headless.renderer_reconcile(&renderer, &view))
		checksum += headless.renderer_stats(&renderer).applied
		ui.builder_reset(&builder)
	}
	reconcile_elapsed := time.tick_since(reconcile_start)

	fmt.printf(
		"builder: %.1f ns/op\nbuilder + keyed reconcile: %.1f ns/op\nchecksum: %d\n",
		nanoseconds_per_operation(build_elapsed),
		nanoseconds_per_operation(reconcile_elapsed),
		checksum,
	)
}
