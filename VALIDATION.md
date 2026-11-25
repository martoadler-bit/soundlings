# Soundlings — current validation

Latest changes: collision-free overhead flight for sustained roles, audible filter/octave arpeggio gates with matching visual state, continuous random routes with fewer portals; one shared portal fade envelope for live first person and exported video; common modal/scale constraint across all pitched roles, chords and transpose gates; shared editable piece catalogue, direct world builder with placement/drag preview/undo, legacy scenery migration, wide first-person camera with smoothing, eased portal fades, instrument surfaces and timbres, five random architectures, full-screen playback and MP4 export with audio. Same project, bundle identifier and application version.

## Verified

- All production Swift files pass iOS type checking using Xcode's iOS Simulator SDK, arm64, deployment target iOS 17. This includes SwiftUI panels, the SceneKit viewport, camera controls and the portal transition overlay.
- **89,155 model/audio checks:** deterministic random generation, serialization/migration, fractional scheduling, sustained sounds, waveform safety, stereo WAV and distinct harp/wind/wood waveforms without changing event times. Includes every generated pitched note staying in its common mode, all 12 tonics and all four modes across register bounds/transpositions, pedal tonic preservation and explicit chromatic opt-out persistence.
- **44,835 temporal movement checks:** 60 Hz simulation through two complete loops in both presets and a generated spiral, bounded ordinary motion, continued walking progress, collider clearance, loop seams and stable world framing. Optimized CPU scene update measured approximately 0.072 ms median / 0.132 ms p95 on this Mac; this excludes GPU/SwiftUI and is not an iPhone frame-rate claim.
- **1,233 scene/camera checks:** real SceneKit hierarchy, geometry bounds, clipping planes, native orthographic camera and collision checks.
- **287 feature checks:** empty world validity and JSON round trip; adding/extending the first platform; clearing the scene; selecting every avatar for perspective first person with a 92° horizontal field of view; hiding only the selected avatar from its eye camera; restoring overview/follow; a complete continuous jump over a waiting body; cooldown; a low ceiling selecting a reverse maneuver instead.
- **14,663 builder model/scene checks:** reconstruct 200 generated worlds solely through manual placement and obtain identical serialized worlds; every structure kind is in the palette; legacy scaffolding becomes stored pieces; deleted scenery stays deleted after JSON reload; scenery-only canvases; precise coordinates; selectable roots; stable builder framing and placement guides.
- **29 builder/controller checks:** production Game and BuilderGame code with only platform audio/video services mocked; placement, selection, undo/redo, exact fractional moves, rotation, duplication, deletion, drag preview, atomic one-step drag undo, cancellation, world export/import, character enable/disable/undo persistence, camera fallback when a followed voice is disabled, all voices off and render-busy guards. This does not emulate touch delivery or render SwiftUI.
- **697 transition checks:** one monotonic fade to black and one reveal at 30/60/120 Hz; close portal chains stay covered; pause freezes the envelope; production scene tests with short and long gates verify the fade follows onset-to-onset travel time, relocation is fully covered and arrival never creates a second blackout. Viewport and video export consume the same shade value.
- **6,688 flight/route checks:** full swept routes climb over architecture with continuous bounded speed, production hovering/flying bodies avoid world geometry and one another, hovering also clears thin orbital rings, floating roles never enter portal fades, and 200 generated worlds have at most one physical portal link each (83 links total). Traversing multiple connected stations, including in reverse, does not create a false portal.
- **18 icon slots:** all referenced PNGs exist, have the required pixel dimensions and use opaque RGB. Includes iPhone, iPad and 1024px marketing artwork. Asset catalog is included in the existing project and AppIcon is selected in build settings.

## Export validation boundary

The new video exporter passes iOS source type checking. It renders an independent SceneKit scene at 60 Hz, writes 720 × 1280 H.264 frames at 30 fps, then combines the video with the production stereo loop in MP4. Presentation timestamps derive from the same tempo and 48 kHz sample count; the composition is trimmed to the exact audio duration. Progress, cancellation, cleanup and the native sharing sheet are implemented.

**No MP4 has been successfully rendered or played in this environment**, because GPU rendering is unavailable. Encoding, orientation, sharing, cancellation and audio/video alignment must be confirmed on an iPhone/iPad. The exporter reports an error when Metal is unavailable. Source type checking does not establish end-to-end export correctness.

