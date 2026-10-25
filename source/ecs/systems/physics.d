module ecs.systems.physics;

import ode;
import raylib;
import std.math : sqrt;
import std.typecons : Tuple, tuple;
import ecs.components.rigidbody;
import ecs.components.transform;
import ecs.world;
import core.log;
import ecs.ecs;

enum float GRAVITY = 20.81f;
enum float FIXED_STEP = 1.0f / 60.0f;
enum int MAX_SUBSTEPS = 10;

alias EntityPair = Tuple!(Entity, Entity);

class PhysicsSystem {
private:
    World m_world;

    dWorldID odeWorld;
    dSpaceID space;
    dJointGroupID contactGroup;

    float m_accumulator = 0;
    bool[EntityPair] m_previous;
    bool[EntityPair] m_current;

    static EntityPair makePair(Entity a, Entity b) {
        return a < b ? tuple(a, b) : tuple(b, a); }
    static Entity entityOf(dGeomID g) {
        return cast(Entity)cast(size_t) dGeomGetData(g); }
public:
    void initialize(World world) {
        m_world = world;
        dInitODE();
        odeWorld = dWorldCreate();
        space = dHashSpaceCreate(null);
        contactGroup = dJointGroupCreate(0);
        dWorldSetGravity(odeWorld, 0.0, -GRAVITY, 0.0);
    }

    void shutdown() {
        dJointGroupDestroy(contactGroup);
        dSpaceDestroy(space);
        dWorldDestroy(odeWorld);
        dCloseODE();
    }

    void onRigidbody(Entity e) {
        if (!m_world.has!Transform3D(e)) {
            Log.get.log(LogType.warning,
                "Rigidbody added to an object with no Transform3D.");
            return;
        }

        auto col = &m_world.get!Collider(e);
        auto rb  = &m_world.get!Rigidbody3D(e);
        auto tr  = &m_world.get!Transform3D(e);

        rb.body = dBodyCreate(odeWorld);
        rb.geom = createGeom(*col);
        dGeomSetBody(rb.geom, rb.body);
        dGeomSetData(rb.geom, cast(void*)cast(size_t) e);

        setBodyTransform(rb.body, *tr);
        applyMass(*rb, *col);

        if (rb.isKinematic) dBodySetKinematic(rb.body);
    }

    void onRigidDestroy(Entity e) {
        auto rb = &m_world.get!Rigidbody3D(e);
        if (rb.body) {
            dGeomDestroy(rb.geom);
            dBodyDestroy(rb.body);
            rb.body = null;
            rb.geom = null;
        }
    }

    void update(float dt) {
        foreach (item; m_world.view!(Rigidbody3D, Transform3D)()) {
            Entity e = item[0];
            auto rb = &m_world.get!Rigidbody3D(e);
            auto tr = &m_world.get!Transform3D(e);
            if (rb.isKinematic && rb.body)
                setBodyTransform(rb.body, *tr);
        }

        m_accumulator += dt;
        int steps = 0;
        m_current = null;
        while (m_accumulator >= FIXED_STEP && steps < MAX_SUBSTEPS) {
            dSpaceCollide(space, cast(void*) this, &nearCallback);
            dWorldStep(odeWorld, FIXED_STEP);
            dJointGroupEmpty(contactGroup);
            m_accumulator -= FIXED_STEP;
            steps++;
        }
        if (steps == MAX_SUBSTEPS) m_accumulator = 0;
        
        foreach (item; m_world.view!(Rigidbody3D, Transform3D)()) {
            Entity e = item[0];
            auto rb = &m_world.get!Rigidbody3D(e);
            auto tr = &m_world.get!Transform3D(e);
            if (!rb.isKinematic && rb.body) {
                fromODE(rb.body, *tr);
                tr.dirty = true;
                m_world.registry().patch!Transform3D(e, (ref Transform3D) {});
            }
        }

        foreach (p, _; m_current)
            if (p !in m_previous)
                m_world.events.trigger(OnColliderEnter(p[0], p[1]));

        foreach (p, _; m_previous)
            if (p !in m_current)
                m_world.events.trigger(OnColliderExit(p[0], p[1]));

        m_previous = m_current;
    }
    
    void addForce(Entity e, Vector3 f) {
        auto rb = &m_world.get!Rigidbody3D(e);
        if (!rb.body || rb.isKinematic) return;
        dBodyAddForce(rb.body, f.x, f.y, f.z);
    }

    void addImpulse(Entity e, Vector3 imp) {
        auto rb = &m_world.get!Rigidbody3D(e);
        if (!rb.body || rb.isKinematic) return;
        auto v = dBodyGetLinearVel(rb.body);
        double inv = 1.0 / rb.mass;
        dBodySetLinearVel(rb.body, v[0] + imp.x * inv, v[1] + imp.y * inv, v[2] + imp.z * inv);
    }

    void setVelocity(Entity e, Vector3 vel) {
        auto rb = &m_world.get!Rigidbody3D(e);
        if (!rb.body) return;
        dBodySetLinearVel(rb.body, vel.x, vel.y, vel.z);
    }

    Vector3 getVelocity(Entity e) {
        auto rb = &m_world.get!Rigidbody3D(e);
        if (!rb.body) return Vector3(0, 0, 0);
        auto v = dBodyGetLinearVel(rb.body);
        return Vector3(v[0], v[1], v[2]);
    }

