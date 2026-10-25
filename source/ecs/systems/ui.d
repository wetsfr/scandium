module ecs.systems.ui;
import raylib;
import ecs.components.ui;
import ecs.world;
import std.algorithm : sort;
import std.string : toStringz;

enum ItemType {
    primitive = 0,
    text = 1,
}

struct UIItem {
    int layer;
    ItemType type;

    Vector2 position;
    Vector2 size;
    Color color;
    float rotation = 0.0f;

    PrimitiveType primitiveType;
    Texture2D* texture;

    Font* font;
    string text;
    float fontSize;    
}

final class UI {
    private World world;
    private UIItem[] items;

    void initialize(World world) {
        this.world = world;
    }

    void update() {
        items = [];
        
        foreach (entity, primitive; world.view!(UIPrimitive)()) {
            items ~= UIItem(
                primitive.layer,
                ItemType.primitive,
                primitive.position,
                primitive.size,
                primitive.color,
                primitive.rotation,
                primitive.type,
                primitive.texture,
                null,
                "",
                0.0f
            );
        }

        foreach (entity, text; world.view!(UIText)()) {
            items ~= UIItem(
                text.layer,
                ItemType.text,
                text.position,
                Vector2(0.0f, 0.0f),
                text.color,
                0.0f,
                PrimitiveType.rect,
                null,
                text.font,
                text.text,
                text.size
            );
        }

        sort!((a,b) {
            if (a.layer != b.layer)
                return a.layer < b.layer;
            if (a.texture != b.texture)
                return a.texture < b.texture;
            if (a.font != b.font)
                return a.font < b.font;

            return a.type < b.type;
        })(items);
    }

    void draw() nothrow {
        foreach (item; items) {
            if (item.type == ItemType.primitive) {
                if (item.texture != null) 
                    DrawTextureEx(*item.texture, item.position, item.rotation, item.size.x, item.color);
                else {
                    if (item.size.y == 0.0f) // circle 
                        DrawCircleV(item.position, item.size.x, item.color);
                    else
                        DrawRectangleV(item.position, item.size, item.color);
                }
            } else {
                DrawTextEx(
                    *item.font, toStringz(item.text),
                    item.position, item.fontSize, 1.0f, item.color
                );
            }
        }
    }
}