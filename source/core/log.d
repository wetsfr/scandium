module core.log;
import std.datetime.systime : Clock;
import std.file : append, exists, mkdirRecurse;
import std.path : dirName;
import std.stdio : writeln;
import std.format;

final enum LogType {
    info,
    warning,
    error
}

final class Log {
    bool logToFile;
    string file = "log.txt";

    private this() {}
    private static shared Log _instance;
    static Log get() {
        if (_instance is null) {
            synchronized {
                if (_instance is null) _instance = cast(shared) new Log(); }
        }
        return cast(Log) _instance;
    }

    void init(bool log, string fileName) {
        this.logToFile = log;
        this.file = fileName;

        if (this.logToFile && this.file.length > 0) {
            try {
                string dir = dirName(this.file);
                if (dir.length > 0 && dir != "." && !exists(dir)) mkdirRecurse(dir);
                import std.file : write;
                write(this.file, ""); 
            } catch (Exception e) {
                writeln("\033[31m[Log Error] cannot clear file: \033[0m", e.msg);
            }
        }
    }

    void log(LogType type, string message) {
        string textPrefix;
        string colorPrefix;

        switch (type) {
            case LogType.info:
                textPrefix = "[Info]";
                colorPrefix = "\033[32m[Info]\033[0m";
                break;
            case LogType.warning:
                textPrefix = "[Warning]";
                colorPrefix = "\033[33m[Warning]\033[0m";
                break;
            case LogType.error:
                textPrefix = "[Error]";
                colorPrefix = "\033[31m[Error]\033[0m";
                break;
            default: 
                textPrefix = "[Log]";
                colorPrefix = "[Log]";
                break;
        }

        writeln(colorPrefix ~ " " ~ message);
        if (logToFile && file.length > 0) {
            try {
                string dir = dirName(file);
                if (dir.length > 0 && dir != "." && !exists(dir)) {
                    mkdirRecurse(dir);
                }
                auto time = Clock.currTime;
                string timestamp = format("[%02d:%02d:%02d] ", time.hour, time.minute, time.second);
                string fileOutput = timestamp ~ textPrefix ~ " " ~ message ~ "\n";
                append(file, fileOutput);
            } catch (Exception e) {
                writeln("\033[31m[Log Error] cannot write to file: \033[0m", e.msg);
            }
        }
    }
}
