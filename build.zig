const std = @import("std");
const ch32 = @import("ch32fun_zig");

pub fn build(b: *std.Build) void {
    const target = ch32.ch32Target(b);
    const optimize = b.option(std.builtin.OptimizeMode, "optimize", "Optimization mode") orelse .ReleaseSmall;
    const ch32_dep = b.dependency("ch32fun_zig", .{});
    const mimoc_dep = b.dependency("mimoc_ui", .{ .target = target, .optimize = optimize });
    const hal = ch32.halModule(ch32_dep.builder);
    const options = b.addOptions();
    options.addOption(usize, "max_nodes", b.option(usize, "max_nodes", "Mimoc UI node capacity") orelse 10);
    options.addOption(usize, "max_animations", b.option(usize, "max_animations", "Mimoc UI animation capacity") orelse 0);

    // ch32fun_zig owns reset/interrupt startup; Mimoc UI remains an
    // application-only dependency, never a dependency of the HAL.
    const app = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });
    app.addImport("ch32fun", hal);
    app.addImport("mimoc_ui", mimoc_dep.module("mimoc_ui"));
    app.addOptions("build_options", options);

    const startup = b.createModule(.{
        .root_source_file = ch32_dep.path("src/firmware.zig"),
        .target = target,
        .optimize = optimize,
        .link_libc = false,
    });
    startup.addImport("app", app);
    startup.addImport("ch32fun", hal);

    const fw = b.addExecutable(.{ .name = "firmware", .root_module = startup, .linkage = .static });
    fw.bundle_compiler_rt = true;
    fw.link_gc_sections = true;
    fw.link_function_sections = true;
    fw.link_data_sections = true;
    fw.setLinkerScript(ch32_dep.path("src/runtime/linker.ld"));
    b.installArtifact(fw);
    const bin = fw.addObjCopy(.{ .format = .bin, .basename = "firmware.bin" });
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(bin.getOutput(), .{ .custom = "firmware" }, "firmware.bin").step);
    const hex = fw.addObjCopy(.{ .format = .hex, .basename = "firmware.hex" });
    b.getInstallStep().dependOn(&b.addInstallFileWithDir(hex.getOutput(), .{ .custom = "firmware" }, "firmware.hex").step);
}
