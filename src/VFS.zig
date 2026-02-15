const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const zip = @cImport(@cInclude("miniz.h"));

const ClassFile = @import("ClassFile.zig");
const Validator = @import("ClassFileValidator.zig");

const ZipError = error {
    InitFailed,
    StatFailed,
    ExtractionFailed,
    InvalidClassFilePath,
    IndexingFailed,
};

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

pub fn readZip(allocator: Allocator, path: []const u8) !void {
    var archive: zip.mz_zip_archive = undefined;
    zip.mz_zip_zero_struct(&archive);
    if(zip.mz_zip_reader_init_file(&archive, path.ptr, 0) != zip.MZ_TRUE) { @panic("couldn't init archive!"); }
    defer _ = zip.mz_zip_reader_end(&archive);

    const filename = try allocator.alloc(u8, 512);
    defer allocator.free(filename);

    for(0..zip.mz_zip_reader_get_num_files(&archive)) |index| {
        var stat: zip.mz_zip_archive_file_stat = undefined;
        if(zip.mz_zip_reader_file_stat(&archive, @intCast(index), &stat) != zip.MZ_TRUE) { @panic("stat failed!"); }

        if(stat.m_is_directory == zip.MZ_TRUE) { continue; }

        const filename_length = zip.mz_zip_reader_get_filename(&archive, @intCast(index), filename.ptr, @intCast(filename.len));
        if(!std.mem.eql(u8, filename[filename_length - 7..filename_length-1], ".class")) continue;

        const buffer = try allocator.alloc(u8, stat.m_uncomp_size);
        defer allocator.free(buffer);
        if(zip.mz_zip_reader_extract_to_mem(&archive, @intCast(index), buffer.ptr, buffer.len, 0) != zip.MZ_TRUE) { @panic("couldn't extract archive!"); }

        var byteReader = std.Io.Reader.fixed(buffer);
        var cf: ClassFile.ClassFile = try ClassFile.ClassFile.parse(&byteReader, allocator);

        Validator.validate(&cf, &byteReader, .{ .verbose = true });

        std.debug.print("Extracted {s} ({} bytes)\n", .{@as([*:0]const u8, @ptrCast(&stat.m_filename)), stat.m_uncomp_size});
    }
}

pub fn readJar(path: []const u8, classpath: ?[]const u8, allocator: Allocator) ZipError!void {
    var archive: zip.mz_zip_archive = undefined;
    zip.mz_zip_zero_struct(&archive);
    if(zip.mz_zip_reader_init_file(&archive, path.ptr, 0) != zip.MZ_TRUE) { return ZipError.InitFailed; }
    defer _ = zip.mz_zip_reader_end(&archive);

    const manifest: ?Manifest = try extractManifest(&archive, allocator);
    
    const filename: []const u8 = if(classpath) |ext_path| 
        ext_path 
    else if(manifest) |manifest_obj|
        if(manifest_obj.@"Main-Class") |main_class|
            main_class
        else return ZipError.InvalidClassFilePath
    else return ZipError.InvalidClassFilePath;

    const root: ClassFile.ClassFile = try parseClassFromArchive(&archive, filename, allocator);
    
    for(root.constant_pool) |pool| {
        if(std.meta.activeTag(pool) == .Class) {
            std.debug.print("Class: {s}\n", .{root.constant_pool[pool.Class.name_index - 1].Utf8.bytes});
        }
    }
}

pub fn parseClassFromArchive(archive: *zip.mz_zip_archive, name: []const u8, allocator: Allocator) ZipError!ClassFile.ClassFile {
    const file_index = zip.mz_zip_reader_locate_file(archive, name.ptr, null, 0);
    if(file_index == -1) return ZipError.IndexingFailed;

    var stat: zip.mz_zip_archive_file_stat = undefined;
    if(zip.mz_zip_reader_file_stat(archive, @intCast(file_index), &stat) != zip.MZ_TRUE) return ZipError.StatFailed;

    const buffer = allocator.alloc(u8, stat.m_uncomp_size) catch unreachable;
    if(zip.mz_zip_reader_extract_to_mem(
        archive, 
        @intCast(file_index), 
        buffer.ptr, 
        buffer.len, 
        0
    ) != zip.MZ_TRUE) return ZipError.ExtractionFailed;

    var reader = std.Io.Reader.fixed(buffer);
    var result = ClassFile.ClassFile.parse(&reader, allocator) catch unreachable;
    Validator.validate(&result, &reader, .{});
    return result;
}

fn extractManifest(archive: *zip.mz_zip_archive, allocator: Allocator) ZipError!?Manifest {
    const manifest_index = zip.mz_zip_reader_locate_file(archive, "META-INF/MANIFEST.MF", null, 0);
    if(manifest_index == -1) { return null; }
    
    var manifest_stat: zip.mz_zip_archive_file_stat = undefined;
    if(zip.mz_zip_reader_file_stat(
        archive, 
        @intCast(manifest_index), 
        &manifest_stat
    ) != zip.MZ_TRUE) return ZipError.StatFailed; 

    const manifest_buffer = allocator.alloc(u8, manifest_stat.m_uncomp_size) catch unreachable;
    if(zip.mz_zip_reader_extract_to_mem(
        archive, 
        @intCast(manifest_index), 
        manifest_buffer.ptr, 
        manifest_buffer.len, 
        0
    ) != zip.MZ_TRUE) return ZipError.ExtractionFailed; 

    const manifest_enum = std.meta.FieldEnum(Manifest);
    var manifest: Manifest = .{};
    
    var iter = std.mem.splitScalar(u8, manifest_buffer, '\n');
    brk: while(iter.next()) |line| {
        const split_index = if(std.mem.indexOf(u8, line, ": ")) |index| index else continue;
        if(std.meta.stringToEnum(manifest_enum, line[0..split_index])) |val| {
            switch(val) { inline else => |v| {
                @field(manifest, @tagName(v)) = line[split_index+2..];
            }}
        // we can stop after the main attributes, the Main-Class attribute won't come after
        // https://docs.oracle.com/en/java/javase/25/docs/specs/jar/jar.html#manifest-specification
        } else break :brk; 
    }
    return manifest;
}

pub fn getSourceReader(filePath: []const u8, allocator: Allocator) !Reader {
    const source = try std.fs.cwd().openFile(filePath, .{});
    defer source.close();

    const stat = try source.stat();
    const buffer: []u8 = source.readToEndAlloc(allocator, stat.size) catch @panic("ALLOC FAILED!\n");
    
    return std.Io.Reader.fixed(buffer);
}
