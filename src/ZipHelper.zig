const std = @import("std");
const miniz = @cImport(@cInclude("miniz.h"));

pub const True = miniz.MZ_TRUE;

// TODO make centralized error
const InternalError = error {
    MemoryError,
};

pub const ZipError = error {
    InitFailed,
    StatFailed,
    ExtractionFailed,
    InvalidClassFilePath,
    InvalidFileName,
} || InternalError;

pub const Archive = struct {
    archive: *miniz.mz_zip_archive,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(path: []const u8, allocator: std.mem.Allocator) ZipError!Self {
        const archive = allocator.create(miniz.mz_zip_archive) catch return InternalError.MemoryError;
        errdefer allocator.destroy(archive);
        miniz.mz_zip_zero_struct(archive);

        if(miniz.mz_zip_reader_init_file(archive, path.ptr, 0) != True) return ZipError.InitFailed;
    
        return .{
            .archive = archive,
            .allocator = allocator
        };
    }
    
    pub fn deinit(self: *Self) void {
        _ = miniz.mz_zip_reader_end(self.archive);
        self.allocator.destroy(self.archive);
    }
    
    pub fn fileCount(self: *Self) u32 {
        return miniz.mz_zip_reader_get_num_files(self.archive);
    }
    
    pub fn getElementByIndex(self: *Self, index: usize) ZipError!Element {
        var stat: miniz.mz_zip_archive_file_stat = undefined;    
        if(miniz.mz_zip_reader_file_stat(self.archive, @intCast(index), &stat) != True) return ZipError.StatFailed;

        var reader = std.Io.Reader.fixed(&stat.m_filename);
        const name_len = reader.discardDelimiterInclusive(0) catch return ZipError.InvalidFileName;

        const buffer = self.allocator.alloc(u8, stat.m_uncomp_size) catch return InternalError.MemoryError;
        if(stat.m_is_directory != True) {
            if(miniz.mz_zip_reader_extract_to_mem(self.archive, @intCast(index), buffer.ptr, buffer.len, 0) != True) 
                return ZipError.ExtractionFailed;
        }

        return .{
            .stat = stat,
            .buffer = buffer,
            .name_len = name_len,
            .allocator = self.allocator,
        };
    }

    pub fn getElementByName(self: *Self, name: []const u8) ZipError!Element {
        const file_index = miniz.mz_zip_reader_locate_file(self.archive, name.ptr, null, 0);
        return if(file_index == -1) 
            ZipError.InvalidFileName
        else 
            try getElementByIndex(self, @intCast(file_index))
        ;
    }
};

pub const Element = struct {
    stat: miniz.mz_zip_archive_file_stat,
    buffer: []const u8,
    name_len: usize,
    allocator: std.mem.Allocator,

    const Self = @This();
    
    pub fn isDir(self: *Self) bool {
        return self.stat.m_is_directory == True;
    }

    pub fn getFilename(self: *Self) []const u8 {
        return self.stat.m_filename[0..self.name_len];
    }

    pub fn getContent(self: *Self) []const u8 {
        return self.buffer;
    }
    
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.buffer);
    }
};