    void setKinematic(Entity e, bool kinematic) {
        auto rb  = &m_world.get!Rigidbody3D(e);
        auto col = &m_world.get!Collider(e);
        if (!rb.body) return;

        rb.isKinematic = kinematic;
        if (kinematic) {
            dBodySetKinematic(rb.body);
        } else {
            dBodySetDynamic(rb.body);
            applyMass(*rb, *col);
        }
    }

    public void teleport(Entity e) {
        if (!m_world.has!Rigidbody3D(e) || !m_world.has!Transform3D(e)) return;
        auto rb = &m_world.get!Rigidbody3D(e);
        if (!rb.body) return;
        setBodyTransform(rb.body, m_world.get!Transform3D(e));
        dBodySetAngularVel(rb.body, 0, 0, 0);
    }

    RaycastHit raycast(Vector3 from, Vector3 to) {
        RaycastHit hit;

        double dx = to.x - from.x, dy = to.y - from.y, dz = to.z - from.z;
        double len = sqrt(dx*dx + dy*dy + dz*dz);
        if (len <= 0) return hit;

        RayCtx ctx;
        ctx.sys = this;
        ctx.best = double.infinity;

        dGeomID ray = dCreateRay(null, len);
        dGeomRaySet(ray, from.x, from.y, from.z, dx/len, dy/len, dz/len);
        dSpaceCollide2(ray, cast(dGeomID) space, &ctx, &rayCallback);
        dGeomDestroy(ray);

        if (ctx.found) {
            hit.hit = true;
            hit.point = ctx.point;
            hit.normal = ctx.normal;
            hit.entity = ctx.entity;
        }
        return hit;
    }
    
private:
    dGeomID createGeom(const ref Collider col) {
        final switch (col.type) {
            case ColliderType.Box:
                return dCreateBox(space, col.size.x, col.size.y, col.size.z);
            case ColliderType.Sphere:
                return dCreateSphere(space, col.size.x * 0.5);
        }
    }

    void applyMass(const ref Rigidbody3D rb, const ref Collider col) {
        if (rb.isKinematic) return;
        dMass m;
        final switch (col.type) {
            case ColliderType.Box:
                dMassSetBoxTotal(&m, rb.mass, col.size.x, col.size.y, col.size.z);
                break;
            case ColliderType.Sphere:
                dMassSetSphereTotal(&m, rb.mass, col.size.x * 0.5);
                break;
        }
        dBodySetMass(cast(dBodyID) rb.body, &m);
    }

    static void setBodyTransform(dBodyID b, const ref Transform3D t) {
        dBodySetPosition(b, t.position.x, t.position.y, t.position.z);
        double[4] q = [t.rotationQ.w, t.rotationQ.x, t.rotationQ.y, t.rotationQ.z];
        dBodySetQuaternion(b, q.ptr);
    }

    static void fromODE(dBodyID b, ref Transform3D t) {
        auto p = dBodyGetPosition(b);
        t.position = Vector3(p[0], p[1], p[2]);

        auto q = dBodyGetQuaternion(b);
        t.rotationQ = Quaternion(q[1], q[2], q[3], q[0]);

        Vector3 e = QuaternionToEuler(t.rotationQ);
        t.rotation = Vector3(e.x * RAD2DEG, e.y * RAD2DEG, e.z * RAD2DEG);
    }

    static extern(C) void nearCallback(void* data, dGeomID o1, dGeomID o2) {
        (cast(PhysicsSystem) data).onNear(o1, o2);
    }

    void onNear(dGeomID o1, dGeomID o2) {
        dBodyID b1 = null, b2 = null;
        Entity a = entityOf(o1), b = entityOf(o2);

        enum MAX_CONTACTS = 8;
        dContactGeom[MAX_CONTACTS] cg;
        int n = dCollide(o1, o2, MAX_CONTACTS, cg.ptr, cast(int) dContactGeom.sizeof);
        if (n <= 0) return;

        m_current[makePair(a, b)] = true;

        auto rbA = &m_world.get!Rigidbody3D(a);
        auto rbB = &m_world.get!Rigidbody3D(b);
        auto cA  = &m_world.get!Collider(a);
        auto cB  = &m_world.get!Collider(b);
        
        if (cA.isTrigger || cB.isTrigger) return;

        b1 = rbA.body; b2 = rbB.body;
        foreach (i; 0 .. n) {
            dContact c;
            c.surface.mode = dContactBounce;
            c.surface.mu = rbA.friction * rbB.friction;
            c.surface.bounce = rbA.restitution > rbB.restitution ? rbA.restitution : rbB.restitution;
            c.surface.bounce_vel = 0.1;
            c.geom = cg[i];

            auto j = dJointCreateContact(odeWorld, contactGroup, &c);
            dJointAttach(j, b1, b2);
        }
    }

    struct RayCtx {
        PhysicsSystem sys;
        bool found;
        double best;
        Vector3 point, normal;
        Entity entity;
    }

    static extern(C) void rayCallback(void* data, dGeomID o1, dGeomID o2) {
        auto ctx = cast(RayCtx*) data;
        dGeomID target = o2;
        dContactGeom cg;
        if (dCollide(o1, o2, 1, &cg, cast(int) dContactGeom.sizeof) <= 0) return;

        if (cg.depth < ctx.best) {
            ctx.best = cg.depth;
            ctx.found = true;
            ctx.point = Vector3(cg.pos[0], cg.pos[1], cg.pos[2]);
            ctx.normal = Vector3(cg.normal[0], cg.normal[1], cg.normal[2]);
            ctx.entity = entityOf(target);
        }
    }
}