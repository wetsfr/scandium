# Scandium

Scandium is a lightweight 3D game engine written in D, with C scripting powered by libtcc.

---

## Overview

Scandium is built on the Entity-Component-System (ECS) pattern. Functionality is split into independent systems that operate on plain-data components stored in a central registry.

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
* Documentation

## Credits

* **Ramon Santamaria (raysan5)**: author of Raylib, used for rendering.
* **Michele Caini (skypjack)**: author of EnTT, which inspired the ECS design.
* **Russell Smith**: author of the Open Dynamics Engine (ODE), used for physics.
* **Fabrice Bellard**: author of the Tiny C Compiler, used for scripting.


## Building

Scandium is built with [dub](https://dub.pm) and the LDC compiler. It links against three native libraries (Raylib, ODE and libtcc), which must be available to the linker before building.

### Requirements

* **LDC** 1.35 or newer (ldc2) and **dub**
* **Raylib** 6.0 (native library)
* **ODE, built in double precision** (ode_double)
* **libtcc**

The linker searches the project root for libraries ("-L."), so the simplest setup is to place the library files next to **dub.json**

---

### Windows

1. Install LDC and dub (from the [LDC releases](https://github.com/ldc-developers/ldc/releases))
2. Obtain the 64-bit libraries and place them in the project root:
   * **raylib.lib** and **raylib.dll** (or a static **raylib.lib**)
   * **ode_double.lib** and **ode_double.dll**
   * **tcc.lib** (or **libtcc.lib**) and **libtcc.dll**, built from the [TinyCC sources](https://repo.or.cz/tinycc.git) with **win32/build-tcc.bat**
3. Build from PowerShell:

```
dub build --compiler=ldc2 --build=release
```

4. Copy the **.dll** files and the **asset/** directory next to the produced executable before running it.

---

### Linux

1. Install the toolchain and libraries.
2. Build and install the native libraries, if the distribution does not provide the required versions:
```bash
# Raylib
git clone --depth 1 --branch 6.0 https://github.com/raysan5/raylib.git
cmake -S raylib -B raylib/build -DBUILD_SHARED_LIBS=ON
cmake --build raylib/build && sudo cmake --install raylib/build

# ODE (double precision)
git clone https://bitbucket.org/odedevs/ode.git
cmake -S ode -B ode/build -DBUILD_SHARED_LIBS=ON -DODE_DOUBLE_PRECISION=ON
cmake --build ode/build && sudo cmake --install ode/build

# TinyCC
git clone https://repo.or.cz/tinycc.git
cd tinycc && ./configure && make && sudo make install && cd ..
```

3. Make sure the linker names match **dub.json** (**libode_double.so**, **libtcc.so**). If the library installs under a different name, create a symlink in the project root:

```
ln -s /usr/local/lib/libode.so libode_double.so
```

4. Build:

```
dub build --compiler=ldc2 --build=release
```

The executable is linked with **-rpath=$ORIGIN**, so shared libraries placed beside it are found at runtime without setting **LD_LIBRARY_PATH**.

---

### Running

Run the executable from a directory that contains the **asset/** folder (scenes, scripts, textures, models, sounds and fonts). Paths in scene files and scripts are relative to the working directory.