#pragma once

// raylib stuff
typedef struct Vector2 {
    float x;
    float y;
} Vector2;

typedef struct Vector3 {
    float x;
    float y;
    float z;
} Vector3;

typedef struct {
    unsigned char r;
    unsigned char g;
    unsigned char b;
    unsigned char a;
} Color;

// enums, definitions
typedef unsigned int Entity;

typedef enum LogType {
    LogInfo = 0,
    LogWarning,
    LogError
} LogType;
typedef enum ColliderType {
    ColliderBox = 0,
    ColliderSphere = 1
} ColliderType;
typedef enum PrimitiveType {
    PrimitiveBox = 0,
    PrimitiveCircle = 1,
} PrimitiveType;
typedef enum ComponentType {
    Transform = 0,
    Renderer,
    Light,
    Audio,
    Rigidbody,
    Collider,
    Primitive,
    Text
} ComponentType;

// engine-level structs
typedef struct {
    Vector3 ambient;
    float fogStart, fogEnd;
    void* sky;
} Environment;

typedef struct {
    int windowWidth, windowHeight;
    bool vsync, fullscreen;
    const char* title;
} WindowConfig;

// components
typedef struct {
    Vector3 *position;
    Vector3 *rotation;
    Vector3 *scale;
} Transform3D;

typedef struct {
    float* FOV;
    Vector3 *right;
} WorldCamera;

typedef struct {
    void* sound;
    float* minDistance;
    float* maxDistance;
    float* volume;
    float* pitch;
    bool* looped;

    bool* playing;
    bool* paused;
    bool* enablePan;
} AudioSource;

typedef struct {
    void* model;
    Vector2* tiling;
} MeshRenderer;

typedef struct {
    Vector3* color;
    float* radius;
    bool* enabled;
} LightSource;

typedef struct {
    ColliderType type;
    Vector3* size;
    bool* isTrigger;
} MeshCollider;

typedef struct {
    float* mass;
    float* friction;
    float* restitution;
    bool* kinematic;
} Rigidbody3D;

typedef struct {
    bool hit;
    Vector3 point;
    Vector3 normal;
    Entity entity;
} RaycastHit;

typedef struct {
    PrimitiveType* type;

    Vector2* size;
    Vector2* position;
    float* rotation;
    Color* color;
    void* texture;

    int* layer;
    bool* active;
} UIPrimitive;

typedef struct {
    char** text;
    void* font;

    Vector2* position;
    Color* color;
    float* size;

    int* layer;
    bool* active;
} UIText;

// functions

// scene
void* new_texture(const char* name, const char* path);
void* load_texture(const char* name);

void bind_action(const char* name, int key);
void bind_axis(const char* name, int positive, int negative);

bool get_action(const char* name, bool pressed);
float get_axis(const char* name);

// generic
WindowConfig window_config();
void log_message(LogType type, const char* message, bool logToFile);
float delta_time();
int get_fps();
Vector2 mouse_delta();
void toggle_cursor();
bool mouse_pressed(int button);
bool mouse_down(int button);
bool mouse_released(int button);
const char* entity_name(Entity e);

// object

// entities
Entity create_entity(const char* name);
Entity find_entity(const char* name);
void destroy_entity(Entity e);
bool valid(Entity e);

Entity get_current_camera();
void set_current_camera(Entity cam);

void* add_component(Entity e, ComponentType type);
void* get_component(Entity e, ComponentType type);
void remove_component(Entity e, ComponentType type);

void invoke(void (*fn)(unsigned int), Entity e, float seconds);
void cancel_invoke(void (*fn)(unsigned int), Entity e);

// components
void transform_move(Entity e, Vector3 pos);
void transform_rotate(Entity e, Vector3 rot);
void transform_scale(Entity e, Vector3 scale);

void play_one_shot(Entity e);
void stop_audio(Entity e);

void add_force(Entity e, Vector3 force);
void add_impulse(Entity e, Vector3 impulse);
void set_velocity(Entity e, Vector3 vel);
Vector3 get_velocity(Entity e);
RaycastHit raycast(Vector3 from, Vector3 to);

