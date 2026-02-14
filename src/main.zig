const std = @import("std");
const Bytecode_Transpiler = @import("Bytecode_Transpiler");
const Parser = @import("ClassFileParser.zig");
const Validator = @import("ClassFileValidator.zig");
const ClassFile = @import("ClassFile.zig");
const OpCode = @import("OpCode.zig").OpCode;
const VFS = @import("VFS.zig");

pub fn main() void {}

test "does it parse" {
    var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arenaAllocator.allocator();
    defer arenaAllocator.deinit();

    var byteReader = try Parser.getSourceReader("/home/tobi/doc/projects/casino/out/production/casino/src/View_GUI/CasinoView.class", allocator);
    var cf: ClassFile.ClassFile = undefined;
    _ = try Parser.parseStruct(ClassFile.ClassFile, &cf, &byteReader, allocator);

    Validator.validate(&cf, &byteReader, .{});
    
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
     
    try VFS.readJar("/home/tobi/dld/client.jar", null, allocator);
    // try VFS.readJar("/home/tobi/doc/ghidra/support/LaunchSupport.jar", null, allocator);
}

pub fn printClassFile(classFile: *ClassFile.ClassFile, writer: *std.Io.Writer) !void {
    @setEvalBranchQuota(500000);
    try std.json.Stringify.value(classFile.*, .{ .whitespace = .indent_2}, writer);
    try writer.flush();
}
