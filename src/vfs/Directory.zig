const std = @import("std");
const Allocator = std.mem.Allocator;

const ClassFile = @import("../bytecode/ClassFile.zig");

const Errors = @import("../Errors.zig");
const VFSParseError = Errors.VFSParseError;

const fs = std.fs;

const VFS = @import("VFS.zig");

// this is mostly for testing purposes
pub fn walk(allocator: Allocator, path: []const u8, subdir: []const u8) VFSParseError!void {
    _ = .{allocator, path, subdir};
    // TODO
}

pub fn read(allocator: Allocator, path: []const u8, classpath: [:0]const u8) VFSParseError!VFS {
    const abs_path = fs.cwd().realpathAlloc(allocator, path) catch return Errors.MemoryError;
    defer allocator.free(abs_path);
    const dir = fs.cwd().makeOpenPath(abs_path, .{}) catch return Errors.FileSystemError.OpeningFailed;

    const root: ClassFile = try parseClass(dir, classpath, allocator);

    var vfs: VFS = .{ .paths = std.StringHashMap(*const ClassFile).init(allocator) };
    vfs.paths.put(root.getName(), &root)
        catch return Errors.MemoryError;

    // archive needs .class extension that is not present in classfile paths
    var classfile_name = [_]u8{0} ** 512;
    const dot_class = ".class";
    for(dot_class, 505..) |c, it| {
        classfile_name[it] = c;
    }

    try addDependencyRecursive(&vfs, dir, allocator, &classfile_name, &root);

    return vfs;
}

pub fn parseClass(dir: fs.Dir, name: [:0]const u8, allocator: Allocator) VFSParseError!ClassFile {
    const source = dir.openFileZ(name, .{}) catch return Errors.FileSystemError.OpeningFailed;
    defer source.close();
    
    const stat = source.stat() catch return Errors.FileSystemError.StatFailed;
    const buffer: []u8 = source.readToEndAlloc(allocator, stat.size) catch return Errors.MemoryError;

    var reader = std.Io.Reader.fixed(buffer);
    return try ClassFile.parseAndValidate(&reader, allocator, .{});
}

fn addDependencyRecursive(
    vfs: *VFS,
    dir: fs.Dir,
    allocator: Allocator,
    classfile_name: []u8,
    classFile: *const ClassFile
) VFSParseError!void {
    
    for(classFile.constant_pool) |pool| {
        if(std.meta.activeTag(pool) != .Class) continue;

        const class = classFile.constant_pool[pool.Class.name_index - 1].Utf8.bytes;
        if(vfs.paths.contains(class)) continue;

        const class_slice = classfile_name[505-class.len..];
        std.mem.copyForwards(u8, class_slice, class);
        const dep = parseClass(dir, @ptrCast(class_slice), allocator)
            catch |err| switch(err) { 
                Errors.FileSystemError.OpeningFailed => {
                    std.debug.print("warning: {s} not found in archive!\n", .{class_slice});
                    continue;
                },
                else => |e| return e,
            };
        vfs.paths.put(class, &dep) catch return Errors.MemoryError;
        try addDependencyRecursive(vfs, dir, allocator, classfile_name, &dep);
    }
}
