//! Analysis-only firmware. Variant selection is a comptime build option.
//! The normal application remains src/main.zig.
const fun = @import("ch32fun");
const ui = @import("mimoc_ui");
const options = @import("build_options");
const adapter = @import("adapter.zig");

pub const ch32fun_ssd1306_buffer_mode = .page;
pub const ch32fun_ssd1306_basic_ascii_font = true;
pub const ch32fun_swio_log_enabled = false;

const variant = options.size_variant;
const Config = if (variant == 80 or variant == 83)
    .{ .max_nodes = options.max_nodes, .max_animations = options.max_animations, .diagnostics = true }
else
    .{ .max_nodes = options.max_nodes, .max_animations = options.max_animations };
const Display = ui.runtime.Runtime(Config);
const Id = enum(u16) {
    root,
    title,
    box,
    extra,
    button,
    checkbox,
    toggle,
    progress,
    icon,
    divider,
    panel,
    scrollbar,
    wrap,
    tuner,
    knob,
    list,
    scroll,
    item_a,
    item_b,
    bitmap,
};
const View = ui.ui.Ui(Id, Config);
const markers = [_]ui.widgets.Marker{ .{}, .{ .pending = true }, .{ .unread = true } };
const pixels = [_]u8{ 0x81, 0x42, 0x24, 0x18, 0x18, 0x24, 0x42, 0x81 };
var runtime: Display = .{};
var wifi = true;
var progress: u16 = 25;

fn lowText() void {
    var builder = runtime.beginView();
    builder.add(.{ .id = 1, .kind = .text, .text = "A" }) catch @trap();
    runtime.finishView(&builder) catch @trap();
}

fn lowPair() void {
    var builder = runtime.beginView();
    builder.begin(1, .stack, 0, 0, .start) catch @trap();
    builder.add(.{ .id = 2, .kind = .text, .text = "A" }) catch @trap();
    builder.add(.{ .id = 3, .kind = .rect, .min_size = .{ .w = 16, .h = 8 } }) catch @trap();
    builder.end();
    runtime.finishView(&builder) catch @trap();
}

fn highPair() void {
    var view = View.begin(&runtime);
    if (variant == 80) view.screen("SIZE_PROBE");
    {
        var root = view.stack(.root, .{});
        defer root.end();
        view.text(.title, "A");
        view.rect(.box, .{ .w = 16, .h = 8 });
    }
    if (variant == 81) view.finishChecked() catch @trap() else view.finish();
}

fn rawPair() void {
    const Raw = ui.ui.Ui(u16, Config);
    var view = Raw.begin(&runtime);
    {
        var root = view.stack(0, .{});
        defer root.end();
        view.text(1, "A");
        view.rect(2, .{ .w = 16, .h = 8 });
    }
    view.finish();
}

fn highVariant() void {
    var view = View.begin(&runtime);
    {
        var root = switch (variant) {
            7 => view.column(.root, .{}),
            8 => view.row(.root, .{}),
            9 => view.column(.root, .{ .padding = 2, .spacing = 2, .alignment = .center }),
            else => view.stack(.root, .{}),
        };
        defer root.end();
        view.text(.title, "A");
        view.rect(.box, .{ .w = 16, .h = 8 });
        switch (variant) {
            19 => view.text(.extra, "B"),
            20, 5 => view.button(.button, "GO"),
            21 => view.checkbox(.checkbox, "WI-FI", wifi),
            22 => view.toggleWith(.toggle, "BT", true, .{ .width = 50 }),
            23 => view.progressWith(.progress, progress, 100, .{ .width = 50 }),
            24 => view.icon(.icon, ui.widgets.icons.wifi),
            25 => view.divider(.divider, 32),
            26 => {
                var panel = view.panel(.panel, "PANEL", .{ .w = 40, .h = 24 }, .{});
                panel.end();
            },
            27 => view.scrollbar(.scrollbar, 32, 100, 20, 3),
            28 => view.wrappedText(.wrap, "HELLO WORLD", 26),
            29 => view.tuner(.tuner, .{ .markers = &markers, .selected = 1, .width = 50 }),
            30 => view.knob(.knob, .{ .value = 1 }),
            31 => {
                var list = view.list(.list, .{ .w = 50, .h = 20 }, 0, .{});
                view.listItem(.item_a, "A", 48, false);
                view.listItem(.item_b, "B", 48, false);
                list.end();
            },
            32 => {
                var scroll = view.scrollView(.scroll, .{ .size = .{ .w = 50, .h = 20 } });
                view.text(.item_a, "A");
                scroll.end();
            },
            33 => view.bitmap(.bitmap, .{ .width = 8, .height = 8, .stride = 1, .data = &pixels }),
            else => {},
        }
    }
    view.finish();
}

