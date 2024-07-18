const std = @import("std");

const xrgen = @import("src/main.zig");
pub const VkGenerateStep = xrgen.XrGenerateStep;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const maybe_registry: ?[]const u8 = b.option([]const u8, "registry", "Set the path to the OpenXR registry (xr.xml)");
    const test_step = b.step("test", "Run all the tests");

    // Using the package manager, this artifact can be obtained by the user
    // through `b.dependency(<name in build.zig.zon>, .{}).artifact("openxr-zig-generator")`.
    // with that, the user need only `.addArg("path/to/xr.xml")`, and then obtain
    // a file source to the generated code with `.addOutputArg("xr.zig")`
    const generator_exe = b.addExecutable(.{
        .name = "openxr-zig-generator",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(generator_exe);

    // Or they can skip all that, and just make sure to pass `.registry = "path/to/xr.xml"` to `b.dependency`,
    // and then obtain the module directly via `.module("openxr-zig")`.
    if (maybe_registry) |registry| {
        const xr_generate_cmd = b.addRunArtifact(generator_exe);

        xr_generate_cmd.addArg(registry);

        const xr_zig = xr_generate_cmd.addOutputFileArg("xr.zig");
        const xr_zig_module = b.addModule("openxr-zig", .{
            .root_source_file = xr_zig,
        });

        // Also install xr.zig, if passed.

        const xr_zig_install_step = b.addInstallFile(xr_zig, "src/xr.zig");
        b.getInstallStep().dependOn(&xr_zig_install_step.step);

        // And run tests on this xr.zig too.

        // This test needs to be an object so that openxr-zig can import types from the root.
        // It does not need to run anyway.
        const ref_all_decls_test = b.addObject(.{
            .name = "ref-all-decls-test",
            .root_source_file = b.path("test/ref_all_decls.zig"),
            .target = target,
            .optimize = optimize,
        });
        ref_all_decls_test.root_module.addImport("vulkan", xr_zig_module);
        test_step.dependOn(&ref_all_decls_test.step);
    }

    const test_target = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
    });
    test_step.dependOn(&b.addRunArtifact(test_target).step);
}
