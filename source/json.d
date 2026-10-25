// json.d
// by wetsfr -w-
// mental-illness.cc
module json;

import std.conv : to, ConvException;
import std.traits : Unqual, isIntegral, isFloatingPoint, isSomeString, isAssociativeArray, isDynamicArray, isStaticArray, KeyType, ValueType, FieldNameTuple, OriginalType;
import std.array : appender, Appender;
import std.algorithm : sort, remove;
import std.format : format;
import std.file : readText, write;
import std.utf : encode;

enum JsonType { null_, boolean, integer, floating, string_, array, object }

class JsonException : Exception {
    this(string msg, string file = __FILE__, size_t line = __LINE__) {
        super(msg, file, line);
    }
}

struct Json {
    private JsonType t_ = JsonType.null_;
    private bool bool_;
    private long int_;
    private double flt_ = 0.0;
    private string str_;
    private Json[] arr_;
    private Json[string] obj_;

    this(T)(T v) if (!is(Unqual!T == Json)) {
        set(v);
    }
    
    this(ref return scope const Json o) {
        copyFrom(o);
    }

    ref Json opAssign(T)(T v) if (!is(Unqual!T == Json)) {
        set(v);
        return this;
    }

    private void copyFrom(ref const Json o) {
        t_ = o.t_;
        bool_ = o.bool_;
        int_ = o.int_;
        flt_ = o.flt_;
        str_ = o.str_;
        if (o.t_ == JsonType.array) {
            arr_ = new Json[o.arr_.length];
            foreach (i, ref e; o.arr_) arr_[i].copyFrom(e);
        } else if (o.t_ == JsonType.object) {
            foreach (k, ref v; o.obj_) obj_.require(k, Json.init).copyFrom(v);
        }
    }

    private void reset() {
        t_ = JsonType.null_;
        bool_ = false;
        int_ = 0;
        flt_ = 0.0;
        str_ = null;
        arr_ = null;
        obj_ = null;
    }
    
    private void set(T)(T v) {
        alias U = Unqual!T;
        static if (is(U == typeof(null))) {
            reset();
        } else static if (is(U == bool)) {
            reset();
            t_ = JsonType.boolean;
            bool_ = v;
        } else static if (is(U == enum)) {
            set(cast(OriginalType!U) v);
        } else static if (isIntegral!U) {
            reset();
            t_ = JsonType.integer;
            int_ = cast(long) v;
        } else static if (isFloatingPoint!U) {
            reset();
            t_ = JsonType.floating;
            static if (is(U == float)) flt_ = shortestFloat(v);
            else flt_ = cast(double) v;
        } else static if (isSomeString!U) {
            reset();
            t_ = JsonType.string_;
            str_ = to!string(v);
        } else static if (isDynamicArray!U || isStaticArray!U) {
            reset();
            t_ = JsonType.array;
            arr_ = new Json[v.length];
            foreach (i, ref e; v) arr_[i] = Json(e);
        } else static if (isAssociativeArray!U && isSomeString!(KeyType!U)) {
            reset();
            t_ = JsonType.object;
            foreach (k, ref e; v) obj_[to!string(k)] = Json(e);
        } else static if (is(U == struct)) {
            reset();
            t_ = JsonType.object;
            foreach (name; FieldNameTuple!U) obj_[name] = Json(__traits(getMember, v, name));
        } else {
            static assert(false, "json: unsupported type " ~ T.stringof);
        }
    }

    static Json array(Args...)(Args args) {
        Json j;
        j.t_ = JsonType.array;
        foreach (a; args) j.arr_ ~= Json(a);
        return j;
    }

    static Json object(Args...)(Args args) {
        static assert(Args.length % 2 == 0, "json: object() takes key, value pairs");
        Json j;
        j.t_ = JsonType.object;
        static foreach (i; 0 .. Args.length / 2)
            j.obj_[to!string(args[i * 2])] = Json(args[i * 2 + 1]);
        return j;
    }

    static Json parse(const(char)[] text, bool ignoreComments = false) {
        if (text.length >= 3 && text[0 .. 3] == "\xEF\xBB\xBF") text = text[3 .. $];
        auto ps = Parser(text, 0, ignoreComments);
        Json j = ps.value();
        ps.ws();
        if (ps.p != text.length) throw ps.err("unexpected trailing characters");
        return j;
    }

    static Json parseFile(string path, bool ignoreComments = false) {
        return parse(readText(path), ignoreComments);
    }

    void saveFile(string path, int indent = 4) const {
        write(path, dump(indent) ~ "\n");
    }

