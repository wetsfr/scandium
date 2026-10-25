// ini.d (.INI parser)
// by wetsfr -w-
// mental-illness.cc
module core.ini;

import std.string;
import std.conv : to;
import std.algorithm : startsWith, endsWith;
import std.array : split;
import std.file : readText;

struct Ini {
    string[string][string] data;

    string[string] opIndex(string section) const {
        if (auto s = section in data)
            return cast(string[string]) *s;
        return null;
    }

    string get(string section, string key, string def = "") const {
        if (auto s = section in data)
            if (auto v = key in *s)
                return *v;
        return def;
    }

    int getInt(string section, string key, int def = 0) const {
        auto s = get(section, key, null);
        if (s is null) return def;
        try return s.to!int;
        catch (Exception) return def;
    }

    float getFloat(string section, string key, float def = 0.0f) const {
        auto s = get(section, key, null);
        if (s is null) return def;
        try return s.to!float;
        catch (Exception) return def;
    }

    bool getBool(string section, string key, bool def = false) const {
        auto s = get(section, key, null);
        if (s is null) return def;
        switch (s.toLower) {
            case "true", "1", "yes", "on": return true;
            case "false", "0", "no", "off": return false;
            default: return def;
        }
    }

    bool hasSection(string section) const {
        return (section in data) !is null;
    }

    bool hasKey(string section, string key) const {
        if (auto s = section in data)
            return (key in *s) !is null;
        return false;
    }

    void set(string section, string key, string value) {
        data[section][key] = value;
    }

    string toString() const {
        string result;
        foreach (section, keys; data) {
            result ~= "[" ~ section ~ "]\n";
            foreach (key, value; keys)
                result ~= key ~ " = " ~ value ~ "\n";
            result ~= "\n";
        }
        return result;
    }
}

Ini parseIni(string text) {
    Ini ini;
    string currentSection = "";

    foreach (rawLine; text.splitLines()) {
        string line = rawLine.strip;
        if (line.length == 0) continue;
        if (line.startsWith(";") || line.startsWith("#")) continue;

        if (line.startsWith("[") && line.endsWith("]")) {
            currentSection = line[1 .. $ - 1].strip;
            continue;
        }

        auto eqIdx = line.indexOf('=');
        if (eqIdx < 0) continue;

        string key = line[0 .. eqIdx].strip;
        string value = line[eqIdx + 1 .. $].strip;

        if (value.length >= 2 &&
            ((value[0] == '"' && value[$ - 1] == '"') ||
             (value[0] == '\'' && value[$ - 1] == '\''))) {
            value = value[1 .. $ - 1];
        }

        ini.data[currentSection][key] = value;
    }

    return ini;
}

Ini parseIniFile(string path) {
    return parseIni(readText(path));
}