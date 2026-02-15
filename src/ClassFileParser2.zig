const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

const ClassFile = @import("ClassFile.zig").ClassFile;

pub const MalformedError = error {
    InvalidEnumType,
    InvalidCodeLength,
};

pub const InternalError = error {
    InvalidCallbackImpl,
    ReadFailed,
    MemoryError,
    NotYetImplemented,
};

pub const ParseError = MalformedError || InternalError;

pub fn parseGenericStruct(T: type, instance: *ClassFile, reader: *Reader, allocator: Allocator) ParseError!T {
    var result: T = undefined;

    switch(@typeInfo(T)) {
        .@"struct" => |s| {
            inline for(s.fields, 0..) |field, it| {
                // std.debug.print("{s}\n", .{field.name});
                const fieldtype = field.type;
                @field(result, field.name) = switch(@typeInfo(fieldtype)) {
                    .int => reader.takeInt(field.type, .big) catch return InternalError.ReadFailed,
                    .float => |f| @as(fieldtype, @bitCast(reader.takeInt(@Type(
                        .{ .int = .{ .bits = f.bits, .signedness = .unsigned } }
                    ), .big) catch return InternalError.ReadFailed)),
                    else => |t| ret: {
                        switch(t) {
                            .pointer => |p| switch(@typeInfo(p.child)) {
                                .int, .float => break :ret try defaultArrCallback(fieldtype, result, it, instance, reader, allocator),
                                else => if(@hasDecl(p.child, "callback")) {
                                    break :ret try p.child.callback(fieldtype, result, it, instance, reader, allocator);
                                } else break :ret try defaultArrCallback(fieldtype, result, it, instance, reader, allocator)
                            },
                            else => |e| if(@hasDecl(fieldtype, "callback")) {
                                break :ret try fieldtype.callback(fieldtype, result, it, instance, reader, allocator);
                            } else switch(e) {
                                .@"enum" => break :ret try defaultEnumCallback(fieldtype, result, it, instance, reader, allocator),
                                else => return InternalError.InvalidCallbackImpl,
                            }
                        }
                    },
                };
                if(T == ClassFile) {
                    @field(instance.*, field.name) = @field(result, field.name);
                }
            }
        },
        .int => |i| result = reader.takeInt(@Type(.{ .int = i }), .big) catch return InternalError.ReadFailed,
        .float => |f| result = @as(@Type(.{ .float = f }), @bitCast(reader.takeInt(@Type(
            .{ .int = .{ .bits = f.bits, .signedness = .unsigned } }
        ), .big) catch return InternalError.ReadFailed)),
        else => return InternalError.NotYetImplemented,
    }

    return result;
}

pub fn defaultArrCallback(
    T: type, 
    parent: anytype, 
    comptime field_index: usize, 
    instance: *ClassFile,
    reader: *Reader, 
    allocator: Allocator
) ParseError!T {

    if(field_index == 0) unreachable; // bounds checking to prevent compiler error
    const nonArrType = @typeInfo(T).pointer.child;
    const result = allocator.alloc(
        nonArrType, 
        @field(parent, @typeInfo(@TypeOf(parent)).@"struct".fields[field_index-1].name)
    ) catch return InternalError.MemoryError;
    for(result, 0..) |_, it| {
        result[it] = try parseGenericStruct(nonArrType, instance, reader, allocator);
    }
    return result;
}

pub fn defaultEnumCallback(T: type, _: anytype, comptime _: usize, _: *ClassFile, reader: *Reader, _: Allocator) ParseError!T {

    return std.meta.intToEnum(
        T, 
        reader.takeByte() catch return InternalError.ReadFailed
    ) catch return MalformedError.InvalidEnumType;
}