    JsonType type() const { return t_; }
    bool isNull() const { return t_ == JsonType.null_; }
    bool isBool() const { return t_ == JsonType.boolean; }
    bool isInteger() const { return t_ == JsonType.integer; }
    bool isFloat() const { return t_ == JsonType.floating; }
    bool isNumber() const { return t_ == JsonType.integer || t_ == JsonType.floating; }
    bool isString() const { return t_ == JsonType.string_; }
    bool isArray() const { return t_ == JsonType.array; }
    bool isObject() const { return t_ == JsonType.object; }

    T get(T)() const {
        alias U = Unqual!T;
        static if (is(U == Json)) {
            Json r;
            r.copyFrom(this);
            return r;
        } else static if (is(U == bool)) {
            if (t_ != JsonType.boolean) throw new JsonException("not a boolean: " ~ dump());
            return bool_;
        } else static if (is(U == enum)) {
            return cast(U) get!(OriginalType!U)();
        } else static if (isIntegral!U) {
            if (t_ == JsonType.integer) return cast(U) int_;
            if (t_ == JsonType.floating) return cast(U) flt_;
            throw new JsonException("not a number: " ~ dump());
        } else static if (isFloatingPoint!U) {
            if (t_ == JsonType.floating) return cast(U) flt_;
            if (t_ == JsonType.integer) return cast(U) int_;
            throw new JsonException("not a number: " ~ dump());
        } else static if (isSomeString!U) {
            if (t_ != JsonType.string_) throw new JsonException("not a string: " ~ dump());
            return to!U(str_);
        } else static if (isDynamicArray!U) {
            if (t_ != JsonType.array) throw new JsonException("not an array: " ~ dump());
            alias E = typeof(U.init[0]);
            U r;
            foreach (ref e; arr_) r ~= e.get!E();
            return r;
        } else static if (isStaticArray!U) {
            if (t_ != JsonType.array || arr_.length != U.length) throw new JsonException("array size mismatch: " ~ dump());
            alias E = typeof(U.init[0]);
            U r;
            foreach (i, ref e; arr_) r[i] = e.get!E();
            return r;
        } else static if (isAssociativeArray!U && isSomeString!(KeyType!U)) {
            if (t_ != JsonType.object) throw new JsonException("not an object: " ~ dump());
            alias V = ValueType!U;
            U r;
            foreach (k, ref e; obj_) r[to!(KeyType!U)(k)] = e.get!V();
            return r;
        } else static if (is(U == struct)) {
            if (t_ != JsonType.object) throw new JsonException("not an object: " ~ dump());
            U r;
            foreach (name; FieldNameTuple!U) {
                alias FT = typeof(__traits(getMember, r, name));
                if (auto p = name in obj_) __traits(getMember, r, name) = p.get!FT();
            }
            return r;
        } else {
            static assert(false, "json: unsupported type " ~ T.stringof);
        }
    }

    T value(T)(string key, T def) const {
        if (t_ != JsonType.object) return def;
        auto p = key in obj_;
        if (p is null || p.isNull) return def;
        return p.get!T();
    }

    ref Json opIndex(string key) {
        if (t_ == JsonType.null_) t_ = JsonType.object;
        if (t_ != JsonType.object) throw new JsonException("cannot use [\"" ~ key ~ "\"] on non-object");
        return obj_.require(key, Json.init);
    }

    ref const(Json) opIndex(string key) const {
        return at(key);
    }

    ref Json opIndex(size_t i) {
        if (t_ == JsonType.null_) t_ = JsonType.array;
        if (t_ != JsonType.array) throw new JsonException("cannot use [" ~ to!string(i) ~ "] on non-array");
        if (i >= arr_.length) arr_.length = i + 1;
        return arr_[i];
    }

    ref const(Json) opIndex(size_t i) const {
        return at(i);
    }

    ref inout(Json) at(string key) inout {
        if (t_ != JsonType.object) throw new JsonException("at(\"" ~ key ~ "\"): not an object");
        if (auto p = key in obj_) return *p;
        throw new JsonException("key not found: " ~ key);
    }

    ref inout(Json) at(size_t i) inout {
        if (t_ != JsonType.array) throw new JsonException("at(" ~ to!string(i) ~ "): not an array");
        if (i >= arr_.length) throw new JsonException("index out of range: " ~ to!string(i));
        return arr_[i];
    }

    bool contains(string key) const {
        return t_ == JsonType.object && (key in obj_) !is null;
    }

