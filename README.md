# Scandium

Scandium is a lightweight 3D game engine written in D, with C scripting powered by libtcc.

---

## Overview

Scandium is built on the Entity-Component-System (ECS) pattern and has a modular structure. Its core functionality is provided by built-in systems and components, and custom ones can be integrated without modifying the engine core.

## Features

### Systems and components

* **Scripting**: gameplay logic is written in C and compiled at runtime with the Tiny C Compiler. Scripts can use timers (invoke), raycasting, physics and input.
* **Audio**: positional audio sources.
* **Rendering**: mesh renderers, light sources and scene environment (ambient light, fog, skybox).
* **Physics**: rigid bodies and colliders, including triggers and collision events.
* **UI**: text and primitives with texture support. The UI layer is intentionally minimal, so most interface logic is left to the developer.
* **Core**: cameras, transforms and an event system.

### Development tools

* Input system based on actions and axes.
* Asset manager with support for textures, sounds, models, fonts and shaders.
* Scene loading from JSON, with comment support.
* Configuration loading from .ini files.
* Resources such as shaders can be embedded into the executable at build time.

## ToDo

* Particle system
* Editor
* Animations
* Parent/child hierarchy for transforms
* Distribution (.pak file with all of the game resources)
* Events

## Credits

* **Ramon Santamaria (raysan5)**: author of Raylib, used for rendering.
* **Michele Caini (skypjack)**: author of EnTT, which inspired the ECS design.
* **Russell Smith**: author of the Open Dynamics Engine (ODE), used for physics.
* **Fabrice Bellard**: author of the Tiny C Compiler, used for scripting.