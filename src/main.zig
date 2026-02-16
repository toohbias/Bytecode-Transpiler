const std = @import("std");
const Bytecode_Transpiler = @import("Bytecode_Transpiler");
const Validator = @import("ClassFileValidator.zig");
const ClassFile = @import("ClassFile.zig");
const VFS = @import("VFS.zig");

pub fn main() void {}

test "does it parse" {
    var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arenaAllocator.allocator();
    defer arenaAllocator.deinit();

    const cf = try VFS.parseClassFromDir(std.fs.cwd(), "/home/tobi/doc/projects/casino/out/production/casino/src/View_GUI/CasinoView.class", allocator);

    var buffer: [4096]u8 = undefined;
    var file = try std.fs.cwd().createFile("output.json", .{});
    defer file.close();
    var writer = file.writer(&buffer);
    const stdout = &writer.interface;

    try printClassFile(&cf, stdout);
}

test "zip" {
    var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arenaAllocator.allocator();
    defer arenaAllocator.deinit();
     
    try VFS.readZip(allocator, "/home/tobi/dld/client/client.jar");
    try VFS.readZip(allocator, "/home/tobi/doc/ghidra/support/LaunchSupport.jar");
    _ = try VFS.readJar("/home/tobi/dld/client/client.jar", "net/minecraft/client/main/Main.class", allocator);
    _ = try VFS.readJar("/home/tobi/doc/ghidra/support/LaunchSupport.jar", "LaunchSupport.class", allocator);
}

pub fn printClassFile(classFile: *const ClassFile.ClassFile, writer: *std.Io.Writer) !void {
    @setEvalBranchQuota(500000);
    try std.json.Stringify.value(classFile.*, .{ .whitespace = .indent_2}, writer);
    try writer.flush();
}