## Build limitation

The most recent complete builds stop in Apple's asset-catalog compiler: `No available simulator runtimes for platform iphonesimulator`, accompanied by CoreSimulatorService connection errors. This occurs for both simulator and device SDK attempts in this execution environment. The icon is integrated and its inputs are validated, but its packaged output and a complete current app bundle are **not confirmed** here. Earlier builds before adding the asset catalog succeeded. Current Swift sources independently pass iOS type checking.

No successful current iOS launch, screenshot, touch interaction, GPU rendering or acoustic playback is claimed. Run from Xcode on the user's machine to confirm packaging, subjective smoothness, camera comfort, touch controls and final icon appearance.

## Behavior and limits

- Characters commit to a checked jump or retreat trajectory; the partner waits, and a cooldown prevents immediately repeating the encounter. A blocked maneuver can wait for a third character to clear the path. These are kinematic actions, not full rigid-body physics.
- Navigation retains a chosen correction briefly rather than changing sides every frame. Feet, gaze and body lift follow actual travel. Small platform-height changes are treated as walkable steps rather than walls.
- The musical event timeline remains independent of collision actions. Pad lights show the scheduled trigger even while a character yields or takes a detour.
- First-person camera uses a stable body anchor, omits its own avatar from camera visibility and fades during portal relocation. Its composition and comfort need device evaluation.
- Static architecture can still overlap when edited freely. Conservative collision volumes are not exact triangle-mesh physics; crowded imported worlds and narrow routes need continued play testing.

## Repeat tests from this directory

```sh
bash Tests/run.sh
```

## Manual checks on iPhone/iPad

Compare both presets and Random; observe encounters near open paths and low ceilings; follow each enabled character using both arrows; enter/leave first person; look around and cross a portal; mute the currently followed voice; create an empty world, add/extend/delete its first platform, undo and redo; save/load/export/import empty and populated worlds; play/pause/stop; confirm the Home Screen icon after installation. Check backgrounding and audio route changes as before.


Latest manual checks to add: compare Harp/Wind/Wood platforms and String/Flute/Clarinet voices, try the ribbon and amphitheater random layouts, enter full screen and tap once to restore controls, export a complete MP4 in overview and first person, check portal fades and gesture timing, cancel midway, share/save the result, and compare its duration and sound with the WAV export. The procedural objects and synthesized instruments need visual and acoustic evaluation on device.

Random and manual construction now use the same explicit tile and structure catalogue. Reconstruction equivalence has been checked for 200 seeds. Precise placement fields and the mixer variation code expose the fractional coordinates and musical variation required for an exact rebuild. Bridges, portal connections and a percussion stand are automatic functional connections shared by both workflows.

On device, check the complete builder flow in portrait and iPad landscape: choose and place several types, switch between Select and Place, hold/drag from different parts of a tall object, enable/disable snapping, change elevation, edit precise coordinates and dimensions, duplicate/rotate/delete, undo a whole drag, cancel a gesture, leave with Listen, return with Build and save/load edited Random scenery. Placement uses world-space ray/plane intersection; drag previews avoid rebuilding the scene on every finger move. Camera comfort, hit testing and gestures still need device validation.

The single portal envelope and modal event generation are verified in CPU tests. Their subjective visual/acoustic appearance and MP4 rendering still require device evaluation. Existing worlds default to Stay in scale / mode; intentional chromatic arrangements can opt out in the mixer, and that preference is serialized.

Character portrait strip: vector miniatures match role colors and identifying accessories; active/disabled states are visible and labelled for accessibility. Production iOS sources type-check. Actual layout and touch targets still need device evaluation. Live playback now pre-renders all six linear stereo stems and mixes them through one AVAudioSourceNode sample cursor, applying the same post-sum tanh limiter as WAV export. Toggle targets ramp over 384 samples (8 ms); pause freezes the shared cursor, all-muted playback keeps advancing. No re-render, reschedule, scene rebuild, or transport reset occurs on a toggle. Portrait camera buttons are separate from 44-point speaker controls and preserve first-person mode. Controller tests cover transport continuity using mocked audio; real device listening and layout verification remain pending. Stem buffers increase memory use, especially for long slow loops.


