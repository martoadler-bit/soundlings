import AppKit
import SceneKit
import ImageIO
var count=0
func check(_ condition:@autoclosure()->Bool,_ message:String) {
    guard condition() else { fatalError(message) }; count+=1
}
for world in [World.garden,World.moon,World.generate(seed:42,architecture:.spiral)] {
    let scene=GardenScene(world)
    check(scene.pads.count==world.tiles.count && scene.walkers.count==6,"One rendered pad per logical step and six creatures")
    let initial=scene.camera.position
    check(abs(initial.x)+abs(initial.y)+abs(initial.z)>20,"Camera is framed before the first UIKit layout")
    check(scene.camera.camera!.orthographicScale>1,"Native orthographic scale is initialized")
    scene.frame(size:.zero,zoom:1.04,pan:.zero,follow:false)
    check(scene.camera.position.x==initial.x && scene.camera.position.y==initial.y && scene.camera.position.z==initial.z,"A zero-size initial layout preserves the valid camera")
    let links=world.tiles.indices.filter { world.requiresPortalLink(from:$0,to:($0+1)%world.tiles.count) }
    check(scene.portals.count==Set(links.flatMap{[$0,($0+1)%world.tiles.count]}).count,"Every teleport link has visible departure and arrival portals")
    for size in [CGSize(width:393,height:852),CGSize(width:1024,height:1366),CGSize(width:1366,height:1024)] {
        for angle in [0.0,Double.pi/2,Double.pi,Double.pi*1.5] {
            scene.orbitYaw=angle
            scene.frame(size:size,zoom:1.04,pan:.zero,follow:false)
            let matrix=scene.camera.camera!.projectionTransform(withViewportSize:size)
            let bounds=scene.sculpture.boundingBox
            var widest=0.0
            for x in [bounds.min.x,bounds.max.x] { for y in [bounds.min.y,bounds.max.y] { for z in [bounds.min.z,bounds.max.z] {
                let point=scene.camera.convertPosition(scene.sculpture.convertPosition(SCNVector3(x,y,z),to:nil),from:nil)
                let px=point.x*matrix.m11+matrix.m41, py=point.y*matrix.m22+matrix.m42
                let pz=point.z*matrix.m33+matrix.m43
                check(pz.isFinite && pz > -1 && pz < 1,"Geometry is between the native camera clipping planes")
                check(abs(px)<1 && abs(py)<1,"Scene geometry stays inside frame: \(Int(size.width))×\(Int(size.height)), yaw \(angle)")
                widest=max(widest,abs(Double(px)))
            } } }

        }
    }
    scene.orbitYaw=0
    scene.frame(size:CGSize(width:393,height:852),zoom:1.04,pan:.zero,follow:false,frontView:true)
    let upright=scene.camera.convertVector(SCNVector3(0,1,0),from:nil)
    let horizontal=scene.camera.convertVector(SCNVector3(1,0,0),from:nil)
    check(abs(upright.x)<0.00001 && upright.y>0,"Front view keeps architecture vertical without camera roll")
    check(abs(horizontal.y)<0.00001,"Front view aligns horizontal platforms with the screen")
    let viewport=CGSize(width:393,height:852)
    scene.frame(size:viewport,zoom:1,pan:.zero,follow:false)
    let homePosition=scene.camera.position
    let defaultScale=scene.camera.camera!.orthographicScale
    scene.frame(size:viewport,zoom:2,pan:CGPoint(x:0.3,y:-0.2),follow:false)
    check(abs(scene.camera.camera!.orthographicScale*2-defaultScale)<0.0001,"Zoom adjusts SceneKit's native scale")
    check(scene.camera.position.x != homePosition.x || scene.camera.position.y != homePosition.y,"Panning moves the camera without overriding the projection")
    scene.update(world,beat:2.25,selected:2)
    check(!scene.selection.isHidden,"Editor highlights the selected pad")
    let plan=world.plan()
    for event in plan.events.prefix(40) {
        scene.resetMotion()
        scene.update(world,beat:event.beat,selected:nil,playing:true)
        var tile=world.tiles[event.tile]
        if world.voices[event.voice].role == .percussion {let stage=world.percussionStage();tile.x=stage.x;tile.y=stage.y;tile.z=stage.z}
        let walker=scene.walkers[event.voice]
        check(hypot(Double(walker.position.x)-Double(tile.x),Double(walker.position.z)-Double(tile.z))<=1.001,"Creature remains near its musical station while giving way")
        check(scene.collisionFree,"Production character colliders avoid one another and solid scenery")
    }
    check(scene.walkers.contains{$0.childNode(withName:"canopy",recursively:false) != nil},"Pad has a visible canopy")
    check(scene.walkers.contains{$0.childNode(withName:"beacon",recursively:false) != nil},"Drone has a visible beacon")
    let beacon=scene.walkers[3].childNode(withName:"beacon",recursively:false)!
    for yaw in stride(from:0.0,through:Double.pi*2,by:0.2) {
        beacon.eulerAngles.y=CGFloat(yaw)
        let bottom=Double(beacon.position.y)+Double(beacon.boundingBox.min.y)
        check(bottom>1.1,"Rotating drone halo stays completely above the face")
    }
    for tick in 0..<128 {
        scene.update(world,beat:Double(tick)/4,selected:nil,playing:true)
        check(scene.collisionFree,"Characters remain clear between musical onsets")
    }
    var muted=world; muted.voices[1].enabled=false
    scene.update(muted,beat:0,selected:nil)
    check(scene.walkers[1].isHidden,"Muted creature is hidden")
}
print("\(count) scene and camera checks passed without a GPU.")

