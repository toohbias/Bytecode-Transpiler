const std = @import("std");
const Allocator = std.mem.Allocator;
const zip = @cImport(@cInclude("miniz.h"));

const Parser = @import("ClassFileParser.zig");
const ClassFile = @import("ClassFile.zig");
const Validator = @import("ClassFileValidator.zig");

const ZipError = error {
    InitFailed,
    StatFailed,
    ExtractionFailed,
    InvalidClassFilePath,
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

// TODO take path to main class
pub fn readZip(allocator: Allocator, path: []const u8) !void {
    var archive: zip.mz_zip_archive = undefined;
    zip.mz_zip_zero_struct(&archive);
    if(zip.mz_zip_reader_init_file(&archive, path.ptr, 0) != zip.MZ_TRUE) { @panic("couldn't init archive!"); }
    defer _ = zip.mz_zip_reader_end(&archive);

    const filename = try allocator.alloc(u8, 512);
    defer allocator.free(filename);

    _ = try extractManifest(&archive, allocator);
    
    for(0..zip.mz_zip_reader_get_num_files(&archive)) |index| {
        var stat: zip.mz_zip_archive_file_stat = undefined;
        if(zip.mz_zip_reader_file_stat(&archive, @intCast(index), &stat) != zip.MZ_TRUE) { @panic("stat failed!"); }

        if(stat.m_is_directory == zip.MZ_TRUE) { continue; }

        const filename_length = zip.mz_zip_reader_get_filename(&archive, @intCast(index), filename.ptr, @intCast(filename.len));
        _ = zip.memset(filename.ptr, 0, filename.len);
        if(std.mem.lastIndexOf(u8, filename, ".class")) |file_extension_index| {
            if(filename_length - file_extension_index != 7) { continue; }
        } else { continue; }

        const buffer = try allocator.alloc(u8, stat.m_uncomp_size);
        defer allocator.free(buffer);
        if(zip.mz_zip_reader_extract_to_mem(&archive, @intCast(index), buffer.ptr, buffer.len, 0) != zip.MZ_TRUE) { @panic("couldn't extract archive!"); }

        var byteReader = std.Io.Reader.fixed(buffer);
        var cf: ClassFile.ClassFile = undefined;
        _ = try Parser.parseStruct(ClassFile.ClassFile, &cf, &byteReader, allocator);

        Validator.validate(&cf, &byteReader, .{});

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

    std.debug.print("{s}\n", .{filename});
}

pub fn extractManifest(archive: *zip.mz_zip_archive, allocator: Allocator) ZipError!?Manifest {
    const manifest_index = zip.mz_zip_reader_locate_file(archive, "META-INF/MANIFEST.MF", null, 0);
    if(manifest_index == -1) { return null; }
    
    var manifest_stat: zip.mz_zip_archive_file_stat = undefined;
    if(zip.mz_zip_reader_file_stat(
        archive, 
        @intCast(manifest_index), 
        &manifest_stat
    ) != zip.MZ_TRUE) { return ZipError.StatFailed; }

    const manifest_buffer = allocator.alloc(u8, manifest_stat.m_uncomp_size) catch unreachable;
    if(zip.mz_zip_reader_extract_to_mem(
        archive, 
        @intCast(manifest_index), 
        manifest_buffer.ptr, 
        manifest_buffer.len, 
        0
    ) != zip.MZ_TRUE) { return ZipError.ExtractionFailed; }

    const manifest_enum = std.meta.FieldEnum(Manifest);
    var manifest: Manifest = .{};
    
    var iter = std.mem.splitScalar(u8, manifest_buffer, '\n');
    brk: while(iter.next()) |line| {
        const split_index = if(std.mem.indexOf(u8, line, ": ")) |index| index else continue;
        if(std.meta.stringToEnum(manifest_enum, line[0..split_index])) |val| {
            switch(val) { inline else => |v| {
                @field(manifest, @tagName(v)) = line[split_index+2..];
            }}
        } else break :brk; 
    }
    return manifest;
}
