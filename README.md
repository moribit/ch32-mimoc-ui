# CH32V003 + Mimoc UI sample

This project uses sibling `ch32fun_zig` and `mimoc-ui` checkouts with Zig 0.16:

```sh
zig build
```

`zig-out/bin/firmware` is the RV32EC ELF; `zig-out/firmware/firmware.bin` and `.hex` are generated for flashing. The view is built with Mimoc UI's typed `enum(u16)` IDs, `Ui.begin`, a scoped `column` guard, and `view.finish()`. No application Node offsets, allocator, libc, or full framebuffer are required.

The 128×64 OLED shows **MO-BUS**, a Checkbox for Wi-Fi, a Toggle for BT, a Progress bar, and a bitmap Wi-Fi Icon. Short PD1 press moves focus between Checkbox and Toggle. Hold PD1 for **800 ms** to activate: Wi-Fi toggles and advances Progress by 25%, while BT toggles independently. Application booleans and progress remain outside Mimoc UI. Rendering uses ch32fun_zig's 128-byte SSD1306 page buffer. `runtime.update(now_ms)` runs once before each eight-page draw, leaving the presentation snapshot fixed during the draw.

The default CH32V003 profile uses `max_nodes=10`, `max_animations=0`. This demonstrates the four widget types inside 16KB Flash. The Core animation engine remains available; enabling one animation track with this exact widget set exceeds this chip's Flash limit. Reduce the widget set or use a larger target before enabling animations.

## Desktop emulator

Build `../ch32fun-desktop-emulator`, then run from this directory:

```sh
chemu
```

In a Kitty keyboard terminal, tap **Space** to move focus and hold it for 800 ms to activate. On legacy terminals, Space produces a fixed 600 ms pulse and moves focus; use **d** to hold the emulated button and **u** to release it after 800 ms for activation. For a terminal without Kitty graphics, use `chemu --graphics sixel`.

Headless verification of initial OLED pixels:

```sh
chemu --no-build --headless --steps 2000000 --dump-oled
```

The current ReleaseSmall build measures **16,184B Flash image** and **560B static RAM** (`.data` 424B + `.bss` 136B, including the 128B page buffer). The reserved firmware limit is 16,320B, leaving 136B Flash. The prior 8-node/1-track menu measured 13,844B Flash and 516B static RAM. Use `xcrun llvm-size -A zig-out/bin/firmware` and `wc -c zig-out/firmware/firmware.bin` to recheck these numbers after changes. Physical stack usage, execution time, and OLED electrical behavior still require a board.