    string[] keys() const {
        string[] r;
        if (t_ == JsonType.object) foreach (k, ref v; obj_) r ~= k;
        sort(r);
        return r;
    }

    size_t size() const {
        switch (t_) {
            case JsonType.null_: return 0;
            case JsonType.array: return arr_.length;
            case JsonType.object: return obj_.length;
            default: return 1;
        }
    }

    size_t length() const { return size(); }

    bool empty() const {
        switch (t_) {
            case JsonType.null_: return true;
            case JsonType.array: return arr_.length == 0;
            case JsonType.object: return obj_.length == 0;
            default: return false;
        }
    }

    void clear() {
        switch (t_) {
            case JsonType.boolean: bool_ = false; break;
            case JsonType.integer: int_ = 0; break;
            case JsonType.floating: flt_ = 0.0; break;
            case JsonType.string_: str_ = null; break;
            case JsonType.array: arr_ = null; break;
            case JsonType.object: obj_ = null; break;
            default: break;
        }
    }

    void pushBack(T)(T v) {
        if (t_ == JsonType.null_) t_ = JsonType.array;
        if (t_ != JsonType.array) throw new JsonException("pushBack on non-array");
        arr_ ~= Json(v);
    }

    void opOpAssign(string op : "~", T)(T v) {
        pushBack(v);
    }

    bool erase(string key) {
        if (t_ != JsonType.object) return false;
        return obj_.remove(key);
    }

    void erase(size_t i) {
        if (t_ != JsonType.array) throw new JsonException("erase(index) on non-array");
        if (i >= arr_.length) throw new JsonException("index out of range: " ~ to!string(i));
        arr_ = arr_.remove(i);
    }

    int opApply(scope int delegate(ref Json) dg) {
        if (t_ == JsonType.array) {
            foreach (ref e; arr_) if (auto r = dg(e)) return r;
        } else if (t_ == JsonType.object) {
            foreach (k; keys()) if (auto r = dg(obj_[k])) return r;
        }
        return 0;
    }

    int opApply(scope int delegate(ref const Json) dg) const {
        if (t_ == JsonType.array) {
            foreach (ref e; arr_) if (auto r = dg(e)) return r;
        } else if (t_ == JsonType.object) {
            foreach (k; keys()) if (auto r = dg(obj_[k])) return r;
        }
        return 0;
    }

    auto items() const {
        static struct Items {
            const(Json)* j;
            int opApply(scope int delegate(string, ref const Json) dg) const {
                if (j.t_ == JsonType.object) {
                    foreach (k; j.keys()) if (auto r = dg(k, j.obj_[k])) return r;
                } else if (j.t_ == JsonType.array) {
                    foreach (i, ref e; j.arr_) if (auto r = dg(to!string(i), e)) return r;
                }
                return 0;
            }
        }
        return Items(&this);
    }

    bool opEquals()(auto ref const Json o) const {
        if (isNumber && o.isNumber) {
            if (t_ == JsonType.integer && o.t_ == JsonType.integer) return int_ == o.int_;
            double a = t_ == JsonType.integer ? cast(double) int_ : flt_;
            double b = o.t_ == JsonType.integer ? cast(double) o.int_ : o.flt_;
            return a == b;
        }
        if (t_ != o.t_) return false;
        switch (t_) {
            case JsonType.null_: return true;
            case JsonType.boolean: return bool_ == o.bool_;
            case JsonType.string_: return str_ == o.str_;
            case JsonType.array:
                if (arr_.length != o.arr_.length) return false;
                foreach (i; 0 .. arr_.length) if (!(arr_[i] == o.arr_[i])) return false;
                return true;
            case JsonType.object:
                if (obj_.length != o.obj_.length) return false;
                foreach (k, ref v; obj_) {
                    auto p = k in o.obj_;
                    if (p is null || !(v == *p)) return false;
                }
                return true;
            default: return false;
        }
    }

    bool opEquals(T)(T v) const if (!is(Unqual!T == Json)) {
        return opEquals(Json(v));
    }

    string dump(int indent = -1) const {
        auto sb = appender!string;
        dumpTo(sb, indent, 0);
        return sb.data;
    }

    string toString() const {
        return dump();
    }