## Flying roles and arpeggio floor controls

Violet's safe hover anchor sits above obstructing geometry and its glowing core represents the sustained tonic. Sage commits to an overhead flight path, clears the highest obstruction along that corridor, slows near its waypoints and opens a three-light chord canopy. Static air clearance includes full decorative envelopes, including open arch vaults and torus rims; ground navigation retains their openings. The planner is conservative and prefers flying above an obstacle rather than finding a narrow opening through it. Normal ground encounters exclude flying roles. Moving characters can still make an airborne body yield vertically or wait safely.

Filter Gate stores a normalized cutoff; the arpeggio sequence activates a real cascaded low-pass filter (150–12,000 Hz). Octave Bloom changes the arpeggio pattern to span one, two or three octaves within its available register. These settings persist to the next corresponding gate and reset at the musical loop start. Event-level cutoff/range also drive Coral's lens/rings, giving audio and animation a single source of modifier state. Audio checks verify persistent state, serialized settings, expanded note range, exact motion-event state and reduced high-frequency energy in the filtered render.

Random now connects levels with gentler ramps and bridges, while a steep final return may retain one portal. A skipped silent pad is walked through if the intervening route is connected. Columns and island supports use the same foot clearance as platform tops, avoiding false collisions while descending. Portal posts align across their connected approach rather than blocking it. Existing saved geometry is preserved.

These additions pass native CPU tests and iOS source type checking. Their subjective motion, material appearance, touch controls, acoustic playback and exported MP4 still need evaluation on iPhone/iPad. Floor modifiers follow the musical event sequence; physical collision yielding can still delay Coral's body relative to that sequence.

## Visual and builder regression review

Added ascending/descending raised-step fixtures checking both body clearance and completed travel; a late-target corner traversal fixture; rotated drone-halo face clearance; controller tests placing exactly one Orbit before a path, keeping characters disabled after the first musical step, and explicitly adding a character afterwards. Existing scene/motion/flight/portal and builder suites remain required.

The renderer uses short deck boxes rather than one broad sloping AABB. Navigation accounts for raised landing approach clearance and intermediate corners. A maneuver obstructed by another arrival releases its waiting partner after 350 ms. New empty worlds have no enabled voices. The build palette separates characters from musical steps and scenery, shows the active placement piece, and prevents a placement-mode long press from selecting a different piece.

Native SceneKit CPU tests and iOS type-checking do not validate final pixels or touch behavior on a device. Device visual review, including user-generated dense geometry, remains pending.

Front-view regression: CPU camera tests check vertical world axes remain vertical on screen and horizontal platforms remain horizontal. Controller tests check entering/exiting Front leaves character cameras and preserves the existing world. Video camera snapshots include the selected overview style.

## Environment backdrops

Added five persisted environments with deterministic 2048×2048 Core Graphics artwork, environment lighting and fog. They are outside sculpture geometry, collision space and framing bounds. Live changes update the background/light/fog without restarting audio or rebuilding characters. Export uses the same scene implementation.

Regression coverage checks native texture dimensions and distinct content, round-trip and legacy decoding, unchanged bounds, random coverage and controller transport continuity. These are CPU/source checks; final appearance and MP4 rendering still require a functioning GPU/device.

## Coherent random generation and revised atmosphere

The new RandomMotion suite checks 1,000 generated seeds for valid metadata, scenery corridor/stage clearance and separate starts. It simulates 30 production SceneKit worlds for two complete audio loops each, checking ongoing body clearance, spawn height, walking distance and no stationary interval longer than four seconds for enabled walking roles. Drone and percussion are intentionally excluded from walking-distance requirements because their musical roles hold a station.

Random reserves a wide route before populating it, phases walking voices apart, moves the stationary drummer to an outer stage, checks decoration against sampled corridor envelopes and adds supports below the deck. Eight-bar loops and normalized note-to-route progression avoid chasing a faraway reset target at the audio loop boundary. Width and synchronized-route settings are stored in JSON, with legacy defaults preserving existing worlds.

Backdrops have been regenerated and visually inspected as CPU-rendered images, with soft gradients, landscape depth, planetary shading, underwater lighting and restrained grain. Final scene compositing, device performance and MP4 appearance still need GPU/device review.

