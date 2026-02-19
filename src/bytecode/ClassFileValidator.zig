const std = @import("std");
const log = std.log.scoped(.ClassFileValidation);

const FormatError = @import("../Errors.zig").FormatError;

const ClassFile = @import("ClassFile.zig");
const cp_info = ClassFile.cp_info;

pub const LoggingOptions = struct {
    verbose: bool = false,
};

// ClassFile Spec 4.8
pub fn validate(classFile: *ClassFile, reader: *std.Io.Reader, options: LoggingOptions) void {
    const class_name = classFile.constant_pool[
        classFile.constant_pool[
            classFile.this_class-1
        ].Class.name_index-1
    ].Utf8.bytes;
    validateMagic(classFile.magic, class_name, options) catch unreachable;
    // I suppose attributes have the right length otherwise it wouldn't parse correctly? TODO
    validateReader(reader, class_name, options) catch unreachable;
    validateConstantPool(classFile, class_name, options) catch unreachable;
    // TODO still need to check field/methodrefs for valid names/classes/descriptors
}

fn validateMagic(magic: u32, class_name: []u8, options: LoggingOptions) FormatError!void {
    if(magic != 0xcafebabe) {
        log.err("{s} failed magic validation", .{class_name});
        return FormatError.InvalidMagic;
    }
    if(options.verbose) log.info("{s} passed magic validation", .{class_name});
}

fn validateReader(reader: *std.Io.Reader, class_name: []u8, options: LoggingOptions) FormatError!void {
    if(reader.discardRemaining() catch unreachable != 0) {
        log.err("{s} failed file length validation", .{class_name});
        return FormatError.InvalidFileLength;
    }
    if(options.verbose) log.info("{s} passed file length validation", .{class_name});
}

fn validateConstantPool(classFile: *ClassFile, class_name: []u8, options: LoggingOptions) FormatError!void {
    const constant_pool = classFile.constant_pool;
    var bootstrap_method_count: u16 = 0;
    for(classFile.attributes) |a| {
        if(std.meta.activeTag(a.info) == .BootstrapMethods) {
            bootstrap_method_count = a.info.BootstrapMethods.num_bootstrap_methods;
            break;
        }
    }
    for(constant_pool) |e| {
        // std.debug.print("{}\n", .{e});
        switch (e) {
            .Class => |v| {
                switch(constant_pool[v.name_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to Class is of type {} (should be Utf8)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Fieldref => |v| {
                // class can be class or interface
                switch(constant_pool[v.class_index - 1]) {
                    .Class => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to Fieldref is of type {} (should be Class)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to Fieldref is of type {} (should be NameAndType)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Methodref => |v| {
                // class can only be class, not interface
                switch(constant_pool[v.class_index - 1]) {
                    // TODO distinguish class and interface types at link time
                    .Class => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to Methodref is of type {} (should be Class)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to Methodref is of type {} (should be NameAndType)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .InterfaceMethodref => |v| {
                // class can only be interface, not class
                switch(constant_pool[v.class_index - 1]) {
                    .Class => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to InterfaceMethodref is of type {} (should be Class)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to InterfaceMethodref is of type {} (should be NameAndType)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .String => |v| {
                switch(constant_pool[v.string_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to String is of type {} (should be Utf8)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Integer => {},
            .Float => {},
            .Long => {},
            .Double => {},
            .NameAndType => |v| {
                // name should be a field or method or <init>
                switch(constant_pool[v.name_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to NameAndType is of type {} (should be Utf8)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
                // descriptor should be a field or method descriptor
                switch(constant_pool[v.descriptor_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to NameAndType is of type {} (should be Utf8)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Utf8 => {},
            .MethodHandle => |v| {
                switch(v.reference_kind) {
                    // TODO 5, 6, 7, 9 must not be <init> or <clinit>       
                    .REF_getField, .REF_getStatic, .REF_putField, .REF_putStatic => {
                        switch(constant_pool[v.reference_index - 1]) {
                            .Fieldref => {},
                            else => |t| {
                                log.err("{s} failed constant pool validation: entry to MethodHandle is of type {} (should be Fieldref)", .{class_name, t});
                                return FormatError.InvalidConstantPool;
                            },
                        }
                    },
                    .REF_invokeVirtual, .REF_newInvokeSpecial => {
                        // TODO REF_newInvokeSpecial name must be <init>
                        switch(constant_pool[v.reference_index - 1]) {
                            .Methodref => {},
                            else => |t| {
                                log.err("{s} failed constant pool validation: entry to MethodHandle is of type {} (should be Methodref)", .{class_name, t});
                                return FormatError.InvalidConstantPool;
                            },
                        }
                    },
                    .REF_invokeStatic, .REF_invokeSpecial => {
                        switch(constant_pool[v.reference_index - 1]) {
                            .Methodref => {},
                            .InterfaceMethodref => {},
                            else => |t| {
                                log.err("{s} failed constant pool validation: entry to MethodHandle is of type {} (should be Methodref or InterfaceMethodref)", .{class_name, t});
                                return FormatError.InvalidConstantPool;
                            },
                        }
                    },
                    .REF_invokeInterface => {
                        switch(constant_pool[v.reference_index - 1]) {
                            .InterfaceMethodref => {},
                            else => |t| {
                                log.err("{s} failed constant pool validation: entry to MethodHandle is of type {} (should be InterfaceMethodref)", .{class_name, t});
                                return FormatError.InvalidConstantPool;
                            },
                        }
                    },
                }
            },
            .MethodType => |v| {
                switch(constant_pool[v.descriptor_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to MethodType is of type {} (should be Utf8)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Dynamic => |v| {
                if(v.bootstrap_method_attr_index >= bootstrap_method_count) {
                    log.err("{s} failed constant pool validation: entry to Dynamic is out of bounds of the bootstrap_methods table", .{class_name});
                    return FormatError.InvalidConstantPool;
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to Dynamic is of type {} (should be NameAndType)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .InvokeDynamic => |v| {
                if(v.bootstrap_method_attr_index >= bootstrap_method_count) {
                    log.err("{s} failed constant pool validation: entry to InvokeDynamic is out of bounds of the bootstrap_methods table", .{class_name});
                    return FormatError.InvalidConstantPool;
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to InvokeDynamic is of type {} (should be NameAndType)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Module => |v| {
                switch(constant_pool[v.name_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to Module is of type {} (should be Utf8)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Package => |v| {
                switch(constant_pool[v.name_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("{s} failed constant pool validation: entry to Package is of type {} (should be Utf8)", .{class_name, t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Empty => {},
        }
    }
    if(options.verbose) log.info("{s} passed constant pool validation", .{class_name});
}