let orbitWorld=World.garden,orbitScene=GardenScene(World.garden)
let viewport=CGSize(width:393,height:852)
orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:false)
let firstCamera=orbitScene.camera.position,firstDirection=orbitScene.camera.convertVector(SCNVector3(0,0,-1),to:nil)
orbitScene.orbitYaw = .pi/2
orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:false)
let nextDirection=orbitScene.camera.convertVector(SCNVector3(0,0,-1),to:nil)
check(orbitScene.camera.position.x != firstCamera.x || orbitScene.camera.position.z != firstCamera.z,"Orbit moves the camera through world space")
check(orbitScene.sculpture.eulerAngles.y==0,"Orbit leaves architecture and environment orientation unchanged")
check(abs(firstDirection.x-nextDirection.x)+abs(firstDirection.z-nextDirection.z)>0.5,"Orbit exposes a different panorama direction")
let dome=orbitScene.atmosphere!.dome
check(dome.parent===orbitScene.scene.rootNode && dome.parent !== orbitScene.sculpture,"Panorama is outside builder and collision bounds")
check(dome.categoryBitMask==32 && (orbitScene.camera.camera!.categoryBitMask & 32) != 0,"Panorama is visible to cameras but excluded from piece hit tests")
check(dome.position.x==orbitScene.camera.position.x && dome.position.z==orbitScene.camera.position.z,"Distant environment follows camera translation without false parallax")
check(dome.renderingOrder<0 && dome.geometry!.firstMaterial!.writesToDepthBuffer==false,"Panorama renders behind every world object")
orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:true,voice:0,firstPerson:true,lookYaw:0)
let facing=orbitScene.camera.convertVector(SCNVector3(0,0,-1),to:nil)
orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:true,voice:0,firstPerson:true,lookYaw:1)
let turned=orbitScene.camera.convertVector(SCNVector3(0,0,-1),to:nil)
check(abs(facing.x-turned.x)+abs(facing.z-turned.z)>0.1,"Turning on the spot in first person changes environment direction")
check(dome.position.x==orbitScene.camera.position.x && dome.position.y==orbitScene.camera.position.y,"Panorama remains camera-centered in first person")
let canvasSize=orbitScene.atmosphere!.canvas.size
orbitScene.frame(size:CGSize(width:1080,height:960),zoom:1,pan:.zero,follow:false)
check(orbitScene.atmosphere!.canvas.size==canvasSize && canvasSize.width==canvasSize.height*2,"Split screen and portrait share fixed spherical coordinates")
print("Real camera orbit, panoramic surroundings, eye rotation and split-screen mapping passed.")

