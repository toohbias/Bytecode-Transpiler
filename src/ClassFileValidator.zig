const std = @import("std");
const log = std.log.scoped(.ClassFileValidation);
const ClassFile = @import("ClassFile.zig");
const cp_info = ClassFile.cp_info;

const LoggingOptions = struct {
    verbose: bool = false,
};

const FormatError = error {
    InvalidMagic,
    InvalidFileLength,
    InvalidConstantPool,
};

// ClassFile Spec 4.8
pub fn validate(classFile: *ClassFile.ClassFile, reader: *std.Io.Reader, options: LoggingOptions) void {
    validateMagic(classFile.magic, options) catch unreachable;
    // I suppose attributes have the right length otherwise it wouldn't parse correctly? TODO
    validateReader(reader, options) catch unreachable;
    validateConstantPool(classFile, options) catch unreachable;
    // TODO still need to check field/methodrefs for valid names/classes/descriptors
}

fn validateMagic(magic: u32, options: LoggingOptions) FormatError!void {
    if(magic != 0xcafebabe) {
        log.err("failed magic validation", .{});
        return FormatError.InvalidMagic;
    }
    if(options.verbose) log.info("passed magic validation", .{});
}

fn validateReader(reader: *std.Io.Reader, options: LoggingOptions) FormatError!void {
    if(reader.discardRemaining() catch unreachable != 0) {
        log.err("failed file length validation", .{});
        return FormatError.InvalidFileLength;
    }
    if(options.verbose) log.info("passed file length validation", .{});
}

fn validateConstantPool(classFile: *ClassFile.ClassFile, options: LoggingOptions) FormatError!void {
    const constant_pool = classFile.constant_pool;
    const bootstrap_type: type = @FieldType(@FieldType(ClassFile.attribute_info, "info"), "BootstrapMethods");
    var bootstrap_methods: bootstrap_type = undefined;
    for(classFile.attributes) |a| {
        if(@TypeOf(a) == bootstrap_type) {
            bootstrap_methods = a;
            break;
        }
    }
    for(constant_pool) |e| {
        switch (e) {
            .Class => |v| {
                switch(constant_pool[v.name_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to Class is of type {} (should be Utf8)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Fieldref => |v| {
                // class can be class or interface
                switch(constant_pool[v.class_index - 1]) {
                    .Class => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to Fieldref is of type {} (should be Class)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to Fieldref is of type {} (should be NameAndType)", .{t});
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
                        log.err("failed constant pool validation: entry to Methodref is of type {} (should be Class)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to Methodref is of type {} (should be NameAndType)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .InterfaceMethodref => |v| {
                // class can only be interface, not class
                switch(constant_pool[v.class_index - 1]) {
                    .Class => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to InterfaceMethodref is of type {} (should be Class)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to InterfaceMethodref is of type {} (should be NameAndType)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .String => |v| {
                switch(constant_pool[v.string_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to String is of type {} (should be Utf8)", .{t});
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
                        log.err("failed constant pool validation: entry to NameAndType is of type {} (should be Utf8)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
                // descriptor should be a field or method descriptor
                switch(constant_pool[v.descriptor_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to NameAndType is of type {} (should be Utf8)", .{t});
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
                                log.err("failed constant pool validation: entry to MethodHandle is of type {} (should be Fieldref)", .{t});
                                return FormatError.InvalidConstantPool;
                            },
                        }
                    },
                    .REF_invokeVirtual, .REF_newInvokeSpecial => {
                        // TODO REF_newInvokeSpecial name must be <init>
                        switch(constant_pool[v.reference_index - 1]) {
                            .Methodref => {},
                            else => |t| {
                                log.err("failed constant pool validation: entry to MethodHandle is of type {} (should be Methodref)", .{t});
                                return FormatError.InvalidConstantPool;
                            },
                        }
                    },
                    .REF_invokeStatic, .REF_invokeSpecial => {
                        switch(constant_pool[v.reference_index - 1]) {
                            .Methodref => {},
                            .InterfaceMethodref => {},
                            else => |t| {
                                log.err("failed constant pool validation: entry to MethodHandle is of type {} (should be Methodref or InterfaceMethodref)", .{t});
                                return FormatError.InvalidConstantPool;
                            },
                        }
                    },
                    .REF_invokeInterface => {
                        switch(constant_pool[v.reference_index - 1]) {
                            .InterfaceMethodref => {},
                            else => |t| {
                                log.err("failed constant pool validation: entry to MethodHandle is of type {} (should be InterfaceMethodref)", .{t});
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
                        log.err("failed constant pool validation: entry to MethodType is of type {} (should be Utf8)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Dynamic => |v| {
                if(v.bootstrap_method_attr_index >= bootstrap_methods.num_bootstrap_methods) {
                    log.err("failed constant pool validation: entry to Dynamic is out of bounds of the bootstrap_methods table", .{});
                    return FormatError.InvalidConstantPool;
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to Dynamic is of type {} (should be NameAndType)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .InvokeDynamic => |v| {
                if(v.bootstrap_method_attr_index >= bootstrap_methods.num_bootstrap_methods) {
                    log.err("failed constant pool validation: entry to InvokeDynamicis out of bounds of the bootstrap_methods table", .{});
                    return FormatError.InvalidConstantPool;
                }
                switch(constant_pool[v.name_and_type_index - 1]) {
                    .NameAndType => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to InvokeDynamic is of type {} (should be NameAndType)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Module => |v| {
                switch(constant_pool[v.name_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to Module is of type {} (should be Utf8)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Package => |v| {
                switch(constant_pool[v.name_index - 1]) {
                    .Utf8 => {},
                    else => |t| {
                        log.err("failed constant pool validation: entry to Package is of type {} (should be Utf8)", .{t});
                        return FormatError.InvalidConstantPool;
                    },
                }
            },
            .Empty => {},
        }
    }
    if(options.verbose) log.info("passed constant pool validation", .{});
}
