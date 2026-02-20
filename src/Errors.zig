//---------- Global Errors ----------//

pub const MemoryError = error.MemoryError;

pub const ReadFailed = error.ReadFailed;

//---------- Bytecode Errors ----------//

pub const MalformedError = error {
    InvalidEnumType,
    InvalidCodeLength,
};

pub const ParserImplError = error {
    InvalidCallbackImpl,
    NotYetImplemented,
}; // these should not happen anymore

pub const ParseError = error {
    MemoryError,
    ReadFailed,
} || MalformedError
  || ParserImplError
   ;

pub const FormatError = error {
    InvalidMagic,
    InvalidFileLength,
    InvalidConstantPool,
};

//---------- VFS Errors ----------//

pub const FileSystemError = error {
    StatFailed,
    OpeningFailed,
};

pub const ZipError = error {
    InitFailed,
    StatFailed,
    ExtractionFailed,
    InvalidFileName,
    MemoryError,
};


pub const JarError = error {
    InvalidClassFilePath,
};


pub const VFSError = error {
    InvalidInput,
} || FileSystemError
  || ZipError
  || JarError
   ;

pub const VFSParseError = VFSError
                     ||   ParseError
                      ;
