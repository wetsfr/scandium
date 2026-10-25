// ecs.d
// by wetsfr -w-
// mental-illness.cc
module ecs.ecs;

import std.traits;
import std.meta;
import std.algorithm;
import std.array;
import std.range;
import std.typecons : Tuple, tuple;

alias Entity = uint;
enum Entity nullEntity = Entity.max;

private enum uint indexBits = 20;
private enum uint indexMask = (1 << indexBits) - 1;

private uint entityIndex(Entity e) pure nothrow @nogc { return e & indexMask; }
private uint entityVersion(Entity e) pure nothrow @nogc { return e >> indexBits; }
private Entity makeEntity(uint idx, uint ver) pure nothrow @nogc {
    return (ver << indexBits) | (idx & indexMask);
}

final class Signal(Args...) {
    alias Slot = void delegate(Args);
    private Slot[] slots;
    Signal connect(Slot slot) {
        slots ~= slot;
        return this;
    }

    void disconnect(Slot slot) {
        slots = slots.filter!(s => s !is slot).array;
    }
    void disconnectAll() {
        slots.length = 0;
    }
    void emit(Args args) {
        foreach (s; slots) s(args);
    }
}

private interface IPool {
    bool contains(Entity e);
    void removeUntyped(Entity e);
}

private final class SparseSet(T) : IPool {
    uint[] sparse;
    Entity[] dense;
    T[] instances;

    Signal!(Registry, Entity) onConstruct;
    Signal!(Registry, Entity) onUpdate;
    Signal!(Registry, Entity) onDestroy;

    Registry owner;

    this(Registry owner) {
        this.owner = owner;
        onConstruct = new Signal!(Registry, Entity)();
        onUpdate = new Signal!(Registry, Entity)();
        onDestroy = new Signal!(Registry, Entity)();
    }

    bool contains(Entity e) {
        auto idx = entityIndex(e);
        return idx < sparse.length && sparse[idx] < dense.length
            && dense[sparse[idx]] == e;
    }
    ref T get(Entity e) { return instances[sparse[entityIndex(e)]]; }
    T* tryGet(Entity e) {
        return contains(e) ? &instances[sparse[entityIndex(e)]] : null;
    }
    ref T emplace(Entity e, T value) {
        auto idx = entityIndex(e);
        if (idx >= sparse.length)
            sparse.length = idx + 1;
        sparse[idx] = cast(uint) dense.length;
        dense ~= e;
        instances ~= value;
        onConstruct.emit(owner, e);
        return instances[$ - 1];
    }
     
    ref T patch(Entity e, void delegate(ref T) mutator) {
        auto ptr = &instances[sparse[entityIndex(e)]];
        mutator(*ptr);
        onUpdate.emit(owner, e);
        return *ptr;
    }

    void remove(Entity e) {
        onDestroy.emit(owner, e);
        auto idx = entityIndex(e);
        auto denseIdx = sparse[idx];
        auto lastIdx  = dense.length - 1;
        auto lastEntity = dense[lastIdx];
        dense[denseIdx] = lastEntity;
        instances[denseIdx] = instances[lastIdx];
        sparse[entityIndex(lastEntity)] = denseIdx;
        dense.length -= 1;
        instances.length -= 1;
    }

    void removeUntyped(Entity e) { remove(e); }
    size_t length() const { return dense.length; }
}

final class Registry
{
    private Entity[] entities;
    private uint[] freeList;
    private void*[TypeInfo] pools;
    private IPool[] allPools;
    private SparseSet!T poolFor(T)() {
        auto ti = typeid(T);
        if (auto p = ti in pools)
            return cast(SparseSet!T) *p;

        auto pool = new SparseSet!T(this);
        pools[ti] = cast(void*) pool;
        allPools ~= pool;
        return pool;
    }

    Entity create() {
        if (freeList.length > 0) {
            auto idx = freeList[$ - 1];
            freeList.length -= 1;
            auto ver = entityVersion(entities[idx]);
            entities[idx] = makeEntity(idx, ver);
            return entities[idx];
        }
        auto idx = cast(uint) entities.length;
        auto e = makeEntity(idx, 0);
        entities ~= e;
        return e;
    }
    void destroy(Entity e) {
        foreach (pool; allPools)
            if (pool.contains(e))
                pool.removeUntyped(e);
        auto idx = entityIndex(e);
        auto ver = entityVersion(e) + 1;
        entities[idx] = makeEntity(idx, ver);
        freeList ~= idx;
    }

    bool valid(Entity e) const {
        auto idx = entityIndex(e);
        return idx < entities.length && entities[idx] == e;
    }
    ref T emplace(T, Args...)(Entity e, Args args) {
        static if (Args.length == 1 && is(Args[0] == T))
            return poolFor!T().emplace(e, args[0]);
        else
            return poolFor!T().emplace(e, T(args));
    }
    ref T getOrEmplace(T)(Entity e, lazy T fallback = T.init) {
        auto pool = poolFor!T();
        if (!pool.contains(e))
            pool.emplace(e, fallback);
        return pool.get(e);
    }

    ref T get(T)(Entity e) { return poolFor!T().get(e); }
    T* tryGet(T)(Entity e) { return poolFor!T().tryGet(e); }
    bool has(T)(Entity e) { return poolFor!T().contains(e); }
    bool has(Types...)(Entity e) if (Types.length > 1) {
        static foreach (T; Types)
            if (!poolFor!T().contains(e)) return false;
        return true;
    }

    void remove(T)(Entity e) { poolFor!T().remove(e); }
    ref T patch(T)(Entity e, void delegate(ref T) mutator) {
        return poolFor!T().patch(e, mutator);
    }

    size_t size(T)() { return poolFor!T().length; }
    Signal!(Registry, Entity) onConstruct(T)() { return poolFor!T().onConstruct; }
    Signal!(Registry, Entity) onUpdate(T)() { return poolFor!T().onUpdate; }
    Signal!(Registry, Entity) onDestroy(T)() { return poolFor!T().onDestroy; }
    
    auto view(T)() {
        auto pool = poolFor!T();
        return zip(pool.dense, pool.instances);
    }
    auto view(Types...)() if (Types.length > 1) {
        alias First = Types[0];
        auto basePool = poolFor!First();
        return basePool.dense
            .filter!(e => allHave!Types(e))
            .map!(e => tuple(e, getAll!Types(e)));
    }
    private bool allHave(Types...)(Entity e) {
        static foreach (T; Types)
            if (!poolFor!T().contains(e)) return false;
        return true;
    }
    private auto getAll(Types...)(Entity e) {
        Tuple!(Types) result;
        static foreach (i, T; Types) {
            result[i] = get!T(e);
        }
        return result;
    }
}

private template ApplyGet(T) {
    static ref T ApplyGet(Registry r, Entity e) { return r.get!T(e); }
}

final class EventBus {
    private void delegate(const(void)*)[][TypeInfo] handlers;

    void connect(T)(void delegate(ref const T) h) {
        handlers[typeid(T)] ~= delegate(const(void)* p) {
            h(*cast(const(T)*) p);
        };
    }

    void trigger(T)(T ev) {
        if (auto hs = typeid(T) in handlers)
            foreach (h; *hs)
                h(&ev);
    }
}