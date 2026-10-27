module core.pak;

import std.file : exists, isFile, dirEntries, SpanMode, read;
import std.mmfile : MmFile;
import std.stdio : File, stderr;
import std.array : replace, array;
import std.algorithm : sort, map, filter;
import std.string : fromStringz, startsWith;
import std.uni : toLower;
import core.stdc.string : memcpy;
import raylib;

private __gshared MmFile mm;
private __gshared ubyte[][string] files;

string key(string p) {
    p = p.replace("\\", "/");
    if (p.startsWith("./")) p = p[2 .. $];
    return toLower(p);
}

bool mountPak(string path) {
    if (!exists(path)) return false;
    mm = new MmFile(path, MmFile.Mode.read, 0, null);
    auto d = cast(ubyte[]) mm[];
    
    size_t p = 0;
    while (p + 4 <= d.length) {
        uint len;  memcpy(&len, d.ptr + p, 4);  p += 4;
        string name = cast(string) d[p .. p + len].idup;  p += len;
        ulong size; memcpy(&size, d.ptr + p, 8);  p += 8;
        files[name] = d[p .. p + cast(size_t) size];
        p += cast(size_t) size;
    }
    SetLoadFileDataCallback(cast(LoadFileDataCallback) &pakData);
    SetLoadFileTextCallback(cast(LoadFileTextCallback) &pakText);
    return true;
}

const(ubyte)[] readBytes(string path) {
    if (mm !is null)
        if (auto f = key(path) in files) return *f;
    return cast(ubyte[]) read(path);
}

string readText(string path) {
    return cast(string) readBytes(path);
}

extern(C) private ubyte* pakData(const(char)* name, int* size) nothrow {
    *size = 0;
    if (mm is null) return null;
    try {
        auto f = key(fromStringz(name).idup) in files;
        if (!f || f.length == 0) return null;
        auto mem = cast(ubyte*) MemAlloc(cast(uint) f.length);
        memcpy(mem, f.ptr, f.length);
        *size = cast(int) f.length;
        return mem;
    } catch (Throwable) return null;
}

extern(C) private char* pakText(const(char)* name) nothrow {
    if (mm is null) return null;
    try {
        auto f = key(fromStringz(name).idup) in files;
        if (!f) return null;
        auto mem = cast(char*) MemAlloc(cast(uint) f.length + 1);
        memcpy(mem, f.ptr, f.length);
        mem[f.length] = 0;
        return mem;
    } catch (Throwable) return null;
}

void buildPak(string outPath, string[] roots) {
    auto f = File(outPath, "wb");
    scope(exit) f.close();

    void add(string name, const(ubyte)[] data) {
        uint len = cast(uint) name.length;
        ulong size = data.length;
        f.rawWrite((&len)[0 .. 1]);
        f.rawWrite(name);
        f.rawWrite((&size)[0 .. 1]);
        if (data.length) f.rawWrite(data);
    }

    foreach (r; roots) {
        if (!exists(r)) {
            stderr.writeln("pak: path not found, skipped: ", r);
            continue;
        }
        if (isFile(r)) {
            add(key(r), cast(ubyte[]) read(r));
            continue;
        }
        auto names = dirEntries(r, SpanMode.depth)
            .filter!(e => e.isFile)
            .map!(e => e.name)
            .array
            .sort
            .release;
        foreach (n; names) add(key(n), cast(ubyte[]) read(n));
    }
}