const fun = @import("ch32fun");
const ui = @import("mimoc_ui");
const options = @import("build_options");
const adapter = @import("adapter.zig");

pub const ch32fun_ssd1306_buffer_mode = .page;
pub const ch32fun_ssd1306_basic_ascii_font = true;
pub const ch32fun_swio_log_enabled = false;

const Id = enum(u16) { screen, title, wifi, bluetooth, progress, icon };
const Display = ui.runtime.Runtime(.{ .max_nodes = options.max_nodes, .max_animations = options.max_animations });
const View = ui.ui.Ui(Id, Display.configuration);
var runtime: Display = .{};
var wifi = true;
var bluetooth = false;
var progress: u16 = 25;

fn rebuild() void {
    var view = View.begin(&runtime);
    {
        var screen = view.column(.screen, .{ .padding = 2, .spacing = 2 });
        defer screen.end();
        view.text(.title, "MO-BUS");
        view.checkbox(.wifi, "WI-FI", wifi);
        view.toggleWith(.bluetooth, "BT", bluetooth, .{ .width = 116 });
        view.progressWith(.progress, progress, 100, .{ .width = 116 });
        view.icon(.icon, ui.widgets.icons.wifi);
    }
    view.finish();
}

fn activate() void {
    const focused = runtime.action(.activate) orelse return;
    if (focused == View.childId(View.rootId(.screen), .wifi)) {
        wifi = !wifi;
        progress = if (progress == 100) 0 else progress + 25;
    } else {
        bluetooth = !bluetooth;
    }
    rebuild();
}

pub fn main() noreturn {
    fun.system.init(.{});
    fun.time.systick.init(1000);
    fun.input.initButtonPd1Pullup();
    fun.ssd1306.initI2c() catch unreachable;
    fun.ssd1306.initPanel() catch unreachable;

    var now_ms: u32 = 0;
    var last_cycles = fun.time.nowCycles();
    var cycle_remainder: u32 = 0;
    var previous_pressed = false;
    var pressed_at: u32 = 0;
    runtime.update(now_ms);
    rebuild();

    while (true) {
        const current_cycles = fun.time.nowCycles();
        const elapsed_cycles = current_cycles -% last_cycles;
        last_cycles = current_cycles;
        const ticks_per_ms = fun.system.core_clock_hz / 1000;
        const fractional_cycles = cycle_remainder + (elapsed_cycles % ticks_per_ms);
        now_ms +%= elapsed_cycles / ticks_per_ms + fractional_cycles / ticks_per_ms;
        cycle_remainder = fractional_cycles % ticks_per_ms;
        runtime.update(now_ms);

        const pressed = fun.input.isButtonPressed();
        if (pressed and !previous_pressed) pressed_at = now_ms;
        if (!pressed and previous_pressed) {
            const held_ms = now_ms -% pressed_at;
            if (held_ms >= 800) {
                activate();
            } else {
                _ = runtime.action(.down);
            }
        }
        previous_pressed = pressed;
        adapter.draw(&runtime) catch unreachable;
        fun.time.delayMs(10);
    }
}