## Rotating mechanisms, initial stage and folding panel

Mechanisms suite samples 24 rotation phases in presets and a generated world, maps canonical primitive vertices into their declared geometry dimensions, and checks the transformed vertices fit the full-turn envelope. Additional checks cover mechanism/scenery separation, persistent legacy repair, initial drummer alignment, stage existence before playback and live reveal after enabling, and preserved narrow custom-world stage coordinates. RandomMotion also checks full-turn separation for its 1,000 seeds.

The initial-stage correction is limited to the Hanging Gardens preset and its recognized saved predecessor. The other stage-placement rules are preserved. Character-panel disclosure uses an independent persisted UI preference; physical-device touch/layout validation is pending.

All geometry and motion checks here are CPU-based. Final rendered wheel clearance and UI appearance require device/GPU review.

## World-specific construction tutorial and open gateways

Tutorial tests step through five generated-world blueprints, check coverage of every platform, instrument and scenery record, validate targets and chapter navigation, preserve hidden states and source JSON, and cover empty/scenery-only sources. Controller tests check exact snapshots, unchanged world/history, preserved paused sample position and conditional resumption. The viewer is a demonstration, with manual and automatic progression, rather than an editor that changes the current world.

Arches tests check replacement of the violet torus, twenty solid vault segments, invisible collision-proxy camera masks, free body clearance through the hole, real roof collisions and successful traversal along both X and Z routes. Existing motion, flight, portal, full-turn mechanism and random-world suites remain required.

Violet and gold arches have real openings; collision proxies follow each vault segment instead of treating the entire hole as solid or ignoring the roof mesh. Combined portal/transpose stations avoid duplicate arches. Sounding-tile foot-clearance profiles and costume-aware actor radii address accessory/foot penetration.

Native CPU geometry checks and iOS type-checking do not validate rendered pixels or touch layout. Device review is still needed for the tutorial viewport, material appearance and final collision presentation.

### Simplified builder
Added controller checks for empty-path creation, single-tap extension, directional attachment, inherited elevation, explicit character addition, undoable sound replacement, and sound undo. iOS source typecheck passes. Device interaction and visual validation remain pending because CoreSimulator/GPU are unavailable in this environment.

### Module-first builder
87 controller checks passed, including all five module payloads, six-step assembly, ornament/voice setup, scale protection, chaining, atomic undo, and rejection of unrelated text payloads. Full iOS source typecheck passes. Native drag/drop gesture behavior, visual clearances, and GPU movie export still require device verification; no simulator launch is claimed.

## Grouped construction, social video and living photographic backgrounds

The full native suite passed after removing the former placement/count bounds: 108,466 model/audio checks; 1,335 scene/camera; 40,309 motion; feature/background checks; 12,388 builder reconstruction; 697 portal; 6,688 flight; 194,843 mechanism; 282,491 random-world motion; 1,723 tutorial; 2,496 arch; and 275 production controller checks with mocked platform audio/video. iOS source typecheck passed. The final drag-preview refinement (including internal bridge sections) is also checked by the controller suite and iOS typecheck.

Controller coverage includes all eight module templates, whole-group drag/undo/cancellation, persistent grouping, conservative recovery of earlier six-step modules, atomic overlap rejection, construction beyond 96 tiles and prior coordinate bounds, and import of more than 128 scenery objects. Movie-plan checks cover both presets and randomized worlds, bar-aligned durations, two-bar cut boundaries, enabled walking-only first person, split-screen opt-out, and the all-muted/no-walker cases.

Feature checks load all five project-bound photographic images, verify independent cloud movement, deterministic repeated timestamps, correct aspect-fill geometry for portrait video, transient seeded meteors, and the absence of atmosphere collision geometry. The transparent cloud asset's alpha and all six catalog resource references were inspected. Generated artwork was visually inspected through the generation tool; prompt set and saved locations are in BACKGROUND_ART.md.

This is CPU/model and compile validation. The GPU-composited background layers, native drag gesture feel, final 1080p split-screen appearance, video mux/encoding, cancellation, share sheet and sustained performance of very large worlds still need physical iPhone/iPad validation. No device or simulator render is claimed.

