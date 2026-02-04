const std = @import("std");

pub const ClassFile = struct {
    magic: u32,
    minor_version: u16,
    major_version: u16,
    constant_pool_count: u16,
    constant_pool: []cp_info,
    access_flags: u16,
    this_class: u16,
    super_class: u16,
    interfaces_count: u16,
    interfaces: []u16,
    fields_count: u16,
    fields: []field_info,
    methods_count: u16,
    methods: []method_info,
    attributes_count: u16,
    attributes: []attribute_info,

    pub const access_flags_mask = enum(u16) {
        ACC_PUBLIC = 0x0001,
        ACC_FINAL = 0x0010,
        ACC_SUPER = 0x0020,
        ACC_INTERFACE = 0x0200,
        ACC_ABSTRACT = 0x0400,
        ACC_SYNTHETIC = 0x1000,
        ACC_ANNOTATION = 0x2000,
        ACC_ENUM = 0x4000,
        ACC_MODULE = 0x8000,
    };
};

pub const cp_info = union(enum(u8)) {
    Empty: struct {} = 0, // not in spec; set after Long/Double
    Utf8: struct {
        length: u16,
        bytes: []u8,
    } = 1,
    Integer: struct {
        bytes: u32,
    } = 3,
    Float: struct {
        bytes: u32,
    } = 4,
    Long: struct {
        high_bytes: u32,
        low_bytes: u32,
    } = 5,
    Double: struct {
        high_bytes: u32,
        low_bytes: u32,
    } = 6,
    Class: struct {
        name_index: u16,
    } = 7,
    String: struct {
        string_index: u16,
    } = 8,
    Fieldref: struct {
        class_index: u16,
        name_and_type_index: u16,
    } = 9,
    Methodref: struct {
        class_index: u16,
        name_and_type_index: u16,
    } = 10,
    InterfaceMethodref: struct {
        class_index: u16,
        name_and_type_index: u16,
    } = 11,
    NameAndType: struct {
        name_index: u16,
        descriptor_index: u16,
    } = 12,
    MethodHandle: struct {
        reference_kind: enum(u8) {
            REF_getField = 1,
            REF_getStatic = 2,
            REF_putField = 3,
            REF_putStatic = 4,
            REF_invokeVirtual = 5,
            REF_invokeStatic = 6,
            REF_invokeSpecial = 7,
            REF_newInvokeSpecial = 8,
            REF_invokeInterface = 9,
        },
        reference_index: u16,
    } = 15,
    MethodType: struct {
        descriptor_index: u16,
    } = 16,
    Dynamic: struct {
        bootstrap_method_attr_index: u16,
        name_and_type_index: u16,
    } = 17,
    InvokeDynamic: struct {
        bootstrap_method_attr_index: u16,
        name_and_type_index: u16,
    } = 18,
    Module: struct {
        name_index: u16,
    } = 19,
    Package: struct {
        name_index: u16,
    } = 20,
};

pub const field_info = struct {
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes_count: u16,
    attributes: []attribute_info,

    pub const access_flags_mask = enum(u16) {
        ACC_PUBLIC = 0x0001,
        ACC_PRIVATE = 0x0002,
        ACC_PROTECTED = 0x0004,
        ACC_STATIC = 0x0008,
        ACC_FINAL = 0x0010,
        ACC_VOLATILE = 0x0040,
        ACC_TRANSIENT = 0x0080,
        ACC_SYNTHETIC = 0x1000,
        ACC_ENUM = 0x4000,
    };
};

pub const method_info = struct {
    access_flags: u16,
    name_index: u16,
    descriptor_index: u16,
    attributes_count: u16,
    attributes: []attribute_info,

    pub const access_flags_mask = enum(u16) {
        ACC_PUBLIC = 0x0001,
        ACC_PRIVATE = 0x0002,
        ACC_PROTECTED = 0x0004,
        ACC_STATIC = 0x0008,
        ACC_FINAL = 0x0010,
        ACC_SYNCHRONIZED = 0x0020,
        ACC_BRIDGE = 0x0040,
        ACC_VARARGS = 0x0080,
        ACC_NATIVE = 0x0100,
        ACC_ABSTRACT = 0x0400,
        ACC_STRICT = 0x0800,
        ACC_SYNTHETIC = 0x1000,
    };
};

pub const attribute_info_enum = enum {
    ConstantValue,
    Code,
    StackMapTable,
    Exceptions,
    InnerClasses,
    EnclosingMethod,
    Synthetic,
    Signature,
    SourceFile,
    SourceDebugExtension,
    LineNumberTable,
    LocalVariableTable,
    LocalVariableTypeTable,
    Deprecated,
    RuntimeVisibleAnnotations,
    RuntimeInvisibleAnnotations,
    RuntimeVisibleParameterAnnotations,
    RuntimeInvisibleParameterAnnotations,
    RuntimeVisibleTypeAnnotations,
    RuntimeInvisibleTypeAnnotations,
    AnnotationDefault,
    BootstrapMethods,
    MethodParameters,
    Module,
    ModulePackages,
    ModuleMainClass,
    NestHost,
    NestMembers,
    Record,
    PermittedSubclasses,
};

