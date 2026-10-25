module ecs.event_bus;

import std.traits;
import std.meta;
import std.algorithm;
import std.array;

alias EventHandler(T) = void delegate(ref T);
alias EventCallback = void delegate(const(void)*);

final class EventBus {
    private EventCallback[][TypeInfo] handlers;

    void subscribe(T)(void delegate(ref T) handler) {
        auto ti = typeid(T);
        EventCallback wrapper = delegate(const(void)* ptr) {
            handler(*cast(T*) ptr);
        };
        handlers[ti] ~= wrapper;
    }

    void unsubscribe(T)(void delegate(ref T) handler) {
        auto ti = typeid(T);
        if (auto hs = ti in handlers) {
            *hs = (*hs).filter!(cb => !isDelegateMatch(cb, handler)).array;
        }
    }

    void clear(T)() {
        handlers.remove(typeid(T));
    }

    void clearAll() {
        handlers.clear();
    }
    void publish(T)(ref T event) {
        auto ti = typeid(T);
        if (auto hs = ti in handlers) {
            foreach (h; *hs) {
                h(&event);
            }
        }
    }

    void publish(T)(T event) {
        publish!T(event);
    }

    private bool isDelegateMatch(EventCallback existing, void delegate() target) {
        return cast(void*)existing.ptr == cast(void*)target.ptr && 
               cast(void*)existing.funcptr == cast(void*)target.funcptr;
    }
}