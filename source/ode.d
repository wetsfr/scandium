// ode.d (ODE bindings)
// by wetsfr -w-
// mental-illness.cc
module ode;

extern(C):

struct dxWorld;
struct dxSpace;
struct dxBody;
struct dxGeom;
struct dxJointGroup;

alias dWorldID = dxWorld*;
alias dSpaceID = dxSpace*;
alias dBodyID = dxBody*;
alias dGeomID = dxGeom*;
alias dJointGroupID = dxJointGroup*;

dWorldID dWorldCreate();
void dWorldDestroy(dWorldID);
void dWorldSetGravity(dWorldID, double x, double y, double z);
void dWorldStep(dWorldID, double stepsize);

dSpaceID dHashSpaceCreate(dSpaceID parent);
void dSpaceDestroy(dSpaceID);

dBodyID dBodyCreate(dWorldID);
void dBodyDestroy(dBodyID);
void dBodySetPosition(dBodyID, double x, double y, double z);
const(double)* dBodyGetPosition(dBodyID);
const(double)* dBodyGetQuaternion(dBodyID);
void dBodySetKinematic(dBodyID);
void dBodySetDynamic(dBodyID);

dGeomID dCreateBox(dSpaceID, double lx, double ly, double lz);
dGeomID dCreateSphere(dSpaceID, double radius);
void dGeomSetBody(dGeomID, dBodyID);

void dBodyAddForce(dBodyID, double fx, double fy, double fz);
void dBodySetLinearVel(dBodyID, double x, double y, double z);
const(double)* dBodyGetLinearVel(dBodyID);

alias dNearCallback = extern(C) void function(void* data, dGeomID o1, dGeomID o2);
void dSpaceCollide(dSpaceID, void* data, dNearCallback callback);

void dInitODE();
void dCloseODE();

struct dMass { double mass; double[4] c; double[12] I; }
void dMassSetBoxTotal(dMass*, double total, double lx, double ly, double lz);
void dMassSetSphereTotal(dMass*, double total, double radius);
void dBodySetMass(dBodyID, const(dMass)*);

void dBodySetQuaternion(dBodyID, const(double)* q);
void dBodySetLinearVel(dBodyID, double x, double y, double z);

void dGeomSetData(dGeomID, void*);
void* dGeomGetData(dGeomID);
void dGeomDestroy(dGeomID);
void dGeomSetPosition(dGeomID, double x, double y, double z);

void dSpaceCollide2(dGeomID, dGeomID, void* data, dNearCallback);

struct dContactGeom {
    double[4] pos;
    double[4] normal;
    double depth;
    dGeomID g1, g2;
    int side1, side2;
}
int dCollide(dGeomID, dGeomID, int flags, dContactGeom*, int skip);

struct dSurfaceParameters {
    int mode;
    double mu, mu2, rho, rho2, rhoN, bounce, bounce_vel,
           soft_erp, soft_cfm, motion1, motion2, motionN, slip1, slip2;
}
struct dContact {
    dSurfaceParameters surface;
    dContactGeom geom;
    double[4] fdir1;
}
enum int dContactBounce = 0x004;

alias dJointID = void*;
dJointGroupID dJointGroupCreate(int);
void dJointGroupDestroy(dJointGroupID);
void dJointGroupEmpty(dJointGroupID);
dJointID dJointCreateContact(dWorldID, dJointGroupID, const(dContact)*);
void dJointAttach(dJointID, dBodyID, dBodyID);

dGeomID dCreateRay(dSpaceID, double length);
void dGeomRaySet(dGeomID, double px, double py, double pz, double dx, double dy, double dz);
void dBodySetAngularVel(dBodyID, double x, double y, double z);