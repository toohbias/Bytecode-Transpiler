const std = @import("std");
const Bytecode_Transpiler = @import("Bytecode_Transpiler");
const Parser = @import("ClassFileParser.zig");
const ClassFile = @import("ClassFile.zig");
const OpCode = @import("OpCode.zig").OpCode;

pub fn main() void {}

test "does it parse" {
    var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arenaAllocator.allocator();
    defer arenaAllocator.deinit();

    var byteReader = try Parser.getSourceReader("/home/tobi/doc/projects/casino/out/production/casino/src/View_GUI/CasinoView.class", allocator);
    var cf: ClassFile.ClassFile = undefined;
    _ = try Parser.parseStruct(ClassFile.ClassFile, &cf, &byteReader, allocator);

    try std.testing.expect(try byteReader.discardRemaining() == 0);
    
    var buffer: [1024]u8 = undefined;
    var file = try std.fs.cwd().createFile("output.json", .{});
    defer file.close();
    var writer = file.writer(&buffer);
    const stdout = &writer.interface;

    try printClassFile(&cf, stdout);
}

pub fn printClassFile(classFile: *ClassFile.ClassFile, writer: *std.Io.Writer) !void {
    @setEvalBranchQuota(500000);
    try std.json.Stringify.value(classFile.*, .{ .whitespace = .indent_2}, writer);
    try writer.flush();
}