pub const attribute_info = struct {
    attribute_name_index: u16,
    attribute_length: u32,
    info: union(attribute_info_enum) {
        ConstantValue: struct {
            constantvalue_index: u16,
        },
        Code: struct {
            max_stack: u16,
            max_locals: u16,
            code_length: u32,
            code: []u8,
            exception_table_length: u16,
            exception_table: []struct {
                start_pc: u16,
                end_pc: u16,
                handler_pc: u16,
                catch_type: u16,
            },
            attributes_count: u16,
            attributes: []attribute_info,
        },
        StackMapTable: struct {
            number_of_entries: u16,
            entries: []stack_map_frame,
        },
        Exceptions: struct {
            number_of_exceptions: u16,
            exception_index_table: []u16,
        },
        InnerClasses: struct {
            number_of_classes: u16,
            classes: []struct {
                inner_class_info_index: u16,
                outer_class_info_index: u16,
                inner_name_index: u16,
                inner_class_access_flags: u16,
            },

            pub const access_flags_mask = enum(u16) {
                ACC_PUBLIC = 0x0001,
                ACC_PRIVATE = 0x0002,
                ACC_PROTECTED = 0x0004,
                ACC_STATIC = 0x0008,
                ACC_FINAL = 0x0010,
                ACC_INTERFACE = 0x0200,
                ACC_ABSTRACT = 0x0400,
                ACC_SYNTHETIC = 0x1000,
                ACC_ANNOTATION = 0x2000,
                ACC_ENUM = 0x4000,
            };
        },
        EnclosingMethod: struct {
            class_index: u16,
            method_index: u16,
        },
        Synthetic: struct {},
        Signature: struct {
            signature_index: u16,
        },
        SourceFile: struct {
            sourcefile_index: u16,
        },
        SourceDebugExtension: struct {
            debug_extension: []u8,
        },
        LineNumberTable: struct {
            line_number_table_length: u16,
            line_number_table: []struct {
                start_pc: u16,
                line_number: u16,
            },
        },
        LocalVariableTable: struct {
            local_variable_table_length: u16,
            local_variable_table: []struct {
                start_pc: u16,
                length: u16,
                name_index: u16,
                descriptor_index: u16,
                index: u16,
            },
        },
        LocalVariableTypeTable: struct {
            local_variable_type_table_length: u16,
            local_variable_type_table: []struct {
                start_pc: u16,
                length: u16,
                name_index: u16,
                signature_index: u16,
                index: u16,
            },
        },
        Deprecated: struct {},
        RuntimeVisibleAnnotations: struct {
            num_annotations: u16,
            annotations: []annotation,
        },
        RuntimeInvisibleAnnotations: struct {
            num_annotations: u16,
            annotations: []annotation,
        },
        RuntimeVisibleParameterAnnotations: struct {
            num_parameters: u8,
            parameter_annotations: []struct {
                num_annotations: u16,
                annotations: []annotation,
            },
        },
        RuntimeInvisibleParameterAnnotations: struct {
            num_parameters: u8,
            parameter_annotations: []struct {
                num_annotations: u16,
                annotations: []annotation,
            },
        },
        RuntimeVisibleTypeAnnotations: struct {
            num_annotations: u16,
            annotations: []type_annotation,
        },
        RuntimeInvisibleTypeAnnotations: struct {
            num_annotations: u16,
            annotations: []type_annotation,
        },
        AnnotationDefault: struct {
            default_value: element_value,
        },
        BootstrapMethods: struct {
            num_bootstrap_methods: u16,
            bootstrap_methods: []struct {
                bootstrap_method_ref: u16,
                num_bootstrap_arguments: u16,
                bootstrap_arguments: []u16,
            },
        },
        MethodParameters: struct {
            parameters_count: u8,
            parameters: []struct {
                name_index: u16,
                access_flags: u16,
            },

            pub const access_flags_mask = enum(u16) {
                ACC_FINAL = 0x0010,
                ACC_SYNTHETIC = 0x1000,
                ACC_MANDATED = 0x8000,
            };
        },
        Module: struct {
            module_name_index: u16,
            module_flags: u16,
            module_version_index: u16,

            requires_count: u16,
            requires: []struct {
                requires_index: u16,
                requires_flags: u16,
                requires_version_index: u16,
            },
        
            exports_count: u16,
            exports: []struct {
                exports_index: u16,
                exports_flags: u16,
                exports_to_count: u16,
                exports_to_index: []u16,
            },

            opens_count: u16,
            opens: []struct {
                opens_index: u16,
                opens_flags: u16,
                opens_to_count: u16,
                opens_to_index: []u16,
            },

            uses_count: u16,
            uses_index: []u16,
        
            provides_count: u16,
            provides: []struct {
                provides_index: u16,
                provides_with_count: u16,
                provides_with_index: []u16,
            },

            pub const module_flags_mask = enum(u16) {
                ACC_OPEN = 0x0020,
                ACC_SYNTHETIC = 0x1000,
                ACC_MANDATED = 0x8000,
            };
            
            pub const requires_flags_mask = enum(u16) {
                ACC_TRANSITIVE = 0x0020,
                ACC_STATIC_PHASE = 0x0040,
                ACC_SYNTHETIC = 0x1000,
                ACC_MANDATED = 0x8000,
            };

            pub const exports_flags_mask = enum(u16) {
                ACC_SYNTHETIC = 0x1000,
                ACC_MANDATED = 0x8000,
            };

            pub const opens_flags_mask = enum(u16) {
                ACC_SYNTHETIC = 0x1000,
                ACC_MANDATED = 0x8000,
            };
        },
        ModulePackages: struct {
            package_count: u16,
            package_index: []u16,
        },
        ModuleMainClass: struct {
            main_class_index: u16,
        },
        NestHost: struct {
            host_class_index: u16,
        },
        NestMembers: struct {
            number_of_classes: u16,
            classes: []u16,
        },
        Record: struct {
            components_count: u16,
            components: []record_component_info,
        },
        PermittedSubclasses: struct {
            number_of_classes: u16,
            classes: []u16,
        }
    }
};