fn cumulative() void {
    var view = View.begin(&runtime);
    {
        var root = view.column(.root, .{ .padding = 2, .spacing = 2 });
        defer root.end();
        view.text(.title, "MO-BUS");
        if (variant >= 41) view.checkbox(.checkbox, "WI-FI", wifi);
        if (variant >= 42) view.toggleWith(.toggle, "BT", true, .{ .width = 116, .animation = if (variant == 45) .easeOut(160) else .{} });
        if (variant >= 43) view.progressWith(.progress, progress, 100, .{ .width = 116, .animation = if (variant == 45) .easeOut(160) else .{} });
        if (variant >= 44) view.icon(.icon, ui.widgets.icons.wifi);
    }
    view.finish();
}

fn buildView() void {
    switch (variant) {
        1 => lowText(),
        2 => lowPair(),
        3, 4, 80, 81, 83 => highPair(),
        82 => rawPair(),
        40...45 => cumulative(),
        else => highVariant(),
    }
}

fn directPage(page: u8) void {
    @memset(fun.ssd1306.buffer[0..], 0);
    if (variant == 0) return;
    var surface = ui.surface.Mono1.page(fun.ssd1306.buffer[0..], 128, page) catch @trap();
    var renderer = ui.mono1.Renderer.init(&surface);
    switch (variant) {
        60 => {},
        61 => renderer.pixel(2, 2, true),
        62 => renderer.hline(2, 2, 12, true),
        63 => renderer.vline(2, 2, 6, true),
        64 => renderer.line(2, 2, 14, 6, true),
        65 => renderer.rect(.{ .x = 2, .y = 1, .w = 12, .h = 6 }, true),
        66 => renderer.fillRect(.{ .x = 2, .y = 1, .w = 12, .h = 6 }, true),
        67 => renderer.bitmap(2, 1, 8, 8, &pixels),
        68 => ui.font.draw(&renderer, .tiny5x7, 2, 1, "A", true),
        69 => {
            renderer.setClip(.{ .x = 2, .y = 1, .w = 12, .h = 6 });
            renderer.pixel(2, 2, true);
        },
        84 => {
            const p: u16 = page;
            const key = ui.ui.derive(p, p +% 3, 1);
            renderer.pixel(@intCast(key & 127), 2, true);
        },
        85 => {
            // Non-equivalent arithmetic baseline for mixer cost only.
            const p: u16 = page;
            const key = p +% (p +% 3) +% 1;
            renderer.pixel(@intCast(key & 127), 2, true);
        },
        else => {},
    }
}

fn drawHal() void {
    fun.ssd1306.firstPage();
    var page: u8 = 0;
    while (true) {
        directPage(page);
        if (!(fun.ssd1306.nextPage() catch @trap())) break;
        page += 1;
    }
}

pub fn main() noreturn {
    fun.system.init(.{});
    fun.time.systick.init(1000);
    if (variant == 4 or variant == 5) fun.input.initButtonPd1Pullup();
    fun.ssd1306.initI2c() catch @trap();
    fun.ssd1306.initPanel() catch @trap();

    var now_ms: u32 = 0;
    var last_cycles = fun.time.nowCycles();
    var cycle_remainder: u32 = 0;
    var previous_pressed = false;
    if (variant != 0 and (variant < 60 or (variant >= 80 and variant < 84))) {
        runtime.update(now_ms);
        buildView();
    }
    while (true) {
        const current_cycles = fun.time.nowCycles();
        const elapsed_cycles = current_cycles -% last_cycles;
        last_cycles = current_cycles;
        const ticks_per_ms = fun.system.core_clock_hz / 1000;
        const fractional_cycles = cycle_remainder + (elapsed_cycles % ticks_per_ms);
        now_ms +%= elapsed_cycles / ticks_per_ms + fractional_cycles / ticks_per_ms;
        cycle_remainder = fractional_cycles % ticks_per_ms;
        if (variant != 0 and (variant < 60 or (variant >= 80 and variant < 84))) runtime.update(now_ms);
        if (variant == 4 or variant == 5) {
            const pressed = fun.input.isButtonPressed();
            if (pressed and !previous_pressed) {
                if (variant == 4) {
                    _ = runtime.action(.down);
                } else {
                    const selected = runtime.action(.activate);
                    if (selected == View.childId(View.rootId(.root), .button)) wifi = !wifi;
                }
            }
            previous_pressed = pressed;
        }
        if (variant == 0 or (variant >= 60 and variant < 80) or variant == 84 or variant == 85) drawHal() else adapter.draw(&runtime) catch @trap();
        fun.time.delayMs(10);
    }
}