let backgroundRay=orbitScene.atmosphere!.dome.convertVector(orbitScene.camera.convertVector(SCNVector3(0,0,-1),to:nil),from:nil)
let rayLength=sqrt(Double(backgroundRay.x*backgroundRay.x+backgroundRay.y*backgroundRay.y+backgroundRay.z*backgroundRay.z))
check(abs(asin(Double(backgroundRay.y)/rayLength))<Double.pi/15,"Overview panorama avoids the low-detail polar region")
check(orbitScene.atmosphere!.photo.isHidden,"Static photography bypasses the animated intermediate texture")
let photographic=orbitScene.atmosphere!.dome.geometry!.firstMaterial!.diffuse
check(photographic.maxAnisotropy>=8 && photographic.mipFilter == .linear,"Oblique panoramic texture sampling uses anisotropic mip filtering")
check(orbitScene.atmosphere!.motionDome.parent===orbitScene.atmosphere!.dome,"Atmosphere animation stays registered with the photographic sphere")
print("Direct panorama sampling, polar protection and filtered overlays passed.")

// Overview texture coverage must stay independent of orthographic world zoom.
func textureCoordinates(_ geometry:SCNGeometry)->[Float] {
    let source=geometry.sources(for:.texcoord)[0]
    return (0..<source.vectorCount).flatMap { i in
        source.data.withUnsafeBytes { bytes in (0..<2).map { j in
            bytes.loadUnaligned(fromByteOffset:source.dataOffset+i*source.dataStride+j*source.bytesPerComponent,as:Float.self)
        }}
    }
}
orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:false)
let wideUV=textureCoordinates(dome.geometry!)
let originalGeometry=dome.geometry!
orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:false)
check(dome.geometry === originalGeometry,"Stationary overview reuses its panorama mesh")
orbitScene.frame(size:viewport,zoom:3,pan:.zero,follow:false)
let zoomUV=textureCoordinates(dome.geometry!)
check(wideUV.count==zoomUV.count && zip(wideUV,zoomUV).allSatisfy{abs($0-$1)<0.00001},"World zoom never crops or magnifies the background texture")
check(zoomUV.allSatisfy{$0.isFinite},"Overview projection has finite panorama coordinates")
let columns=48,rows=32,centerRow=rows/2
let left=zoomUV[(centerRow*(columns+1))*2],right=zoomUV[(centerRow*(columns+1)+columns)*2]
check(abs(right-left)>0.4,"Portrait overview uses a substantial native photograph sector instead of a small panorama patch")
for aspect:Float in [0.46,0.75,1,1.33,1.78] {
    for heading in stride(from:Float(-7),through:7,by:0.25) {
        let crop=AtmosphereLayer.overviewCrop(aspect:aspect,imageAspect:1,heading:heading,pitch:0.2)
        check(abs(Float(crop.width/crop.height)-aspect)<0.00001,"Overview photograph preserves viewport proportions")
        check(max(crop.width,crop.height)>0.92,"Overview samples almost the entire longest image dimension")
        check(crop.minY>=0 && crop.maxY<=1,"Camera pitch stays inside photographic vertical bounds")
    }
}
let nearWrap=AtmosphereLayer.overviewCrop(aspect:0.46,imageAspect:1,heading:Float.pi-0.00001,pitch:0)
let pastWrap=AtmosphereLayer.overviewCrop(aspect:0.46,imageAspect:1,heading: -Float.pi+0.00001,pitch:0)
check(abs(abs(nearWrap.minX-pastWrap.minX)-1)<0.00001,"Overview camera movement wraps by exactly one texture period across a complete orbit")
var previous=AtmosphereLayer.overviewCrop(aspect:0.46,imageAspect:1,heading:-7,pitch:0).midX
for heading in stride(from:Float(-6.9),through:7,by:0.1) {
    let current=AtmosphereLayer.overviewCrop(aspect:0.46,imageAspect:1,heading:heading,pitch:0).midX
    check(current<previous,"Photographic U follows the inside-facing camera longitude convention throughout multiple rotations")
    previous=current
}
// Independently project a fixed distant landmark using SceneKit camera matrices.
// Merely checking monotonic U misses a background that moves opposite the world.
for yaw in [0.0,0.7,1.6,2.8,3.2,4.9,6.2] {
    for turn in [-0.05,0.05] {
        orbitScene.orbitYaw=yaw
        orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:false)
        let fixedDirection=orbitScene.camera.convertVector(SCNVector3(0,0,-1),to:nil)
        let oldCoordinates=textureCoordinates(dome.geometry!)
        let center=(centerRow*(columns+1)+columns/2)*2
        let featureU=oldCoordinates[center]
        orbitScene.orbitYaw=yaw+turn
        orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:false)
        let ray=orbitScene.camera.convertVector(fixedDirection,from:nil)
        let expectedScreenX=Double(ray.x / -ray.z)
        let now=textureCoordinates(dome.geometry!)
        var delta=Double(featureU-now[center]);delta -= delta.rounded()
        let imageSpan=Double(now[(centerRow*(columns+1)+columns)*2]-now[(centerRow*(columns+1))*2])
        let featureScreenX=2*delta/imageSpan
        check(expectedScreenX*featureScreenX>0,"Fixed background landmark moves in the same screen direction as the camera-projected world bearing")
    }
}
orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:false)
check(dome.geometry!.firstMaterial!.diffuse.wrapS == .repeat,"Overview material enables continuous horizontal camera rotation")
let plateImage=orbitScene.atmosphere!.overviewImage,plateBytes=orbitScene.atmosphere!.overviewImage.dataProvider!.data! as Data
for y in 0..<plateImage.height {
    let a=y*plateImage.bytesPerRow,b=a+(plateImage.width-1)*4
    check((0..<4).allSatisfy{plateBytes[a+$0]==plateBytes[b+$0]},"Overview plate wraps without a color discontinuity")
}
check((dome.geometry!.firstMaterial!.diffuse.contents as AnyObject) === orbitScene.atmosphere!.overviewImage,"Overview directly samples the native photographic plate")
for row in 0...rows {for column in 0..<columns {
    let a=(row*(columns+1)+column)*2,b=a+2
    check(abs(zoomUV[a]-zoomUV[b])<0.1,"Longitude seam never stretches a triangle across the entire photograph")
}}
for direction:SIMD3<Float> in [SIMD3(0,0,-1),SIMD3(-1,0,0),SIMD3(0,0,1),SIMD3(1,0,0)] {
    let uv=AtmosphereLayer.panoramaUV(direction,around:0)
    check(abs(uv.y-0.5)<0.00001,"Panorama horizon remains level")
}
orbitScene.frame(size:viewport,zoom:1,pan:.zero,follow:true,voice:0,firstPerson:true)
check((dome.geometry is SCNSphere || dome.geometry?.name=="animatedPanoramaSphere") && orbitScene.atmosphere!.motionDome.geometry is SCNSphere,"First person restores the spherical photographic and animation geometry")
print("Native overview plate, aspect-safe framing, zoom invariance and continuous camera movement passed.")

