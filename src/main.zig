const std = @import("std");
const ClassFile = @import("bytecode/ClassFile.zig");
const VFS = @import("vfs/VFS.zig");

pub fn main() void {}

test "does it parse" {
    var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arenaAllocator.allocator();
    defer arenaAllocator.deinit();

    const cf = try VFS.parseClass(std.fs.cwd(), "/home/tobi/doc/projects/casino/out/production/casino/src/View_GUI/CasinoView.class", allocator);

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
     
    try VFS.walk(allocator, "/home/tobi/dld/client/client.jar", "");
    try VFS.walk(allocator, "/home/tobi/doc/ghidra/support/LaunchSupport.jar", "");
    _ = try VFS.read("/home/tobi/dld/client/client.jar", "net/minecraft/client/main/Main.class", allocator);
    _ = try VFS.read("/home/tobi/doc/ghidra/support/LaunchSupport.jar", "LaunchSupport.class", allocator);
    _ = try VFS.read("/home/tobi/doc/projects/casino/out/production/casino/", "src/Main.class", allocator);
}

pub fn printClassFile(classFile: *const ClassFile, writer: *std.Io.Writer) !void {
    @setEvalBranchQuota(500000);
    try std.json.Stringify.value(classFile.*, .{ .whitespace = .indent_2}, writer);
    try writer.flush();
}
