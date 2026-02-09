const std = @import("std");
const Reader = std.Io.Reader;
const Allocator = std.mem.Allocator;

pub const OpCode = union(enum(u8)) {
    // Constants
    nop: struct {} = 0x00,
    aconst_null: struct {} = 0x01,
    iconst_m1: struct {} = 0x02,
    iconst_0: struct {} = 0x03,
    iconst_1: struct {} = 0x04,
    iconst_2: struct {} = 0x05,
    iconst_3: struct {} = 0x06,
    iconst_4: struct {} = 0x07,
    iconst_5: struct {} = 0x08,
    lconst_0: struct {} = 0x09,
    lconst_1: struct {} = 0x0a,
    fconst_0: struct {} = 0x0b,
    fconst_1: struct {} = 0x0c,
    fconst_2: struct {} = 0x0d,
    dconst_0: struct {} = 0x0e,
    dconst_1: struct {} = 0x0f,
    bipush: struct { u8 } = 0x10,
    sipush: struct { u16 } = 0x11,
    ldc: struct { u8 } = 0x12,
    ldc_w: struct { u16 } = 0x13,
    ldc2_w: struct { u16 } = 0x14,

    // Loads
    iload: struct { u8 } = 0x15,
    lload: struct { u8 } = 0x16,
    fload: struct { u8 } = 0x17,
    dload: struct { u8 } = 0x18,
    aload: struct { u8 } = 0x19,
    iload_0: struct {} = 0x1a,
    iload_1: struct {} = 0x1b,
    iload_2: struct {} = 0x1c,
    iload_3: struct {} = 0x1d,
    lload_0: struct {} = 0x1e,
    lload_1: struct {} = 0x1f,
    lload_2: struct {} = 0x20,
    lload_3: struct {} = 0x21,
    fload_0: struct {} = 0x22,
    fload_1: struct {} = 0x23,
    fload_2: struct {} = 0x24,
    fload_3: struct {} = 0x25,
    dload_0: struct {} = 0x26,
    dload_1: struct {} = 0x27,
    dload_2: struct {} = 0x28,
    dload_3: struct {} = 0x29,
    aload_0: struct {} = 0x2a,
    aload_1: struct {} = 0x2b,
    aload_2: struct {} = 0x2c,
    aload_3: struct {} = 0x2d,
    iaload: struct {} = 0x2e,
    laload: struct {} = 0x2f,
    faload: struct {} = 0x30,
    daload: struct {} = 0x31,
    aaload: struct {} = 0x32,
    baload: struct {} = 0x33,
    caload: struct {} = 0x34,
    saload: struct {} = 0x35,

    // Stores
    istore: struct { u8 } = 0x36,
    lstore: struct { u8 } = 0x37,
    fstore: struct { u8 } = 0x38,
    dstore: struct { u8 } = 0x39,
    astore: struct { u8 } = 0x3a,
    istore_0: struct {} = 0x3b,
    istore_1: struct {} = 0x3c,
    istore_2: struct {} = 0x3d,
    istore_3: struct {} = 0x3e,
    lstore_0: struct {} = 0x3f,
    lstore_1: struct {} = 0x40,
    lstore_2: struct {} = 0x41,
    lstore_3: struct {} = 0x42,
    fstore_0: struct {} = 0x43,
    fstore_1: struct {} = 0x44,
    fstore_2: struct {} = 0x45,
    fstore_3: struct {} = 0x46,
    dstore_0: struct {} = 0x47,
    dstore_1: struct {} = 0x48,
    dstore_2: struct {} = 0x49,
    dstore_3: struct {} = 0x4a,
    astore_0: struct {} = 0x4b,
    astore_1: struct {} = 0x4c,
    astore_2: struct {} = 0x4d,
    astore_3: struct {} = 0x4e,
    iastore: struct {} = 0x4f,
    lastore: struct {} = 0x50,
    fastore: struct {} = 0x51,
    dastore: struct {} = 0x52,
    aastore: struct {} = 0x53,
    bastore: struct {} = 0x54,
    castore: struct {} = 0x55,
    sastore: struct {} = 0x56,

    // Stack
    pop: struct {} = 0x57,
    pop2: struct {} = 0x58,
    dup: struct {} = 0x59,
    dup_x1: struct {} = 0x5a,
    dup_x2: struct {} = 0x5b,
    dup2: struct {} = 0x5c,
    dup2_x1: struct {} = 0x5d,
    dup2_x2: struct {} = 0x5e,
    swap: struct {} = 0x5f,

    // Math
    iadd: struct {} = 0x60,
    ladd: struct {} = 0x61,
    fadd: struct {} = 0x62,
    dadd: struct {} = 0x63,
    isub: struct {} = 0x64,
    lsub: struct {} = 0x65,
    fsub: struct {} = 0x66,
    dsub: struct {} = 0x67,
    imul: struct {} = 0x68,
    lmul: struct {} = 0x69,
    fmul: struct {} = 0x6a,
    dmul: struct {} = 0x6b,
    idiv: struct {} = 0x6c,
    ldiv: struct {} = 0x6d,
    fdiv: struct {} = 0x6e,
    ddiv: struct {} = 0x6f,
    irem: struct {} = 0x70,
    lrem: struct {} = 0x71,
    frem: struct {} = 0x72,
    drem: struct {} = 0x73,
    ineg: struct {} = 0x74,
    lneg: struct {} = 0x75,
    fneg: struct {} = 0x76,
    dneg: struct {} = 0x77,
    ishl: struct {} = 0x78,
    lshl: struct {} = 0x79,
    ishr: struct {} = 0x7a,
    lshr: struct {} = 0x7b,
    iushr: struct {} = 0x7c,
    lushr: struct {} = 0x7d,
    iand: struct {} = 0x7e,
    land: struct {} = 0x7f,
    ior: struct {} = 0x80,
    lor: struct {} = 0x81,
    ixor: struct {} = 0x82,
    lxor: struct {} = 0x83,
    iinc: struct { u8, i8 } = 0x84,

    // Conversions
    i2l: struct {} = 0x85,
    i2f: struct {} = 0x86,
    i2d: struct {} = 0x87,
    l2i: struct {} = 0x88,
    l2f: struct {} = 0x89,
    l2d: struct {} = 0x8a,
    f2i: struct {} = 0x8b,
    f2l: struct {} = 0x8c,
    f2d: struct {} = 0x8d,
    d2i: struct {} = 0x8e,
    d2l: struct {} = 0x8f,
    d2f: struct {} = 0x90,
    i2b: struct {} = 0x91,
    i2c: struct {} = 0x92,
    i2s: struct {} = 0x93,

    // Comparisons
    lcmp: struct {} = 0x94,
    fcmpl: struct {} = 0x95,
    fcmpg: struct {} = 0x96,
    dcmpl: struct {} = 0x97,
    dcmpg: struct {} = 0x98,
    ifeq: struct { i16 } = 0x99,
    ifne: struct { i16 } = 0x9a,
    iflt: struct { i16 } = 0x9b,
    ifge: struct { i16 } = 0x9c,
    ifgt: struct { i16 } = 0x9d,
    ifle: struct { i16 } = 0x9e,
    if_icmpeq: struct { i16 } = 0x9f,
    if_icmpne: struct { i16 } = 0xa0,
    if_icmplt: struct { i16 } = 0xa1,
    if_icmpge: struct { i16 } = 0xa2,
    if_icmpgt: struct { i16 } = 0xa3,
    if_icmple: struct { i16 } = 0xa4,
    if_acmpeq: struct { i16 } = 0xa5,
    if_acmpne: struct { i16 } = 0xa6,

    // Control
    goto: struct { i16 } = 0xa7,
    jsr: struct { i16 } = 0xa8,
    ret: struct { u8 } = 0xa9,
    tableswitch: struct {
        default: i32,
        low: i32,
        high: i32,
        size: i32,          // high-low+1 elements
        offsets: [*]i32,    // this brings down the size of each OpCode by 8 bytes
// TODO: figure out how to serialize raw pointers
    } = 0xaa,
    lookupswitch: struct {
        default: i32,
        npairs: i32,
        pairs: [*]pair,     // npairs elements

        const pair = struct {
            match: i32,
            offset: i32,
        };
    } = 0xab,
    ireturn: struct {} = 0xac,
    lreturn: struct {} = 0xad,
    freturn: struct {} = 0xae,
    dreturn: struct {} = 0xaf,
    areturn: struct {} = 0xb0,
    @"return": struct {} = 0xb1,

    // References
    getstatic: struct { u16 } = 0xb2,
    putstatic: struct { u16 } = 0xb3,
    getfield: struct { u16 } = 0xb4,
    putfield: struct { u16 } = 0xb5,
    invokevirtual: struct { u16 } = 0xb6,
    invokespecial: struct { u16 } = 0xb7,
    invokestatic: struct { u16 } = 0xb8,
    invokeinterface: struct { u16, u8, u8 } = 0xb9,
    invokedynamic: struct { u16, u16 } = 0xba,
    new: struct { u16 } = 0xbb,
    newarray: struct { enum(u8) {
        T_BOOLEAN = 4,
        T_CHAR = 5,
        T_FLOAT = 6,
        T_DOUBLE = 7,
        T_BYTE = 8,
        T_SHORT = 9,
        T_INT = 10,
        T_LONG = 11,
    }} = 0xbc,
    anewarray: struct { u16 } = 0xbd,
    arraylength: struct { } = 0xbe,
    athrow: struct {} = 0xbf,
    checkcast: struct { u16 } = 0xc0,
    instanceof: struct { u16 } = 0xc1,
    monitorenter: struct {} = 0xc2,
    monitorexit: struct {} = 0xc3,

    // Extended
    wide: struct { 
        union(enum(u8)) {
            iinc: struct { u16, i16 } = 0x84,
            _: struct { u16 },
        }
    } = 0xc4,
    multianewarray: struct { u16, u8 } = 0xc5,
    ifnull: struct { i16 } = 0xc6,
    ifnonnull: struct { i16 } = 0xc7,
    goto_w: struct { i32 } = 0xc8,
    jsr_w: struct { i32 } = 0xc9,

    // Reserved
    breakpoint: struct {} = 0xca,
    impdep1: struct {} = 0xfe,
    impdep2: struct {} = 0xff,



    pub fn parse(offset: u32, reader: *Reader, allocator: Allocator) !struct { OpCode, u32 } {
        var new_offset = offset;
        const enumVariant = std.enums.fromInt(
            @typeInfo(OpCode).@"union".tag_type.?,
            try reader.takeByte()
        ).?;
        new_offset += 1;
        return switch(enumVariant) {
            inline .tableswitch => ret: {
                reader.toss(if(new_offset % 4 == 0) 0 else 4 - (new_offset % 4)); // padding
                const default = try reader.takeInt(i32, .big);
                const low = try reader.takeInt(i32, .big);
                const high = try reader.takeInt(i32, .big);
                new_offset += 12;
                const size = high - low + 1;
                const offsets = try allocator.alloc(i32, @intCast(size));
                for(0..@intCast(size)) |it| {
                    offsets[it] = try reader.takeInt(i32, .big);
                    new_offset += 4;
                }
                break :ret .{
                    @unionInit(OpCode, "tableswitch", .{
                        .default = default,
                        .low = low,
                        .high = high,
                        .size = size,
                        .offsets = offsets.ptr,
                    }),
                    new_offset,
                };
            },
            inline .lookupswitch => ret: {
                reader.toss(if(new_offset % 4 == 0) 0 else 4 - (new_offset % 4)); // padding
                const default = try reader.takeInt(i32, .big);
                const npairs = try reader.takeInt(i32, .big);
                const pairs = try allocator.alloc(@FieldType(OpCode, "lookupswitch").pair, @intCast(npairs));
                for(0..@intCast(npairs)) |it| {
                    pairs[it] = .{
                        .match = try reader.takeInt(i32, .big),
                        .offset = try reader.takeInt(i32, .big),
                    };
                    new_offset += 8;
                }
                break :ret .{
                    @unionInit(OpCode, "lookupswitch", .{
                        .default = default,
                        .npairs = npairs,
                        .pairs = pairs.ptr,
                    }),
                    new_offset,
                };
            },
            inline else => |e| ret: {
                const value, new_offset = try parseOp(new_offset, @FieldType(OpCode, @tagName(e)), reader);
                break :ret .{
                    @unionInit(OpCode, @tagName(e), value),
                    new_offset,
                };
            },
        };
    }

    fn parseOp(offset: u32, T: type, reader: *Reader) !struct { T, u32 } {
        var new_offset = offset;
        var result: T = undefined;
        inline for(@typeInfo(T).@"struct".fields) |f| {
            @field(result, f.name) = switch(@typeInfo(f.type)) {
                .int => ret: {
                    const int = try reader.takeInt(f.type, .big);
                    new_offset += @sizeOf(f.type);
                    break :ret int;
                },
                .@"union" => |u| ret: {
                    const enumTag = @typeInfo(u.tag_type.?);
                    if(enumTag.@"enum".tag_type == u8) {
                        const enumVariant = std.enums.fromInt(@Type(enumTag), try reader.takeByte()).?;
                        new_offset += 1;
                        switch(enumVariant) { inline else => |t| {
                            const fieldType = @FieldType(f.type, @tagName(t));
                            const value, new_offset = try parseOp(new_offset, fieldType, reader);
                            break :ret @unionInit(f.type, @tagName(t), value);
                        }}
                    } else unreachable;
                },
                .@"enum" => ret: {
                    const e = try std.meta.intToEnum(f.type, try reader.takeByte());
                    new_offset += 1;
                    break :ret e;
                },
                else => unreachable,
            };
        }
        return .{ result, new_offset };
    }
};