// scenes
void load_scene(const char* name);


/* STD */

// math
#ifndef PI
#define PI 3.14159265358979323846f
#endif
#ifndef PI2
#define PI2 (PI * 2.0f)
#endif
#ifndef DEG2RAD
#define DEG2RAD (PI / 180.0f)
#endif
#ifndef RAD2DEG
#define RAD2DEG (180.0f / PI)
#endif
float clamp(float value, float min, float max);
float lerpf(float a, float b, float t);
float smoothstep(float edge0, float edge1, float x);
float radians(float degrees);
float degrees(float radians);
float minf(float a, float b);
float maxf(float a, float b);
float absf(float x);
float signf(float x);
float floorf(float x);
float ceilf(float x);
float roundf(float x);
float sqrtf(float x);
float sinf(float x);
float cosf(float x);
float tanf(float x);
float atan2f(float y, float x);
float powf(float base, float exponent);
float expf(float x);
float logf(float x);
float fmodf(float a, float b);
float hypotf(float a, float b);
void setSeed(unsigned int seed);
float randf();
int randi(int min, int max);
float randRange(float min, float max);

Vector2 vec2add(Vector2 a, Vector2 b);
Vector2 vec2sub(Vector2 a, Vector2 b);
Vector2 vec2scale(Vector2 v, float s);
float vec2dot(Vector2 a, Vector2 b);
float vec2length(Vector2 v);
Vector2 vec2normalize(Vector2 v);
float vec2distance(Vector2 a, Vector2 b);
Vector2 vec2lerp(Vector2 a, Vector2 b, float t);

Vector3 vec3fromxyz(float x, float y, float z);
Vector3 vec3add(Vector3 a, Vector3 b);
Vector3 vec3sub(Vector3 a, Vector3 b);
Vector3 vec3scale(Vector3 v, float s);
Vector3 vec3neg(Vector3 v);
float vec3dot(Vector3 a, Vector3 b);
Vector3 vec3cross(Vector3 a, Vector3 b);
float vec3length(Vector3 v);
Vector3 vec3normalize(Vector3 v);
float vec3distance(Vector3 a, Vector3 b);
Vector3 vec3lerp(Vector3 a, Vector3 b, float t);

// filesystem
bool file_exists(const char* path);
bool dir_exists(const char* path);
const char* read_file(const char* path);
bool write_file(const char* path, const char* contents);
bool append_file(const char* path, const char* contents);
bool delete_file(const char* path);
bool create_dir(const char* path);
bool delete_dir(const char* path);
long long file_size(const char* path);
const char* list_dir(const char* path);

// time / misc
double time_now();
unsigned long long time_ms();
void sleep_ms(int ms);
int get_screen_width();
int get_screen_height();