### Background origin and cloud clock correction
Corrected the vertical origin once on a shared SpriteKit content container, including photographic art, clouds and meteors. The background canvas retains its manually managed aspect instead of requesting renderer-driven resize. Live scene updates now receive their atmosphere timestamp directly: there is one atmosphere update, rather than music time immediately followed by view time. Offline rendering retains its explicit musical time.

Feature regressions check the complete composition's vertical transform and parentage, and 180 consecutive live frames across playback/pause with bounded cloud position/opacity changes. Native source typechecking covers the changed live call signature. GPU appearance remains subject to device verification.

### Real camera orbit and panoramic surroundings
Five new 2:1 panoramic image assets replace viewport-sized background rendering in the primary environment path. The surrounding sphere is a root-level, camera-centered constant material, drawn before geometry without depth writes or shadows; its category is excluded from piece hit tests. Both normal and advanced-builder camera masks include it. Scene fog is disabled for this environment compositing path so the distant background does not become a solid fog color.

Scene tests now exercise real camera orbit through four directions at three viewport sizes, checking native frustum fitting while architecture stays stationary. Additional assertions cover changing panorama direction on orbit and eye-level turning, world-bound isolation, camera-centering, depth order and fixed longitude/latitude coordinates in split screen. Features verify all five 2:1 asset dimensions and retain cloud clock/orientation regressions. Controller tests cover camera-only Rotate, Fit/Front reset and advanced builder visibility; 279 controller checks passed. Focused tutorial cameras reposition their environment after reframing. iOS source typechecking passed.

Generated panoramas were inspected through the built-in generation tool. Final image paths and prompt set are documented in BACKGROUND_ART.md. CPU tests cannot certify GPU-composited vertical orientation, wrap seams/poles, material appearance or MP4 output. These require physical-device visual verification. No navigable near-field terrain or foreground parallax is claimed.

### Shared visual-style coverage
Added a Visuals suite for distinct bounded surface maps, physically based material profiles, metal/wood separation, panoramic reflection lighting, rim light, contact-shadow masks/parentage, cloth/enamel character finishes, lit vault meshes, blink timing, collision preservation, independent paused-water animation, deterministic repeated video timestamps, foam/depth handling and shadow projection only onto actual routes. Instrument checks exercise all five acoustic pad families, key/membrane response and glow reset after playback stops.

Visual changes are shared by the same GardenScene constructors used by presets, imports, random worlds, builder modules, tutorial and video. No serialized musical data or audio scheduling changed. The shadow projection query extends the ground-height search only for visual shadows; locomotion retains its original maximum step/drop behavior.

CPU tests and source typechecking cannot validate final material appearance, transparency sorting, soft-shadow pixels, water reflections or the performance of those GPU effects on a phone. Physical-device review remains required; no rendered screenshot or MP4 validation is claimed.

Visual-style regression run completed successfully across the full existing suite, including audio, motion, coherent random worlds, vault/collision geometry, builder/tutorial and controller checks. The final visual-specific suite has 116 checks, including torso-only turn anticipation and transparent-water shadow suppression. Final iOS source typechecking also passed.

### Overview photographic-background sampling
Removed the static photograph from SpriteKit rasterization, keeping a direct native image texture on the base sphere and a transparent animated overlay sphere. Added anisotropic mip filtering and increased sphere tessellation. Orthographic background pitch is clamped to ±10° in panoramic coordinates, preventing the overview from centering on highly compressed nadir pixels; camera azimuth and first-person pitch remain intact. Tests cover direct-source routing, overlay registration, sampled polar latitude and texture filters. Existing source artwork is genuinely 1774 × 887; no resolution-upscaling claim is made. GPU pixel quality and final orientation remain unverified here.


## Independent overview panorama projection

The orthographic overview now renders the photographic and animated layers on a shared camera-facing tessellated surface, whose texture coordinates come from independent panoramic perspective rays. World zoom, fitting and tutorial focus no longer magnify a narrow patch of the background sphere. Current overview coverage is 50 degrees on the longest viewport axis, with aspect-correct horizontal and vertical fields. This supersedes the earlier 92-degree overview projection. Camera azimuth and the existing gentle overview pitch remain represented; first person restores the original spherical geometry. Longitude coordinates unwrap before interpolation to avoid seam-spanning triangles. Stationary views reuse their mesh; no shader or audio-path changes.