    private void dumpTo(ref Appender!string sb, int indent, int level) const {
        final switch (t_) {
            case JsonType.null_:
                sb.put("null");
                break;
            case JsonType.boolean:
                sb.put(bool_ ? "true" : "false");
                break;
            case JsonType.integer:
                sb.put(to!string(int_));
                break;
            case JsonType.floating:
                sb.put(fmtFloat(flt_));
                break;
            case JsonType.string_:
                escapeTo(sb, str_);
                break;
            case JsonType.array:
                if (arr_.length == 0) {
                    sb.put("[]");
                    break;
                }
                sb.put('[');
                foreach (i, ref e; arr_) {
                    if (i > 0) sb.put(',');
                    nl(sb, indent, level + 1);
                    e.dumpTo(sb, indent, level + 1);
                }
                nl(sb, indent, level);
                sb.put(']');
                break;
            case JsonType.object:
                if (obj_.length == 0) {
                    sb.put("{}");
                    break;
                }
                sb.put('{');
                foreach (i, k; keys()) {
                    if (i > 0) sb.put(',');
                    nl(sb, indent, level + 1);
                    escapeTo(sb, k);
                    sb.put(indent < 0 ? ":" : ": ");
                    obj_[k].dumpTo(sb, indent, level + 1);
                }
                nl(sb, indent, level);
                sb.put('}');
                break;
        }
    }
}

private void nl(ref Appender!string sb, int indent, int level) {
    if (indent < 0) return;
    sb.put('\n');
    foreach (_; 0 .. indent * level) sb.put(' ');
}

private void escapeTo(ref Appender!string sb, const(char)[] s) {
    enum hex = "0123456789abcdef";
    sb.put('"');
    foreach (char c; s) {
        switch (c) {
            case '"': sb.put("\\\""); break;
            case '\\': sb.put("\\\\"); break;
            case '\n': sb.put("\\n"); break;
            case '\r': sb.put("\\r"); break;
            case '\t': sb.put("\\t"); break;
            case '\b': sb.put("\\b"); break;
            case '\f': sb.put("\\f"); break;
            default:
                if (c < 0x20) {
                    sb.put("\\u00");
                    sb.put(hex[c >> 4]);
                    sb.put(hex[c & 15]);
                } else {
                    sb.put(c);
                }
        }
    }
    sb.put('"');
}

private string fmtFloat(double d) {
    if (d != d || d == double.infinity || d == -double.infinity) return "null";
    string s;
    foreach (prec; 15 .. 18) {
        s = format("%." ~ to!string(prec) ~ "g", d);
        if (to!double(s) == d) break;
    }
    foreach (c; s) if (c == '.' || c == 'e' || c == 'E') return s;
    return s ~ ".0";
}

private double shortestFloat(float f) {
    if (f != f || f == float.infinity || f == -float.infinity) return f;
    foreach (prec; 6 .. 10) {
        auto s = format("%." ~ to!string(prec) ~ "g", f);
        if (to!float(s) == f) return to!double(s);
    }
    return f;
}

private bool isDigit(char c) {
    return c >= '0' && c <= '9';
}

private struct Parser {
    const(char)[] s;
    size_t p;
    bool comments;
    int depth;

    JsonException err(string msg) const {
        size_t line = 1, col = 1;
        foreach (i; 0 .. (p < s.length ? p : s.length)) {
            if (s[i] == '\n') {
                line++;
                col = 1;
            } else {
                col++;
            }
        }
        return new JsonException("parse error at line " ~ to!string(line) ~ ", column " ~ to!string(col) ~ ": " ~ msg);
    }

    void ws() {
        while (p < s.length) {
            char c = s[p];
            if (c == ' ' || c == '\t' || c == '\n' || c == '\r') {
                p++;
            } else if (comments && c == '/' && p + 1 < s.length && s[p + 1] == '/') {
                while (p < s.length && s[p] != '\n') p++;
            } else if (comments && c == '/' && p + 1 < s.length && s[p + 1] == '*') {
                p += 2;
                while (p + 1 < s.length && !(s[p] == '*' && s[p + 1] == '/')) p++;
                if (p + 1 >= s.length) throw err("unterminated comment");
                p += 2;
            } else {
                break;
            }
        }
    }

    Json value() {
        ws();
        if (p >= s.length) throw err("unexpected end of input");
        switch (s[p]) {
            case '{': return object();
            case '[': return array();
            case '"': return Json(str());
            case 't': lit("true"); return Json(true);
            case 'f': lit("false"); return Json(false);
            case 'n': lit("null"); return Json.init;
            default: return number();
        }
    }

    void lit(string w) {
        if (p + w.length > s.length || s[p .. p + w.length] != w) throw err("invalid literal");
        p += w.length;
    }