pub const record_component_info = struct {
    name_index: u16,
    descriptor_index: u16,
    attributes_count: u16,
    attributes: []attribute_info,
};

pub const type_annotation = struct {
    target_type: u8, //https://docs.oracle.com/javase/specs/jvms/se25/html/jvms-4.html#jvms-4.7.20
    target_info: union(enum) {
        type_parameter_target: struct {
            type_parameter: u8,
        },
        supertype_target: struct {
            supertype_index: u16,
        },
        type_parameter_bound_target: struct {
            type_parameter_index: u8,
            bound_index: u8,
        },
        empty_target: struct {},
        formal_parameter_target: struct {
            formal_parameter_index: u8,   
        },
        throws_target: struct {
            throws_type_index: u16,
        },
        localvar_target: struct {
            table_length: u16,
            table: []struct {
                start_pc: u16,
                length: u16,
                index: u16,
            },
        },
        catch_target: struct {
            exception_table_index: u16,
        },
        offset_target: struct { 
            offset: u16,
        },
        type_argument_target: struct {
            offset: u16,
            type_argument_index: u8,
        },
    },
    target_path: type_path,
    type_index: u16,
    num_element_value_pairs: u16,
    element_value_pairs: []struct {
        element_name_index: u16,
        value: element_value,
    },
};

pub const type_path = struct {
    path_length: u8,
    path: []struct {
        type_path_kind: u8, // TODO ?
        type_argument_kind: u8,
    },
};

pub const annotation = struct {
    type_index: u16,
    num_element_value_pairs: u16,
    element_value_pairs: []struct {
        element_name_index: u16,
        value: element_value,
    },
};

pub const element_value = struct {
    tag: enum(u8) {
        byte = 'B',
        char = 'C',
        double = 'D',
        float = 'F',
        int = 'I',
        long = 'J',
        short = 'S',
        boolean = 'Z',
        String = 's',
        Enum = 'e',
        Class = 'c',
        Annotation = '@',
        Array = '[',
    },
    value: union(enum) {
        const_value_index: u16,
        enum_info_index: struct {
            type_name_index: u16,
            const_name_index: u16,
        },
        class_info_index: u16,
        annotation_value: annotation,
        array_value: struct {
            num_values: u16,
            values: []element_value
        },
    }
};

pub const verification_type_info = union(enum(u8)) {
    Top: struct {} = 0,
    Integer: struct {} = 1,
    Float: struct {} = 2,
    Double: struct {} = 3,
    Long: struct {} = 4,
    Null: struct {} = 5,
    UninitializedThis: struct {} = 6,
    Object: struct { cpool_index: u16, } = 7,
    Uninitialized: struct { offset: u16, } = 8,
};

pub const stack_map_frame_enum = enum {
    same_frame,
    same_locals_1_stack_item_frame,
    same_locals_1_stack_item_frame_extended,
    chop_frame,
    same_frame_extended,
    append_frame,
    full_frame,
};

pub const stack_map_frame = union(stack_map_frame_enum) {
    same_frame: struct {
        frame_type: u8, // 0-63
    },
    same_locals_1_stack_item_frame: struct {
        frame_type: u8, // 64-127
        stack: []verification_type_info,
    },
    same_locals_1_stack_item_frame_extended: struct {
        frame_type: u8, // 247
        offset_delta: u16,
        stack: []verification_type_info,
    },
    chop_frame: struct {
        frame_type: u8, // 248-250
        offset_delta: u16,
    },
    same_frame_extended: struct {
        frame_type: u8, // 251
        offset_delta: u16,
    },
    append_frame: struct {
        frame_type: u8, // 252-254
        offset_delta: u16,
        locals: []verification_type_info,
    },
    full_frame: struct {
        frame_type: u8, //255
        offset_delta: u16,
        number_of_locals: u16,
        locals: []verification_type_info,
        number_of_stack_items: u16,
        stack: []verification_type_info,
    }
};
