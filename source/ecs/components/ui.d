module ecs.components.ui;
import raylib;

enum PrimitiveType {
    rect = 0,
    circle = 1,
}

struct UIPrimitive {
    PrimitiveType type = PrimitiveType.rect;

    Vector2 size = Vector2(1.0f, 1.0f);
    Vector2 position = Vector2(1.0f, 1.0f);
    float rotation = 0.0f;

    Color color = Color(0,0,0); 
    Texture2D* texture = null;

    int layer = 0;
    bool active = true;
}

struct UIText {
    string text;
    Font* font = null;
    
    Vector2 position = Vector2(0.0f, 0.0f);
    Color color = Color(0,0,0);
    float size = 1.0f;

    int layer = 0;
    bool active = true;
}