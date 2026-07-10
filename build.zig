const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Read version from VERSION file, fallback to "dev"
    const version = b.option([]const u8, "version", "Version string") orelse blk: {
        var buf: [32]u8 = undefined;
        const contents = b.build_root.handle.readFile(b.graph.io, "VERSION", &buf) catch break :blk "dev";
        break :blk b.dupe(std.mem.trim(u8, contents, " \t\r\n"));
    };

    const exe_module = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    // Pass version as build option
    const options = b.addOptions();
    options.addOption([]const u8, "version", version);
    exe_module.addOptions("build_options", options);

    const exe = b.addExecutable(.{
        .name = "lispium",
        .root_module = exe_module,
    });

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Test step
    const unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/tests.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);

}