    Json object() {
        if (++depth > 512) throw err("nesting too deep");
        Json j;
        j.t_ = JsonType.object;
        p++;
        ws();
        if (p < s.length && s[p] == '}') {
            p++;
            depth--;
            return j;
        }
        while (true) {
            ws();
            if (p >= s.length || s[p] != '"') throw err("expected string key");
            string k = str();
            ws();
            if (p >= s.length || s[p] != ':') throw err("expected ':'");
            p++;
            j.obj_[k] = value();
            ws();
            if (p >= s.length) throw err("unexpected end of input");
            if (s[p] == ',') {
                p++;
                continue;
            }
            if (s[p] == '}') {
                p++;
                break;
            }
            throw err("expected ',' or '}'");
        }
        depth--;
        return j;
    }

    Json array() {
        if (++depth > 512) throw err("nesting too deep");
        Json j;
        j.t_ = JsonType.array;
        p++;
        ws();
        if (p < s.length && s[p] == ']') {
            p++;
            depth--;
            return j;
        }
        while (true) {
            j.arr_ ~= value();
            ws();
            if (p >= s.length) throw err("unexpected end of input");
            if (s[p] == ',') {
                p++;
                continue;
            }
            if (s[p] == ']') {
                p++;
                break;
            }
            throw err("expected ',' or ']'");
        }
        depth--;
        return j;
    }

    uint hex4() {
        if (p + 4 > s.length) throw err("invalid \\u escape");
        uint v = 0;
        foreach (i; 0 .. 4) {
            char c = s[p++];
            v <<= 4;
            if (c >= '0' && c <= '9') v |= c - '0';
            else if (c >= 'a' && c <= 'f') v |= c - 'a' + 10;
            else if (c >= 'A' && c <= 'F') v |= c - 'A' + 10;
            else throw err("invalid \\u escape");
        }
        return v;
    }

    string str() {
        p++;
        auto sb = appender!string;
        while (true) {
            if (p >= s.length) throw err("unterminated string");
            char c = s[p++];
            if (c == '"') break;
            if (c < 0x20) throw err("control character in string");
            if (c != '\\') {
                sb.put(c);
                continue;
            }
            if (p >= s.length) throw err("unterminated string");
            char e = s[p++];
            switch (e) {
                case '"': sb.put('"'); break;
                case '\\': sb.put('\\'); break;
                case '/': sb.put('/'); break;
                case 'b': sb.put('\b'); break;
                case 'f': sb.put('\f'); break;
                case 'n': sb.put('\n'); break;
                case 'r': sb.put('\r'); break;
                case 't': sb.put('\t'); break;
                case 'u':
                    uint cp = hex4();
                    if (cp >= 0xD800 && cp <= 0xDBFF) {
                        if (p + 1 < s.length && s[p] == '\\' && s[p + 1] == 'u') {
                            p += 2;
                            uint lo = hex4();
                            if (lo < 0xDC00 || lo > 0xDFFF) throw err("invalid surrogate pair");
                            cp = 0x10000 + ((cp - 0xD800) << 10) + (lo - 0xDC00);
                        } else {
                            throw err("lone surrogate");
                        }
                    } else if (cp >= 0xDC00 && cp <= 0xDFFF) {
                        throw err("lone surrogate");
                    }
                    char[4] buf;
                    auto n = encode(buf, cast(dchar) cp);
                    sb.put(buf[0 .. n]);
                    break;
                default:
                    throw err("invalid escape sequence");
            }
        }
        return sb.data;
    }

    Json number() {
        size_t st = p;
        if (s[p] == '-') p++;
        if (p >= s.length) throw err("invalid number");
        if (s[p] == '0') {
            p++;
        } else if (s[p] >= '1' && s[p] <= '9') {
            while (p < s.length && isDigit(s[p])) p++;
        } else {
            throw err("invalid value");
        }
        bool flt = false;
        if (p < s.length && s[p] == '.') {
            flt = true;
            p++;
            size_t d0 = p;
            while (p < s.length && isDigit(s[p])) p++;
            if (p == d0) throw err("invalid number");
        }
        if (p < s.length && (s[p] == 'e' || s[p] == 'E')) {
            flt = true;
            p++;
            if (p < s.length && (s[p] == '+' || s[p] == '-')) p++;
            size_t d0 = p;
            while (p < s.length && isDigit(s[p])) p++;
            if (p == d0) throw err("invalid number");
        }
        auto txt = s[st .. p];
        if (!flt) {
            try {
                return Json(to!long(txt));
            } catch (ConvException) {}
        }
        return Json(to!double(txt));
    }
}