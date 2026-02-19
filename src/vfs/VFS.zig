const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

const Errors = @import("../Errors.zig");

const ClassFile = @import("../bytecode/ClassFile.zig");

const zip = @import("ZipHelper.zig");
const Archive = zip.Archive;

const Self = @This();

const Manifest = struct {
    @"Manifest-Version": ?[]const u8 = null,
    @"Created-By": ?[]const u8 = null,
    @"Signature-Version": ?[]const u8 = null,
    @"Class-Path": ?[]const u8 = null,
    @"Automatic-Module-Name": ?[]const u8 = null,
    @"Multi-Release": ?[]const u8 = null,
    @"Main-Class": ?[]const u8 = null,
    @"Launcher-Agent-Class": ?[]const u8 = null,
    @"Implementation-Title": ?[]const u8 = null,
    @"Implementation-Version": ?[]const u8 = null,
    @"Implementation-Vendor": ?[]const u8 = null,
    @"Specification-Title": ?[]const u8 = null,
    @"Specification-Version": ?[]const u8 = null,
    @"Specification-Vendor": ?[]const u8 = null,
    @"Sealed": ?[]const u8 = null,
};


paths: std.StringHashMap(*const ClassFile),


pub fn walkJar(allocator: Allocator, path: []const u8) Errors.VFSParseError!void {
    var archive = try Archive.init(path, allocator);
    defer archive.deinit();

    for(0..archive.fileCount()) |index| {
        var elem = try archive.getElementByIndex(index);
        defer elem.deinit();
    
        if(elem.isDir()) continue;
        if(!std.mem.eql(u8, elem.getFilename()[elem.name_len-7..elem.name_len-1], ".class")) continue;
    
        var reader = std.Io.Reader.fixed(elem.getContent());
        var cf = try ClassFile.parse(&reader, allocator);
        cf.validate(&reader, .{});
    }
}

pub fn readJar(path: []const u8, classpath: ?[]const u8, allocator: Allocator) Errors.VFSParseError!Self {
    var archive = try Archive.init(path, allocator);
    defer archive.deinit();

    const manifest: ?Manifest = try extractManifest(&archive);
    
    const filename: []const u8 = if(classpath) |ext_path| 
        ext_path 
    else if(manifest) |manifest_obj|
        if(manifest_obj.@"Main-Class") |main_class|
            main_class
        else return Errors.JarError.InvalidClassFilePath
    else return Errors.JarError.InvalidClassFilePath;

    const root = try parseClassFromArchive(&archive, filename);

    var vfs: Self = .{ .paths = std.StringHashMap(*const ClassFile).init(allocator) };
    vfs.paths.put(root.constant_pool[root.this_class].Utf8.bytes, &root) catch return Errors.MemoryError;

    // archive needs .class extension that is not present in classfile paths
    var classfile_name = [_]u8{0} ** 512;
    const dot_class = ".class";
    for(dot_class, 505..) |c, it| {
        classfile_name[it] = c;
    }

    try vfs.addDependencyRecursiveFromArchive(&archive, &classfile_name, &root);

    return vfs;
}

pub fn readDir(path: []const u8, classpath: [:0]const u8, allocator: Allocator) Errors.VFSParseError!Self {

    const abs_path = fs.cwd().realpathAlloc(allocator, path) catch return Errors.MemoryError;
    defer allocator.free(abs_path);
    const dir = fs.cwd().makeOpenPath(abs_path, .{}) catch return Errors.FileSystemError.OpeningFailed;

    const root = try parseClassFromDir(dir, classpath, allocator);

    var vfs: Self = .{ .paths = std.StringHashMap(*const ClassFile).init(allocator) };
    vfs.paths.put(root.constant_pool[root.this_class].Utf8.bytes, &root) catch return Errors.MemoryError;

    // archive needs .class extension that is not present in classfile paths
    var classfile_name = [_]u8{0} ** 512;
    const dot_class = ".class";
    for(dot_class, 505..) |c, it| {
        classfile_name[it] = c;
    }

    try vfs.addDependencyRecursiveFromDir(dir, allocator, &classfile_name, &root);

    return vfs;
}

