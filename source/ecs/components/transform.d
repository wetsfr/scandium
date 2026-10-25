module ecs.components.transform;
import ecs.ecs;
import raylib;

struct Transform3D {
    Vector3 position = {0.0f, 0.0f, 0.0f};
    Vector3 rotation = {0.0f, 0.0f, 0.0f};
    Vector3 scale = {0.0f, 0.0f, 0.0f};
    Matrix mat;

    Quaternion rotationQ = {0.0f, 0.0f, 0.0f, 1.0f};

    bool dirty = true;
}

final class TransformAPI {
    private Registry reg;
    this(Registry r) { reg = r; }

    void translate(Entity e, Vector3 pos) {
        if (!reg.tryGet!Transform3D(e)) return;

        reg.patch!Transform3D(e, (ref Transform3D t) {
            t.position.x += pos.x;
            t.position.y += pos.y;
            t.position.z += pos.z;
            t.dirty = true;
        });
    }

    void rotate(Entity e, Vector3 rot) {
        if (!reg.tryGet!Transform3D(e)) return;

        reg.patch!Transform3D(e, (ref Transform3D t) {
            t.rotation.x += rot.x;
            t.rotation.y += rot.y;
            t.rotation.z += rot.z;
            Quaternion dq = QuaternionFromEuler(rot.x * DEG2RAD, rot.y * DEG2RAD, rot.z * DEG2RAD);
            t.rotationQ = QuaternionNormalize(QuaternionMultiply(t.rotationQ, dq));
            t.dirty = true;
        });
    }

    void scale(Entity e, Vector3 scale) {
        if (!reg.tryGet!Transform3D(e)) return;

        reg.patch!Transform3D(e, (ref Transform3D t) {
            t.scale.x += scale.x;
            t.scale.y += scale.y;
            t.scale.z += scale.z;
            t.dirty = true;
        });
    }    

    void buildMatrix(Entity e) {
        auto ref t = reg.get!Transform3D(e);
        if (!t.dirty) return;

        Matrix local = MatrixMultiply(
            MatrixMultiply(MatrixScale(t.scale.x, t.scale.y, t.scale.z),
                        QuaternionToMatrix(t.rotationQ)),
            MatrixTranslate(t.position.x, t.position.y, t.position.z)
        );

        t.mat = local;
        t.dirty = false;
    }
}