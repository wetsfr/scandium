// libtcc.d (TCC bindings)
// by wetsfr -w-
// mental-illness.cc
module libtcc;

extern(C):

struct TCCState;

alias TCCErrorFunc = extern(C) void function(void* opaque, const(char)* msg);
alias TCCSymbolCb = extern(C) void function(void* ctx, const(char)* name, const(void)* val);

enum int TCC_OUTPUT_MEMORY = 1;
enum int TCC_OUTPUT_EXE = 2;
enum int TCC_OUTPUT_DLL = 3;
enum int TCC_OUTPUT_OBJ = 4;
enum int TCC_OUTPUT_PREPROCESS = 5;

enum void* TCC_RELOCATE_AUTO = cast(void*) 1;

TCCState* tcc_new();
void tcc_delete(TCCState*);

void tcc_set_lib_path(TCCState*, const(char)* path);
void tcc_set_error_func(TCCState*, void* opaque, TCCErrorFunc);
TCCErrorFunc tcc_get_error_func(TCCState*);
void* tcc_get_error_opaque(TCCState*);
void tcc_set_options(TCCState*, const(char)* str);

int tcc_add_include_path(TCCState*, const(char)* path);
int tcc_add_sysinclude_path(TCCState*, const(char)* path);
void tcc_define_symbol(TCCState*, const(char)* sym, const(char)* value);
void tcc_undefine_symbol(TCCState*, const(char)* sym);

int tcc_add_file(TCCState*, const(char)* filename);
int tcc_compile_string(TCCState*, const(char)* buf);

int tcc_set_output_type(TCCState*, int type);
int tcc_add_library_path(TCCState*, const(char)* path);
int tcc_add_library(TCCState*, const(char)* name);
int tcc_add_symbol(TCCState*, const(char)* name, const(void)* val);

int tcc_output_file(TCCState*, const(char)* filename);
int tcc_run(TCCState*, int argc, char** argv);
int tcc_relocate(TCCState*, void* ptr);
void* tcc_get_symbol(TCCState*, const(char)* name);
void tcc_list_symbols(TCCState*, void* ctx, TCCSymbolCb);

extern(D):

import core.stdc.string : strlen;
import std.string : toStringz;
import std.traits : ReturnType, Parameters, functionLinkage;

enum TccOutput : int {
    memory = TCC_OUTPUT_MEMORY,
    exe = TCC_OUTPUT_EXE,
    dll = TCC_OUTPUT_DLL,
    obj = TCC_OUTPUT_OBJ,
    preprocess = TCC_OUTPUT_PREPROCESS,
}

struct TccLog {
    string[] lines;
}

private extern(C) void tccLogCb(void* opaque, const(char)* msg) {
    auto log = cast(TccLog*) opaque;
    log.lines ~= msg[0 .. strlen(msg)].idup;
}

void tccAttachLog(TCCState* s, TccLog* log) {
    tcc_set_error_func(s, log, &tccLogCb);
}

struct TccSym {
    string name;
    const(void)* addr;
}

private extern(C) void tccSymCb(void* ctx, const(char)* name, const(void)* val) {
    auto list = cast(TccSym[]*) ctx;
    *list ~= TccSym(name[0 .. strlen(name)].idup, val);
}

TccSym[] tccSymbols(TCCState* s) {
    TccSym[] list;
    tcc_list_symbols(s, &list, &tccSymCb);
    return list;
}

template cType(T) {
    static if (is(T == void)) enum cType = "void";
    else static if (is(T == bool)) enum cType = "_Bool";
    else static if (is(T == byte)) enum cType = "signed char";
    else static if (is(T == ubyte)) enum cType = "unsigned char";
    else static if (is(T == short)) enum cType = "short";
    else static if (is(T == ushort)) enum cType = "unsigned short";
    else static if (is(T == int)) enum cType = "int";
    else static if (is(T == uint)) enum cType = "unsigned int";
    else static if (is(T == long)) enum cType = "long long";
    else static if (is(T == ulong)) enum cType = "unsigned long long";
    else static if (is(T == float)) enum cType = "float";
    else static if (is(T == double)) enum cType = "double";
    else static if (is(T == const(char)*)) enum cType = "const char*";
    else static if (is(T == char*)) enum cType = "char*";
    else static if (is(T == U*, U)) enum cType = "void*";
    else static assert(0, "no C type for " ~ T.stringof);
}

string tccProto(alias fn)(string name = __traits(identifier, fn)) {
    alias P = Parameters!fn;
    string r = cType!(ReturnType!fn) ~ " " ~ name ~ "(";
    static foreach (i, T; P) {
        static if (i) r ~= ", ";
        r ~= cType!T;
    }
    static if (P.length == 0) r ~= "void";
    return r ~ ");";
}

int tccAddFn(alias fn)(TCCState* s, string name = __traits(identifier, fn)) {
    static assert(functionLinkage!fn == "C", "tccAddFn needs an extern(C) function");
    return tcc_add_symbol(s, name.toStringz, &fn);
}

struct TccFn(R, A...) {
    alias Fp = extern(C) R function(A);
    Fp ptr;
    this(Fp p) { ptr = p; }
    R opCall(A args) { return ptr(args); }
    bool opCast(T : bool)() const { return ptr !is null; }
}

TccFn!(R, A) tccFn(R, A...)(TCCState* s, string name) {
    return TccFn!(R, A)(cast(TccFn!(R, A).Fp) tcc_get_symbol(s, name.toStringz));
}

T* tccVar(T)(TCCState* s, string name) {
    return cast(T*) tcc_get_symbol(s, name.toStringz);
}

unittest {
    static extern(C) int twice(int x) { return x * 2; }

    auto s = tcc_new();
    scope(exit) tcc_delete(s);

    TccLog log;
    tccAttachLog(s, &log);

    tcc_set_output_type(s, TccOutput.memory);
    tccAddFn!twice(s);

    string src = tccProto!twice() ~ `
        int add_twice(int a, int b) { return twice(a + b); }
        int counter = 5;
    `;
    assert(tcc_compile_string(s, src.toStringz) == 0, log.lines.length ? log.lines[0] : "");
    assert(tcc_relocate(s, TCC_RELOCATE_AUTO) == 0);

    auto f = tccFn!(int, int, int)(s, "add_twice");
    assert(f && f(3, 4) == 14);
    assert(*tccVar!int(s, "counter") == 5);
}