pub fn addDependencyRecursiveFromArchive(self: *Self, archive: *Archive, classfile_name: []u8, classFile: *const ClassFile) Errors.VFSParseError!void {
    for(classFile.constant_pool) |pool| {
        if(std.meta.activeTag(pool) != .Class) continue;
    
        const class = classFile.constant_pool[pool.Class.name_index - 1].Utf8.bytes;
        if(self.paths.contains(class)) continue;

        const class_slice = classfile_name[505-class.len..];
        std.mem.copyForwards(u8, class_slice, class);
        const dep = parseClassFromArchive(archive, class_slice)
            catch |err| switch(err) { 
                Errors.ZipError.InvalidFileName => {
                    std.debug.print("warning: {s} not found in archive!\n", .{class_slice});
                    continue;
                },
                else => |e| return e,
            };
        self.paths.put(class, &dep) catch return Errors.MemoryError;
        try self.addDependencyRecursiveFromArchive(archive, classfile_name, &dep);
    }
}

pub fn addDependencyRecursiveFromDir(self: *Self, dir: fs.Dir, allocator: Allocator, classfile_name: []u8, classFile: *const ClassFile) Errors.VFSParseError!void {
    for(classFile.constant_pool) |pool| {
        if(std.meta.activeTag(pool) != .Class) continue;
    
        const class = classFile.constant_pool[pool.Class.name_index - 1].Utf8.bytes;
        if(self.paths.contains(class)) continue;

        const class_slice = classfile_name[505-class.len..];
        std.mem.copyForwards(u8, class_slice, class);
        const dep = parseClassFromDir(dir, @ptrCast(class_slice), allocator)
            catch |err| switch(err) { 
                Errors.FileSystemError.OpeningFailed => {
                    std.debug.print("warning: {s} not found in archive!\n", .{class_slice});
                    continue;
                },
                else => |e| return e,
            };
        self.paths.put(class, &dep) catch return Errors.MemoryError;
        try self.addDependencyRecursiveFromDir(dir, allocator, classfile_name, &dep);
    }
}

pub fn parseClassFromArchive(archive: *Archive, name: []const u8) Errors.VFSParseError!ClassFile {
    var file = try archive.getElementByName(name);

    var reader = std.Io.Reader.fixed(file.getContent());
    var result = try ClassFile.parse(&reader, archive.allocator);
    result.validate(&reader, .{});
    return result;
}

pub fn parseClassFromDir(dir: fs.Dir, name: [:0]const u8, allocator: Allocator) Errors.VFSParseError!ClassFile {
    const source = dir.openFileZ(name, .{}) catch return Errors.FileSystemError.OpeningFailed;
    defer source.close();
    
    const stat = source.stat() catch return Errors.FileSystemError.StatFailed;
    const buffer: []u8 = source.readToEndAlloc(allocator, stat.size) catch return Errors.MemoryError;

    var reader = std.Io.Reader.fixed(buffer);
    var result = try ClassFile.parse(&reader, allocator);
    result.validate(&reader, .{});
    return result;
}

fn extractManifest(archive: *Archive) Errors.VFSError!?Manifest {
    const name: []const u8 = "META-INF/MANIFEST.MF";
    var manifest_elem = archive.getElementByName(name) catch |err| switch(err) {
        Errors.ZipError.InvalidFileName => return null,
        else => return err,
    };

    const manifest_enum = std.meta.FieldEnum(Manifest);
    var manifest: Manifest = .{};

    var iter = std.mem.splitScalar(u8, manifest_elem.getContent(), '\n');
    while(iter.next()) |line| {
        const split_index = if(std.mem.indexOf(u8, line, ": ")) |index| index else continue;
        if(std.meta.stringToEnum(manifest_enum, line[0..split_index])) |val| {
            switch(val) { inline else => |v| {
                @field(manifest, @tagName(v)) = line[split_index+2..];
            }}
        // we can stop after the main attributes, the Main-Class attribute won't come after
        // https://docs.oracle.com/en/java/javase/25/docs/specs/jar/jar.html#manifest-specification
        } else break;
    }
    return manifest;
}
