# CH32V003 + Mimoc UI sample

This project depends on sibling `ch32fun_zig` and `mimoc-ui` checkouts. Build with Zig 0.16:

```sh
zig build
```

`zig-out/bin/firmware` is the RV32EC ELF. `zig-out/firmware/firmware.bin` and `firmware.hex` are also generated. The default configuration uses eight Mimoc UI nodes, one animation track, no heap, and ch32fun_zig's 128-byte SSD1306 page buffer.

The screen shows **MO-BUS**, CHAT, CQ, and EHAGAKI. Each press of the PD1 pull-up button advances focus; an independent two-pixel selection marker slides to the focused row. Mimoc UI renders each of the eight display pages into the HAL's own page buffer. `runtime.update(now_ms)` runs once before the page loop, so every page uses the same presentation state.

## Desktop emulator

Build `../ch32fun-desktop-emulator` first, then run from this directory:

```sh
chemu
```

In the emulator, press **Space** to trigger the PD1 button and change focus. For a terminal without Kitty graphics, use `chemu --graphics sixel`. A headless display dump is available with:

```sh
chemu --no-build --headless --steps 2000000 --dump-oled
```

The linked image and static RAM can be checked on macOS with `xcrun llvm-size -A zig-out/bin/firmware`. The default ReleaseSmall build measured 13,844 bytes of Flash image and 516 bytes of static RAM (`.data` 380B + `.bss` 136B, including the 128-byte page buffer). The emulator validates display traffic and screen pixels; physical stack usage, timing and OLED behavior still require a board.

With the default 8-node/1-track build, a 2,000,000-step headless run reached the complete MO-BUS menu, transferred OLED pages over I2C, and reported 688 nonzero VRAM bytes. Space-button focus cycling is available in the interactive emulator; the headless run does not inject button input.
