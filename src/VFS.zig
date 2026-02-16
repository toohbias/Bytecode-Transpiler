const std = @import("std");
const fs = std.fs;
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

const ClassFile = @import("ClassFile.zig").ClassFile;
const Parser = @import("ClassFileParser.zig");
const Validator = @import("ClassFileValidator.zig");

const zip = @import("ZipHelper.zig");
const Archive = zip.Archive;

const InternalError = error {
    StatFailed,
    MemoryError,
} || Parser.ParseError;

const ZipError = zip.ZipError;

const DirError = error {
    OpeningFailed,
} || InternalError;

const VfsError = ZipError || DirError;

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


pub fn readZip(allocator: Allocator, path: []const u8) !void {
    var archive = try Archive.init(path, allocator);
    defer archive.deinit();

    for(0..archive.fileCount()) |index| {
        var elem = try archive.getElementByIndex(index);
        defer elem.deinit();
    
        if(elem.isDir()) continue;
        if(!std.mem.eql(u8, elem.getFilename()[elem.name_len-7..elem.name_len-1], ".class")) continue;
    
        var reader = std.Io.Reader.fixed(elem.getContent());
        var cf = try ClassFile.parse(&reader, allocator);
        Validator.validate(&cf, &reader, .{});
    }
}

pub fn readJar(path: []const u8, classpath: ?[]const u8, allocator: Allocator) !@This() {
    var archive = try Archive.init(path, allocator);
    defer archive.deinit();

    const manifest: ?Manifest = try extractManifest(&archive);
    
    const filename: []const u8 = if(classpath) |ext_path| 
        ext_path 
    else if(manifest) |manifest_obj|
        if(manifest_obj.@"Main-Class") |main_class|
            main_class
        else return ZipError.InvalidClassFilePath
    else return ZipError.InvalidClassFilePath;

    const root = try parseClassFromArchive(&archive, filename);

    var vfs: @This() = .{ .paths = std.StringHashMap(*const ClassFile).init(allocator) };
    vfs.paths.put(root.constant_pool[root.this_class].Utf8.bytes, &root) catch return InternalError.MemoryError;

    // archive needs .class extension that is not present in classfile paths
    var classfile_name = [_]u8{0} ** 128;
    const dot_class = ".class";
    for(dot_class, 121..) |c, it| {
        classfile_name[it] = c;
    }

    for(root.constant_pool) |pool| {
        if(std.meta.activeTag(pool) != .Class) continue; 

        const class = root.constant_pool[pool.Class.name_index - 1].Utf8.bytes;
        if(!vfs.paths.contains(class)) {
            const class_slice = classfile_name[121-class.len..];
            std.mem.copyForwards(u8, class_slice, class);
            const dep = parseClassFromArchive(&archive, class_slice)
                catch |err| switch(err) { 
                    ZipError.InvalidFileName => {
                        std.debug.print("warning: {s} not found in archive!\n", .{class_slice});
                        continue;
                    },
                    else => |e| return e,
                };
            std.debug.print("added {s}\n", .{class});
            vfs.paths.put(class, &dep) catch return InternalError.MemoryError;
        }
    }

    return vfs;
}

pub fn parseClassFromArchive(archive: *Archive, name: []const u8) !ClassFile {
    var file = try archive.getElementByName(name);

    var reader = std.Io.Reader.fixed(file.getContent());
    var result = try ClassFile.parse(&reader, archive.allocator);
    Validator.validate(&result, &reader, .{});
    return result;
}

pub fn parseClassFromDir(dir: fs.Dir, name: []const u8, allocator: Allocator) DirError!ClassFile {
    const source = dir.openFile(name, .{}) catch return DirError.OpeningFailed;
    defer source.close();
    
    const stat = source.stat() catch return DirError.StatFailed;
    const buffer: []u8 = source.readToEndAlloc(allocator, stat.size) catch return InternalError.MemoryError;

    var reader = std.Io.Reader.fixed(buffer);
    var result = try ClassFile.parse(&reader, allocator);
    Validator.validate(&result, &reader, .{});
    return result;
}

fn extractManifest(archive: *Archive) !?Manifest {
    const name: []const u8 = "META-INF/MANIFEST.MF";
    var manifest_elem = archive.getElementByName(name) catch |err| switch(err) {
        ZipError.InvalidFileName => return null,
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