// Optional CPU preview of the exact photographic texture window used by overview.
// This is a background-composition preview, not a GPU screenshot of the game.
if let directory=ProcessInfo.processInfo.environment["SOUNDLINGS_PREVIEW_DIR"] {
    for environment in WorldEnvironment.allCases {
        var world=World.garden;world.environment=environment
        let garden=GardenScene(world)
        garden.frame(size:CGSize(width:1179,height:2556),zoom:1,pan:.zero,follow:false)
        let layer=garden.atmosphere!,coordinates=textureCoordinates(layer.dome.geometry!)
        let us=stride(from:0,to:coordinates.count,by:2).map{coordinates[$0]}
        let vs=stride(from:1,to:coordinates.count,by:2).map{coordinates[$0]}
        let image=layer.overviewImage
        let rect=CGRect(x:Double(us.min()!)*Double(image.width),y:Double(vs.min()!)*Double(image.height),width:Double(us.max()!-us.min()!)*Double(image.width),height:Double(vs.max()!-vs.min()!)*Double(image.height))
        check(rect.width>500 && rect.height>1100,"Portrait overview uses real source pixels across the full photograph")
        guard let crop=image.cropping(to:rect),let context=CGContext(data:nil,width:1179,height:2556,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {fatalError("Preview context")}
        context.interpolationQuality = .high
        context.draw(crop,in:CGRect(x:0,y:0,width:1179,height:2556))
        let file=URL(fileURLWithPath:directory).appendingPathComponent("overview-"+environment.rawValue+".png")
        let destination=CGImageDestinationCreateWithURL(file as CFURL,"public.png" as CFString,1,nil)!
        CGImageDestinationAddImage(destination,context.makeImage()!,nil)
        check(CGImageDestinationFinalize(destination),"Overview preview saved")
    }
}
