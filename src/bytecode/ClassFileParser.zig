const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;

const Errors = @import("../Errors.zig");

const ClassFile = @import("ClassFile.zig");

pub fn parseGenericStruct(T: type, instance: *ClassFile, reader: *Reader, allocator: Allocator) Errors.ParseError!T {
    var result: T = undefined;

    switch(@typeInfo(T)) {
        .@"struct" => |s| {
            inline for(s.fields, 0..) |field, it| {
                const fieldtype = field.type;
                @field(result, field.name) = switch(@typeInfo(fieldtype)) {
                    .int => reader.takeInt(field.type, .big) catch return Errors.ReadFailed,
                    .float => |f| @as(fieldtype, @bitCast(reader.takeInt(@Type(
                        .{ .int = .{ .bits = f.bits, .signedness = .unsigned } }
                    ), .big) catch return Errors.ReadFailed)),
                    .pointer => |p| ret: switch(@typeInfo(p.child)) {
                        .int, .float => break :ret try defaultArrCallback(fieldtype, result, it, instance, reader, allocator),
                        else => if(@hasDecl(p.child, "callback")) {
                            break :ret try p.child.callback(fieldtype, result, it, instance, reader, allocator);
                        } else break :ret try defaultArrCallback(fieldtype, result, it, instance, reader, allocator)
                    },
                    else => |e| ret: { 
                        if(@hasDecl(fieldtype, "callback")) {
                            break :ret try fieldtype.callback(fieldtype, result, it, instance, reader, allocator);
                        } else switch(e) {
                            .@"enum" => break :ret try defaultEnumCallback(fieldtype, result, it, instance, reader, allocator),
                            else => return Errors.ParserImplError.InvalidCallbackImpl,
                        }
                    },
                };
                if(T == ClassFile) {
                    @field(instance.*, field.name) = @field(result, field.name);
                }
            }
        },
        .int => |i| result = reader.takeInt(@Type(.{ .int = i }), .big) catch return Errors.ReadFailed,
        .float => |f| result = @as(@Type(.{ .float = f }), @bitCast(reader.takeInt(@Type(
            .{ .int = .{ .bits = f.bits, .signedness = .unsigned } }
        ), .big) catch return Errors.ReadFailed)),
        else => return Errors.ParserImplError.NotYetImplemented,
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
) Errors.ParseError!T {

    if(field_index == 0) unreachable; // bounds checking to prevent compiler error
    const nonArrType = @typeInfo(T).pointer.child;
    const result = allocator.alloc(
        nonArrType, 
        @field(parent, @typeInfo(@TypeOf(parent)).@"struct".fields[field_index-1].name)
    ) catch return Errors.MemoryError;
    for(result, 0..) |_, it| {
        result[it] = try parseGenericStruct(nonArrType, instance, reader, allocator);
    }
    return result;
}

pub fn defaultEnumCallback(T: type, _: anytype, comptime _: usize, _: *ClassFile, reader: *Reader, _: Allocator) Errors.ParseError!T {
    return std.meta.intToEnum(T, reader.takeByte() catch return Errors.ReadFailed) catch return Errors.MalformedError.InvalidEnumType;
}
