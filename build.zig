const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Read version from VERSION file, fallback to "dev"
    const version = b.option([]const u8, "version", "Version string") orelse blk: {
        const version_file = std.fs.cwd().openFile("VERSION", .{}) catch break :blk "dev";
        defer version_file.close();
        var buf: [32]u8 = undefined;
        const bytes_read = version_file.readAll(&buf) catch break :blk "dev";
        // Trim trailing newline
        var len = bytes_read;
        while (len > 0 and (buf[len - 1] == '\n' or buf[len - 1] == '\r')) : (len -= 1) {}
        break :blk b.dupe(buf[0..len]);
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
