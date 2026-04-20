# Changelog

All notable changes to this project will be documented in this file.

Format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

---

## [1.0.5] - 2025-04-20

### Initial Release

### 🎨 Added

#### 3D Rendering Engine
- Metal-based GPU rendering with depth buffering
- Scene graph architecture with Node3D system
- Directional and Point light support (1-4 simultaneous)
- Materials and texture mapping
- Mirror/reflection primitives
- Particle system support
- Height map rendering
- Object instance rendering for performance

#### Core Math & Utility Libraries
- Matrix4 transformations with view/projection matrix support
- SIMD-optimized Vector types
- Color system with blending modes
- Texture2D/Texture3D management
- Geometry primitives: Box, Sphere, Cylinder, Land
- Bounding volume detection (box and sphere)

#### UI Framework
- Declarative UI model (SwiftUI-inspired)
- XML-based layout configuration (AEXML)
- UI Components: StackView, ShutterView, RotationView
- ButtonView, ImageView, TextView
- Touch event handling
- Layout system with constraints

#### Foundation Utilities
- Complete JSON serialization/deserialization
- Touch and Signal handling
- Concurrency primitives: Future, Stream, Cloud services
- Debug utilities
- WebSocket networking
- Device abstraction layer

#### Mesh Generation
- Box mesh generation with culling
- Sphere mesh with configurable factors
- Cylinder mesh support
- Land (plane/terrain) generation
- Bounding box and sphere computation

### 🔧 Configuration

#### Package Configuration
- Swift 6.2+ compatibility
- macOS 26+ / iOS 26+ platform support
- Dependencies: libtess v1.0.5+

### 📦 Package Products

- `aestesis_alib` - Main rendering framework library

---

## Version 1.0.5

### Highlights
- **Metal Graphics Rendering** - Full GPU acceleration for 3D rendering
- **Scene Graph** - Hierarchical node-based rendering system
- **Lighting Engine** - Multiple light sources with material support
- **Complete Math Library** - Matrix, Vector, Color, Geometry primitives
- **UI Framework** - Declarative UI with Swift syntax
- **Performance Optimization** - Object instances, Z-sorting pipeline

---

## [1.0.0] - TBD (Next Release)

### Planned Features

#### Rendering Enhancements
- [ ] Mouse/Touch raycasting
- [ ] Normal mapping implementation
- [ ] Bump mapping support
- [ ] Advanced shader effects
- [ ] Z-sorting optimization
- [ ] Shadow mapping
- [ ] Post-processing effects

#### UI Improvements
- [ ] Animation system
- [ ] Gesture recognition
- [ ] Advanced layouts

#### Concurrency
- [ ] Task-based rendering
- [ ] Pipeline parallelism

#### Platform Support
- [ ] tvOS support
- [ ] Catalyst support

#### Documentation
- [ ] API reference documentation
- [ ] Tutorials and examples
- [ ] Migration guides

---

## Versioning Policy

We use [Semantic Versioning](https://semver.org/):

- **MAJOR** version: Breaking changes
- **MINOR** version: New functionality, backward compatible
- **PATCH** version: Bug fixes, backward compatible

### Release Branching
- Release branches are created from `main`
- Each release creates a git tag
- Changelog maintained at the top level

---

## Notes

- Version format follows semantic versioning (MAJOR.MINOR.PATCH)
- Initial release: 1.0.5
- All changes documented in this changelog
- See [Releases](../../releases) for release details

---

**Made with ❤️ by the aestesis team**
