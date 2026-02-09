const std = @import("std");
const Allocator = std.mem.Allocator;
const Reader = std.Io.Reader;
const ClassFile = @import("ClassFile.zig");
const OpCode = @import("OpCode.zig").OpCode;

// most cursed function I've ever made in my life
pub fn parseStruct(T: type, instance: *ClassFile.ClassFile, reader: *Reader, allocator: Allocator) anyerror!T {
    var result: T = undefined;

    switch(@typeInfo(T)) {
        .@"struct" => |s| {
        inline for(s.fields, 0..) |f, it| {

                // can't forward this stuff to a new function call because other field values from the struct are necessary
                @field(result, f.name) = switch (@typeInfo(f.type)) {
                    .int => |i| ret: {
                        if(@hasField(T, "code") and std.mem.eql(u8, f.name, "opcode_count")) {
                            if(it == 0) { std.debug.print("{s}\n", .{s.fields[it].name}); @panic("where?"); } // bounds checking to prevent compiler error

                            const size = @field(result, f.name);
                            const old_arr: []OpCode = @field(result, "code");
                            const new_arr: []OpCode = allocator.remap(old_arr, size).?;
                            @field(result, "code") = new_arr;
                            break :ret size;
                        }
                        break :ret try reader.takeInt(@Type(.{.int = i}), .big);
                    },
                    .pointer => |p| ret: {
                        if(it == 0) { std.debug.print("{s}\n", .{s.fields[it].name}); @panic("where?"); } // bounds checking to prevent compiler error
                        var arr = if(std.mem.eql(u8, f.name, "constant_pool"))                                                                      // cp_info
                            try allocator.alloc(p.child, @field(result, s.fields[it-1].name) - 1)
                        else if(std.mem.eql(u8, f.name, "locals") and s.fields.len == 3 and @field(result, s.fields[it-2].name) >= 252)             // append_frame
                            try allocator.alloc(p.child, @field(result, s.fields[it-2].name) - 251)
                        else if(f.type == []ClassFile.verification_type_info and s.fields[it-1].name[0] != 'n')                                     // most other stack_map_frame s
                            try allocator.alloc(p.child, 1)
                        else                                                                                                                        // default
                            try allocator.alloc(p.child, @field(result, s.fields[it-1].name))
                        ;

                        // we don't know how many OpCode elements there are
                        if(f.type == []OpCode) {
                            var offset: u32 = 0;
                            const size: u32 = @field(result, "code_length");
                            var i: u32 = 0;
                            while(offset < size) {
                                arr[i], offset = try OpCode.parse(offset, reader, allocator);
                                i += 1;
                            }
                            if(offset != size) @panic("Invalid Code Length!\n");
                            @field(result, "opcode_count") = i;
                        } else {
                            for(arr, 0..) |item, i| {
                                if(i != 0 
                                and @TypeOf(item) == ClassFile.cp_info 
                                and (std.meta.activeTag(arr[i-1]) == ClassFile.cp_info.Long or std.meta.activeTag(arr[i-1]) == ClassFile.cp_info.Double)) {
                                    arr[i] = @unionInit(ClassFile.cp_info, "Empty", undefined);
                                    continue;
                                } // "In retrospect, making 8-byte constants take two constant pool entries was a poor choice" -Java ClassFile Spec
                                arr[i] = try parseStruct(@TypeOf(item), instance, reader, allocator);
                            }
                        }
                        break :ret arr;
                    },
                    .@"union" => |u| ret: {
                        var resultIn: f.type = undefined;
                        // in attribute_info, switch depending on attribute_name_index
                        if(std.mem.eql(u8, f.name, "info")) {
                            if(it <= 1) { std.debug.print("{s}\n", .{s.fields[it].name}); @panic("where?"); } // bounds checking to prevent compiler error
                            const index = @field(result, s.fields[it-2].name) - 1;
                            const fieldName = instance.*.constant_pool[index].Utf8.bytes;
                            const enumVariant = std.meta.stringToEnum(u.tag_type.?, fieldName).?;
                            resultIn = switch (enumVariant) { inline else => |t| retIn: {
                                const fieldType = @FieldType(f.type, @tagName(t));
                                break :retIn @unionInit(f.type, @tagName(t), try parseStruct(fieldType, instance, reader, allocator));
                            }};
                        }
                        break :ret resultIn;
                    },
                    .@"enum" => try std.meta.intToEnum(f.type, try reader.takeByte()),
                    else => |t| ret: {
                        std.debug.print("{} not yet implemented!\n", .{@Type(t)});
                        break :ret undefined;
                    },
                };
                if(T == ClassFile.ClassFile) {
                    @field(instance.*, f.name) = @field(result, f.name);
                }
            }
        },
        .@"union" => |u| {
            const enumTag = @typeInfo(u.tag_type.?);
            if(enumTag.@"enum".tag_type == u8) {
                const enumVariant = std.enums.fromInt(@Type(enumTag), try reader.takeByte()).?;
                switch(enumVariant) { inline else => |t| {
                    const fieldType = @FieldType(T, @tagName(t));
                    result = @unionInit(T, @tagName(t), try parseStruct(fieldType, instance, reader, allocator));
                }}
            } else {
                switch(T) {
                    ClassFile.stack_map_frame => {
                        const enumVariant: ClassFile.stack_map_frame_enum = switch(try reader.peekByte()) { //frame_type
                            0...63    => .same_frame,
                            64...127  => .same_locals_1_stack_item_frame,
                            247       => .same_locals_1_stack_item_frame_extended,
                            248...250 => .chop_frame,
                            251       => .same_frame_extended,
                            252...254 => .append_frame,
                            255       => .full_frame,
                            else      => |n| std.debug.panic("frame type not supported! ({})\n", .{n}),
                        };
                        switch(enumVariant) { inline else => |t| {
                            const fieldType = @FieldType(T, @tagName(t));
                            result = @unionInit(T, @tagName(t), try parseStruct(fieldType, instance, reader, allocator));
                        }}
                    },
                    else => std.debug.print("{} size?\n", .{T}),
                }
            }
        },
        .int => |i| result = try reader.takeInt(@Type(.{.int = i}), .big),
        else => |t| std.debug.print("{} not implemented yet!\n", .{@Type(t)}),
    }
    return result;
}

pub fn getSourceReader(filePath: []const u8, allocator: Allocator) !Reader {
    const source = try std.fs.cwd().openFile(filePath, .{});
    defer source.close();

    const stat = try source.stat();
    const buffer: []u8 = source.readToEndAlloc(allocator, stat.size) catch @panic("ALLOC FAILED!\n");
    
    return std.Io.Reader.fixed(buffer);
}
