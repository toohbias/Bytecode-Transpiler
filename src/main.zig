const std = @import("std");
const Bytecode_Transpiler = @import("Bytecode_Transpiler");
const Parser = @import("ClassFileParser.zig");
const ClassFile = @import("ClassFile.zig");

pub fn main() !void {
    var arenaAllocator = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    const allocator = arenaAllocator.allocator();
    defer arenaAllocator.deinit();

    var byteReader = try Parser.getSourceReader("/home/tobi/doc/projects/casino/out/production/casino/src/View_GUI/CasinoView.class", allocator);
    var cf: ClassFile.ClassFile = undefined;
    _ = try Parser.parseStruct(ClassFile.ClassFile, &cf, &byteReader, allocator);
    std.debug.print("\n{}\n", .{try byteReader.discardRemaining()}); // should be 0
}
