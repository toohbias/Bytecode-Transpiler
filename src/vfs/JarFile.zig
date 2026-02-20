const std = @import("std");
const Allocator = std.mem.Allocator;

const ClassFile = @import("../bytecode/ClassFile.zig");

const Errors = @import("../Errors.zig");
const VFSParseError = Errors.VFSParseError;

const zip = @import("ZipHelper.zig");
const Archive = zip.Archive;

const VFS = @import("VFS.zig");

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

    fn extract(archive: *Archive) Errors.VFSError!?Manifest {
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
};

// this is mostly for testing purposes
pub fn walk(allocator: Allocator, path: []const u8, subdir: []const u8) VFSParseError!void {
    var archive = try Archive.init(path, allocator);
    defer archive.deinit();

    for(0..archive.fileCount()) |index| {
        var elem = try archive.getElementByIndex(index);
        defer elem.deinit();

        if(elem.isDir()) continue;

        const filename = elem.getFilename();
        if(!std.mem.eql(u8, filename[elem.name_len-7..elem.name_len-1], ".class")) continue;
        if(!std.mem.eql(u8, filename[0..subdir.len], subdir)) continue;

        var reader = std.Io.Reader.fixed(elem.getContent());
        _ = try ClassFile.parseAndValidate(&reader, allocator, .{});
    }
}

pub fn read(allocator: Allocator, path: []const u8, classpath: ?[]const u8) VFSParseError!VFS {
    var archive = try Archive.init(path, allocator);
    defer archive.deinit();

    const manifest: ?Manifest = try Manifest.extract(&archive);

    const filename: []const u8 = if(classpath) |ext_path|
        ext_path
    else if(manifest) |manifest_obj|
        if(manifest_obj.@"Main-Class") |main_class|
            main_class
        else return Errors.JarError.InvalidClassFilePath
    else return Errors.JarError.InvalidClassFilePath;

    const root: ClassFile = try parseClass(&archive, filename);

    var vfs: VFS = .{ .paths = std.StringHashMap(*const ClassFile).init(allocator) };
    vfs.paths.put(root.getName(), &root) 
        catch return Errors.MemoryError;

    // archive needs .class extension that is not present in classfile paths
    var classfile_name = [_]u8{0} ** 512;
    for(".class", 505..) |c, it| {
        classfile_name[it] = c;
    }

    try addDependencyRecursive(&vfs, &archive, &classfile_name, &root);
    
    return vfs;
}

pub fn parseClass(archive: *Archive, name: []const u8) VFSParseError!ClassFile {
    var file = try archive.getElementByName(name);

    var reader = std.Io.Reader.fixed(file.getContent());
    return try ClassFile.parseAndValidate(&reader, archive.allocator, .{});
}

fn addDependencyRecursive(
    vfs: *VFS, 
    archive: *Archive, 
    classfile_name: []u8, 
    classFile: *const ClassFile
) VFSParseError!void {

    for(classFile.constant_pool) |pool| {
        if(std.meta.activeTag(pool) != .Class) continue;

        const class = classFile.constant_pool[pool.Class.name_index - 1].Utf8.bytes;
        if(vfs.paths.contains(class)) continue;

        const class_slice = classfile_name[505-class.len..];
        std.mem.copyForwards(u8, class_slice, class);
        const dep = parseClass(archive, class_slice)
            catch |err| switch(err) {
                Errors.ZipError.InvalidFileName => {
                    std.debug.print("warning: {s} not found in archive!\n", .{class_slice});
                    continue;
                },
                else => |e| return e,
            };
        vfs.paths.put(class, &dep) catch return Errors.MemoryError;
        try addDependencyRecursive(vfs, archive, classfile_name, &dep);
    }
}
