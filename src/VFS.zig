const std = @import("std");
const zip = @cImport(@cInclude("miniz.h"));

pub fn version() void {
    std.debug.print("{s}\n", .{zip.mz_version()});
}
