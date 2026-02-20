const std = @import("std");
const Allocator = std.mem.Allocator;

const Errors = @import("../Errors.zig");
const VFSParseError = Errors.VFSParseError;

const JarFile = @import("JarFile.zig");
const Directory = @import("Directory.zig");

const ClassFile = @import("../bytecode/ClassFile.zig");

const Self = @This();


paths: std.StringHashMap(*const ClassFile),


const SourceType = enum {
    Jar,
    Dir,
};

fn isJarOrDir(path: []const u8) SourceType {
    return if(std.mem.eql(u8, path[path.len-4..], ".jar")) .Jar else .Dir;
}

pub fn walk(allocator: Allocator, path: []const u8, subdir: []const u8) VFSParseError!void {
    switch(isJarOrDir(path)) {
        .Jar => try JarFile.walk(allocator, path, subdir),
        .Dir => try Directory.walk(allocator, path, subdir),
    }
}

pub fn read(path: []const u8, classpath: ?[:0]const u8, allocator: Allocator) VFSParseError!Self {
    switch(isJarOrDir(path)) {
        .Jar => return try JarFile.read(allocator, path, classpath),
        .Dir => {
            if(classpath) |cp| {
                return try Directory.read(allocator, path, cp);
            } else {
                std.debug.print("classpath is needed for non-jar sources!\n", .{});
                return Errors.VFSError.InvalidInput;
            }
        },
    }
}

pub fn parseClass(dir: std.fs.Dir, name: [:0]const u8, allocator: Allocator) VFSParseError!ClassFile {
    return try Directory.parseClass(dir, name, allocator);
}
