# aestesis_alib

[![Latest Version](https://img.shields.io/badge/version-1.0.5-blue.svg?style=flat)](https://github.com/aestesis/libtess/releases)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg?style=flat)](https://www.apache.org/licenses/LICENSE-2.0)
[![Swift Version](https://img.shields.io/badge/swift-6.2-orange.svg?style=flat)](https://docs.swift.org/swift-book/)
[![Platform](https://img.shields.io/badge/platform-macOS%2013%2B%20%7C%20iOS%2017%2B-336699.svg?style=flat)](https://developer.apple.com/)
[![Language](https://img.shields.io/badge/language-Swift-purple.svg?style=flat)](https://www.swift.org/)
[![SwiftPM](https://img.shields.io/badge/SwiftPM-compatible-46cc92.svg?style=flat&logo=swiftpackageindex)](https://.swift.org/package-manager/)

A comprehensive **Swift 3D graphics rendering engine** built on **Metal**, providing a complete scene graph, mesh generation, lighting, and UI framework for macOS and iOS.

---

## 🎯 Features

### 3D Rendering Engine
- **Metal-based GPU acceleration** for high-performance rendering
- **Scene graph architecture** with Node3D system
- **Lighting support**: Directional and Point lights (1-4 simultaneous)
- **Materials & Textures**: Full texture mapping and blending
- **Depth buffering** with configurable stencil states
- **Reflections**: Mirror/primitive reflection support
- **Particle systems** for effects
- **Height maps** for terrain rendering
- **Object instances** for performance optimization

### Core Math & Tools
- **Matrix4** transformations with view/projection matrix support
- **Vector** SIMD-optimized vectors
- **Color** system with blending modes
- **Texture2D/3D** management
- **Geometry primitives**: Box, Sphere, Cylinder, Land
- **Bounding volume detection**: Boxes, spheres

### UI Framework
- **Instance UI model**
- **Components**: StackView, ButtonView, ImageView, TextView, Touch handling
- **Layout system** with constraints and sizing

### Utilities
- **JSON** serialization/deserialization
- **Touch/SIG**nal handling
- **Concurrency**: Future, Stream
- **Debug** utilities
- **WebSocket** networking

---

## 🏗️ Architecture

```
aestesis_alib/
├── Sources/aestesis_alib/
│   ├── 3D/              # 3D rendering engine
│   ├── AEXML/           # XML layout configuration
│   ├── Foundation/      # Core types & utilities
│   ├── UI/              # UI components
│   ├── Internals/       # Internal implementations
│   ├── iOS/             # iOS-specific code
│   ├── OSX/             # macOS-specific code
│   └── Services/        # Service layer
├── Tests/
└── Package.swift
```

---

## 🔧 Prerequisites

- **Swift 6.2+**
- **Xcode 26+**
- **macOS 26.0+ / iOS 26+**
- **Metal-capable GPU**
- **Development tools**: `swift build`, `swift package update`

---

## 📖 Usage

### Creating a Scene

```swift
import aestesis_alib

// Create renderer view
let view = RendererView(superview: superview, layout: layout)

// Create camera
let camera = Camera3D()
view.camera = camera

// Create world and add objects
let world = Node3D()
view.world = world

// Add a box mesh
let box = Box(origin: Vec3.zero, size: Vec3(2, 2, 2))
world.add(box)

// Render
view.render()
```

### Adding Lights

```swift
// Directional light
let light = DirectionalLight(direction: Vec3(x: 0, y: -1, z: 1), color: Color.white)
world.add(light)

// Point light
let pointLight = PointLight(position: Vec3(x: 1, y: 2, z: 3), intensity: 2.0)
world.add(pointLight)
```
---

## 🎨 Rendering Pipeline

```
┌─────────────────────────────────────────────────────────────┐
│                         Scene Graph                         │
├─────────────────────────────────────────────────────────────┤
│  Renderer                                                   │
│    ├─ Camera (view matrix)                                  │
│    ├─ World (scene nodes)                                   │
│    ├─ Lighting (directional/point)                          │
│    ├─ Materials & Textures                                  │
│    └─ Depth Testing                                         │
└─────────────────────────────────────────────────────────────┘
```

---

## 🚀 Performance

- **Metal GPU acceleration** with compute shaders
- **Object instances** for draw call reduction
- **Vertex caching** and batch rendering

---

## 📜 License

Apache License, Version 2.0

See [LICENSE](LICENSE) for details.

---

**Made with ❤️ by the aestesis team**