// raylib
typedef enum {
    KEY_NULL            = 0,        // Key: NULL, used for no key pressed
    // Alphanumeric keys
    KEY_APOSTROPHE      = 39,       // Key: '
    KEY_COMMA           = 44,       // Key: ,
    KEY_MINUS           = 45,       // Key: -
    KEY_PERIOD          = 46,       // Key: .
    KEY_SLASH           = 47,       // Key: /
    KEY_ZERO            = 48,       // Key: 0
    KEY_ONE             = 49,       // Key: 1
    KEY_TWO             = 50,       // Key: 2
    KEY_THREE           = 51,       // Key: 3
    KEY_FOUR            = 52,       // Key: 4
    KEY_FIVE            = 53,       // Key: 5
    KEY_SIX             = 54,       // Key: 6
    KEY_SEVEN           = 55,       // Key: 7
    KEY_EIGHT           = 56,       // Key: 8
    KEY_NINE            = 57,       // Key: 9
    KEY_SEMICOLON       = 59,       // Key: ;
    KEY_EQUAL           = 61,       // Key: =
    KEY_A               = 65,       // Key: A | a
    KEY_B               = 66,       // Key: B | b
    KEY_C               = 67,       // Key: C | c
    KEY_D               = 68,       // Key: D | d
    KEY_E               = 69,       // Key: E | e
    KEY_F               = 70,       // Key: F | f
    KEY_G               = 71,       // Key: G | g
    KEY_H               = 72,       // Key: H | h
    KEY_I               = 73,       // Key: I | i
    KEY_J               = 74,       // Key: J | j
    KEY_K               = 75,       // Key: K | k
    KEY_L               = 76,       // Key: L | l
    KEY_M               = 77,       // Key: M | m
    KEY_N               = 78,       // Key: N | n
    KEY_O               = 79,       // Key: O | o
    KEY_P               = 80,       // Key: P | p
    KEY_Q               = 81,       // Key: Q | q
    KEY_R               = 82,       // Key: R | r
    KEY_S               = 83,       // Key: S | s
    KEY_T               = 84,       // Key: T | t
    KEY_U               = 85,       // Key: U | u
    KEY_V               = 86,       // Key: V | v
    KEY_W               = 87,       // Key: W | w
    KEY_X               = 88,       // Key: X | x
    KEY_Y               = 89,       // Key: Y | y
    KEY_Z               = 90,       // Key: Z | z
    KEY_LEFT_BRACKET    = 91,       // Key: [
    KEY_BACKSLASH       = 92,       // Key: '\'
    KEY_RIGHT_BRACKET   = 93,       // Key: ]
    KEY_GRAVE           = 96,       // Key: `
    // Function keys
    KEY_SPACE           = 32,       // Key: Space
    KEY_ESCAPE          = 256,      // Key: Esc
    KEY_ENTER           = 257,      // Key: Enter
    KEY_TAB             = 258,      // Key: Tab
    KEY_BACKSPACE       = 259,      // Key: Backspace
    KEY_INSERT          = 260,      // Key: Ins
    KEY_DELETE          = 261,      // Key: Del
    KEY_RIGHT           = 262,      // Key: Cursor right
    KEY_LEFT            = 263,      // Key: Cursor left
    KEY_DOWN            = 264,      // Key: Cursor down
    KEY_UP              = 265,      // Key: Cursor up
    KEY_PAGE_UP         = 266,      // Key: Page up
    KEY_PAGE_DOWN       = 267,      // Key: Page down
    KEY_HOME            = 268,      // Key: Home
    KEY_END             = 269,      // Key: End
    KEY_CAPS_LOCK       = 280,      // Key: Caps lock
    KEY_SCROLL_LOCK     = 281,      // Key: Scroll down
    KEY_NUM_LOCK        = 282,      // Key: Num lock
    KEY_PRINT_SCREEN    = 283,      // Key: Print screen
    KEY_PAUSE           = 284,      // Key: Pause
    KEY_F1              = 290,      // Key: F1
    KEY_F2              = 291,      // Key: F2
    KEY_F3              = 292,      // Key: F3
    KEY_F4              = 293,      // Key: F4
    KEY_F5              = 294,      // Key: F5
    KEY_F6              = 295,      // Key: F6
    KEY_F7              = 296,      // Key: F7
    KEY_F8              = 297,      // Key: F8
    KEY_F9              = 298,      // Key: F9
    KEY_F10             = 299,      // Key: F10
    KEY_F11             = 300,      // Key: F11
    KEY_F12             = 301,      // Key: F12
    KEY_LEFT_SHIFT      = 340,      // Key: Shift left
    KEY_LEFT_CONTROL    = 341,      // Key: Control left
    KEY_LEFT_ALT        = 342,      // Key: Alt left
    KEY_LEFT_SUPER      = 343,      // Key: Super left
    KEY_RIGHT_SHIFT     = 344,      // Key: Shift right
    KEY_RIGHT_CONTROL   = 345,      // Key: Control right
    KEY_RIGHT_ALT       = 346,      // Key: Alt right
    KEY_RIGHT_SUPER     = 347,      // Key: Super right
    KEY_KB_MENU         = 348,      // Key: KB menu
    // Keypad keys
    KEY_KP_0            = 320,      // Key: Keypad 0
    KEY_KP_1            = 321,      // Key: Keypad 1
    KEY_KP_2            = 322,      // Key: Keypad 2
    KEY_KP_3            = 323,      // Key: Keypad 3
    KEY_KP_4            = 324,      // Key: Keypad 4
    KEY_KP_5            = 325,      // Key: Keypad 5
    KEY_KP_6            = 326,      // Key: Keypad 6
    KEY_KP_7            = 327,      // Key: Keypad 7
    KEY_KP_8            = 328,      // Key: Keypad 8
    KEY_KP_9            = 329,      // Key: Keypad 9
    KEY_KP_DECIMAL      = 330,      // Key: Keypad .
    KEY_KP_DIVIDE       = 331,      // Key: Keypad /
    KEY_KP_MULTIPLY     = 332,      // Key: Keypad *
    KEY_KP_SUBTRACT     = 333,      // Key: Keypad -
    KEY_KP_ADD          = 334,      // Key: Keypad +
    KEY_KP_ENTER        = 335,      // Key: Keypad Enter
    KEY_KP_EQUAL        = 336,      // Key: Keypad =
    // Android key buttons
    KEY_BACK            = 4,        // Key: Android back button
    KEY_MENU            = 5,        // Key: Android menu button
    KEY_VOLUME_UP       = 24,       // Key: Android volume up button
    KEY_VOLUME_DOWN     = 25        // Key: Android volume down button
} KeyboardKey;
#define MOUSE_LEFT 0
#define MOUSE_RIGHT 1

