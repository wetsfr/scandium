module ecs.components.rigidbody;
import ode;
import raylib;
import ecs.ecs;

enum ColliderType {
    Box = 0,
    Sphere
}

struct Collider {
    ColliderType type = ColliderType.Box;
    Vector3 size = Vector3(1.0f, 1.0f, 1.0f);

    bool isTrigger = false;
}

struct Rigidbody3D {
    float mass = 1.0f;
    float friction = 1.0f;
    float restitution = 0.0f;

    bool isKinematic = false;
    
    dBodyID body;
    dGeomID geom;
}

struct OnColliderEnter { Entity a,b; }
struct OnColliderExit { Entity a,b; }

struct RaycastHit {
    bool hit = false;
    Vector3 point = Vector3(0, 0, 0);
    Vector3 normal = Vector3(0, 0, 0);
    Entity entity = nullEntity;
}