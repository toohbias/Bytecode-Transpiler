const std = @import("std");
const Allocator = std.mem.Allocator;
const zip = @cImport(@cInclude("miniz.h"));

const Parser = @import("ClassFileParser.zig");
const ClassFile = @import("ClassFile.zig");
const Validator = @import("ClassFileValidator.zig");

pub fn version() void {
    std.debug.print("{s}\n", .{zip.mz_version()});
}

pub fn readZip(allocator: Allocator, path: []const u8) !void {
    var archive: zip.mz_zip_archive = undefined;
    zip.mz_zip_zero_struct(&archive);
    if(zip.mz_zip_reader_init_file(&archive, path.ptr, 0) != zip.MZ_TRUE) { @panic("couldn't init archive!"); }
    defer _ = zip.mz_zip_reader_end(&archive);
    
    for(3..zip.mz_zip_reader_get_num_files(&archive)) |index| {
        var stat: zip.mz_zip_archive_file_stat = undefined;
        if(zip.mz_zip_reader_file_stat(&archive, @intCast(index), &stat) != zip.MZ_TRUE) { @panic("stat failed!"); }

        if(stat.m_is_directory == zip.MZ_TRUE) { continue; }

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