#define LIGHTGRAY  CLITERAL(Color){ 200, 200, 200, 255 }   // Light Gray
#define GRAY       CLITERAL(Color){ 130, 130, 130, 255 }   // Gray
#define DARKGRAY   CLITERAL(Color){ 80, 80, 80, 255 }      // Dark Gray
#define YELLOW     CLITERAL(Color){ 253, 249, 0, 255 }     // Yellow
#define GOLD       CLITERAL(Color){ 255, 203, 0, 255 }     // Gold
#define ORANGE     CLITERAL(Color){ 255, 161, 0, 255 }     // Orange
#define PINK       CLITERAL(Color){ 255, 109, 194, 255 }   // Pink
#define RED        CLITERAL(Color){ 230, 41, 55, 255 }     // Red
#define MAROON     CLITERAL(Color){ 190, 33, 55, 255 }     // Maroon
#define GREEN      CLITERAL(Color){ 0, 228, 48, 255 }      // Green
#define LIME       CLITERAL(Color){ 0, 158, 47, 255 }      // Lime
#define DARKGREEN  CLITERAL(Color){ 0, 117, 44, 255 }      // Dark Green
#define SKYBLUE    CLITERAL(Color){ 102, 191, 255, 255 }   // Sky Blue
#define BLUE       CLITERAL(Color){ 0, 121, 241, 255 }     // Blue
#define DARKBLUE   CLITERAL(Color){ 0, 82, 172, 255 }      // Dark Blue
#define PURPLE     CLITERAL(Color){ 200, 122, 255, 255 }   // Purple
#define VIOLET     CLITERAL(Color){ 135, 60, 190, 255 }    // Violet
#define DARKPURPLE CLITERAL(Color){ 112, 31, 126, 255 }    // Dark Purple
#define BEIGE      CLITERAL(Color){ 211, 176, 131, 255 }   // Beige
#define BROWN      CLITERAL(Color){ 127, 106, 79, 255 }    // Brown
#define DARKBROWN  CLITERAL(Color){ 76, 63, 47, 255 }      // Dark Brown

#define WHITE      CLITERAL(Color){ 255, 255, 255, 255 }   // White
#define BLACK      CLITERAL(Color){ 0, 0, 0, 255 }         // Black
#define BLANK      CLITERAL(Color){ 0, 0, 0, 0 }           // Blank (Transparent)
#define MAGENTA    CLITERAL(Color){ 255, 0, 255, 255 }     // Magenta
#define RAYWHITE   CLITERAL(Color){ 245, 245, 245, 255 }   // My own White (raylib logo)