CPU scene checks passed for zoom-invariant texture coverage, wide coverage at 3x world zoom, stationary mesh caching, finite coordinates, longitude continuity and restoring both spherical layers in first person. iOS source typechecking passed. This improves projection and sampling; source artwork remains 1774 × 887 and GPU appearance still requires device review.

Normal-lens / ocean wrap follow-up: overview FOV tests passed at portrait, square and landscape aspect ratios, alongside independent world zoom and camera orbit checks. All 887 rows of the prepared sunset texture have equal RGBA values at both horizontal boundaries; checks also passed for unchanged center pixels, cached preparation, and sharing the same prepared texture with reflection lighting. Feature/environment regressions and iOS source typechecking passed. The ocean panorama was edited with the built-in image tool; the renderer additionally feathers the outer 6% on each side to enforce continuous boundary colors. Final seam appearance and lens composition still need physical-device review.


## Panorama magnification and compact controls

Added one-time Accelerate/vImage high-quality Lanczos reconstruction of the 1774 × 887 panorama sources to a 4096 × 2048 sampling texture before GPU magnification. This improves interpolation only and is not new native detail or higher-resolution artwork. A two-entry, 72 MiB-cost NSCache bounds prepared texture caching. Sunset boundary matching runs after reconstruction so the reflection and backdrop textures stay periodic. The 50° overview lens remains unchanged. Front and Backdrop now use icon-only circular 44-point controls with accessibility labels; the backdrop accessibility value still names the selected environment.

Feature checks passed for all five reconstructed textures, aspect preservation, no repeated enlargement at target size, smooth subpixel reconstruction, unchanged seam continuity, shared reflection source and cache reuse. Scene/camera regressions and iOS source typechecking passed. Actual perceived sharpness remains a device/GPU visual check; original panorama detail remains limited by the source image.


## Native overview photographic plates — screenshot-driven correction

The supplied device screenshot showed that the normal 50-degree overview lens was magnifying only a small sector of the 1774 × 887 panoramic source. Upsampling did not create detail and was insufficient. Overview now directly uses the existing 1254 × 1254 Backdrop photographic plates. Aspect-fill with 8% overscan uses over 500 × 1100 genuine source pixels at the supplied 1179 × 2556 portrait aspect, instead of roughly 120 × 246 native panorama pixels. A bounded sinusoidal camera-relative pan stays within the image at all yaw angles, with continuity across full rotations and no texture wrap. This is deliberately scenic parallax, not a full 360-degree overview environment. First-person views still use the real panoramic sphere. The photographic plate and atmospheric overlays now have separate texture coordinates on coincident visual-only geometry.

CPU scene checks passed for direct original-image binding, native source coverage, aspect preservation across five viewport shapes, edge-safe pan across multiple orbits, full-orbit continuity, world-zoom invariance, stable geometry reuse, restoring first-person sphere geometry and both existing camera and collision-framing regressions. iOS typechecking passed. A CPU photographic composition preview for each environment was generated in Previews/ at 1179 × 2556 using the same actual overview mesh texture-coordinate bounds. The sunset preview was visually inspected and shows substantially more source detail than the provided screenshot. These previews do not certify GPU cloud composition, color grading or final device rendering.

## Restore continuous overview rotation

Replaced the bounded sinusoidal horizontal pan with linear camera-azimuth texture positioning (one photographic texture period per complete turn). Overview plates retain the native image scale and aspect-fill framing, and receive the existing edge feather preparation before horizontal repeat. Vertical framing remains bounded; first person continues using its spherical panorama. Tests passed for monotonic background movement over multiple rotations, a one-period wrap across ±π, matching boundary RGBA values on every row, material repeat mode, source coverage, aspect and zoom invariance, and restoration of first-person geometry. iOS source typechecking passed. Native photographic previews were refreshed; final GPU/device appearance remains unverified here.

## Correct overview rotation direction against fixed world bearings

The continuous overview plate offset had the wrong sign: plate U increases to screen-right, while the inside-facing spherical longitude convention increases toward world-left. Negating the horizontal heading offset aligns the plate with camera-projected world bearings and the atmospheric layer without changing source scale, crop size, wrap period, image quality or first-person geometry.

