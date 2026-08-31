# Controller art

Vector source for the on-screen controller's textures. These are the design
reference for the gradients and shapes built at runtime in
`swift/Sources/Nestopia/NestopiaControllerArt.swift` — each SVG lists the
Swift function that mirrors it.

They live outside `swift/Sources/Nestopia/` on purpose: that directory is the
`Nestopia` SwiftPM target's `path`, and this package intentionally has no
Xcode asset-catalog (`.xcassets`) dependency, so it keeps building with a
plain `swift build`/`swift test` — without requiring `actool`/Xcode to be
installed. Runtime rendering therefore uses native SwiftUI `Shape`s and
gradients (resolution-independent, like the SVGs) instead of loading these
files as image assets.

If a future consumer wants literal image assets instead of the native
drawing code (e.g. for a design tool, a style guide, or an Android skin),
import these into an asset catalog or convert them directly — the visual
parameters (colors, gradient stops, corner radii) are kept in sync with
`NestopiaControllerArt.swift` by hand.

- `body-panel.svg` — brushed outer controller shell → `bodyPanelGradient(color:opacity:)`
- `dpad-plate.svg` — recessed four-armed cross plate → `DPadCrossShape`, `dPadGradient(color:opacity:)`
- `action-button.svg` — glossy domed A/B cap → `actionCapGradient(color:opacity:diameter:)`
- `utility-capsule.svg` — inset-groove SELECT/START pill → `utilityCapsuleGradient(color:opacity:)`