The earlier monotonic-U test was insufficient to catch this directional error. A new regression independently transforms a fixed world-space direction through SceneKit camera matrices before and after positive/negative camera turns at seven headings, including the longitude wrap. It checks that the same photographic landmark moves in the same screen direction as that fixed bearing. All 14 directional cases, existing scene/camera regressions, seam continuity and zoom invariance passed. iOS source typechecking passed. This verifies the sign and continuity mathematically; GPU/device motion appearance still needs visual review.

## Living photographic environments

Added deterministic, spatially masked texture-coordinate flow for underwater surface ripples and edge vegetation, sunset water waves, and slow sky cloud flow. Underwater background floor-center pixels and the ocean horizon stay pinned. Native photographs remain directly sampled on the overview mesh; first-person non-space backgrounds use a 96 × 48 tessellated sphere with the same type of UV motion. The sphere reuses its vertex/index sources and avoids rebuilding twice at the same explicit atmosphere time. Overview mesh cache keys include animation time; space stays static apart from existing meteors.

Underwater atmosphere gains six feather-textured animated light shafts and twelve subtle moving caustic curves. Sunset gains forty fragmented wave highlights whose view-dependent intensity uses shared wave phases for normal slopes, a fixed sun direction, the camera/view half-vector and Schlick Fresnel. Reflection position and brightness respond to camera heading/elevation without advancing animation time. Cloud and light layers use photo-aligned coordinates in non-space overview, preserving the independent direct photographic texture and its native sharpness. First person retains panoramic overlay coordinates. All timing is absolute/deterministic; it does not restart the audio engine or create world colliders.

Visual regression checks passed for moving water/vegetation, pinned ocean horizon and plant roots, static central underwater rocks, seam continuity over all five environments at several times, finite and bounded UVs, native material binding, paused animation, same-time geometry reuse, animated first-person geometry, moving shafts, camera-dependent glitter and bounded analytic solar reflection. Existing Features and Scene suites passed, including the fixed-world-bearing camera rotation regression; iOS source typechecking passed. These are photographic motion approximations with analytic specular accents, not physical fluid simulation or true 3D background plants. GPU appearance, frame rate on device, SpriteKit compositing and MP4 playback remain unverified here.

## Real 360° coastal movie pilot

Integrated the actual CC BY 3.0 2FILMZ Studios coastal stereoscopic video as the pilot for the existing sunset environment. Source SHA-1 matched the Commons record. One eye was extracted and its compressed vertical proportions restored; this creates no extra native detail. The adapted H.264 asset is 3840 × 1920, 30 fps, 330 frames / 11 seconds, no audio, with a one-second temporal crossfade. FFmpeg decoded all 330 frames. At 128 × 64 luma analysis, last-to-first mean absolute difference was 1.076 versus median adjacent difference 0.519 and maximum adjacent difference 1.905; the loop transition was inside ordinary motion variation. This does not prove an invisible perceptual join.

Live iOS playback uses AVQueuePlayer/AVPlayerLooper with a startup poster. Video projection bypasses all photographic UV effects and overview pitch counter-rotation. The overview's perspective ray grid and the first-person sphere sample the same real spherical coordinates. The pilot is initially oriented toward the sea. Export prepares AVAssetReader, stops and releases live-player items, decodes frame indices from the explicit simulated clock, reuses a frame for split views, and resets at the 330-frame wrap. Decoder failures abort export rather than silently writing a frozen panorama. Visible attribution is included in exports and complete author/source/license/adaptation credits in Help and the asset folder.

3309 loop-clock and independent world-bearing projection checks passed; Scene, Features and Visuals regressions passed; iOS source typechecking passed. XcodeGen registered the new Swift source, movie and poster as resources in the same project with unchanged bundle/version. A native AVFoundation decoding attempt in this tool environment failed with AVFoundation -11821 / underlying OSStatus -12911, while the same asset decoded fully in FFmpeg. No native live playback, GPU orientation/performance or completed exported movie is claimed as verified. Physical-device validation is still needed, especially source 4K sharpness, top/bottom stereo adaptation, temporal blending, switching cameras and 30–60 second exports. The footage is a daylight coastal time-lapse with source camera movement/capture imperfections, not final 8K sunset/open-ocean art.
