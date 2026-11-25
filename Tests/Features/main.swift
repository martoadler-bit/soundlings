import Foundation
import SceneKit
var checks=0
func check(_ condition:Bool,_ message:String) {if !condition {fatalError(message)};checks+=1}
var blank=World.blank
check(blank.valid && blank.tiles.isEmpty && blank.events().isEmpty,"Empty world is valid and silent")
check((try! JSONDecoder().decode(World.self,from:blank.encoded())).tiles.isEmpty,"Empty save/import round trip")
let scene=GardenScene(blank)
check(scene.walkers.isEmpty && scene.pads.isEmpty,"Blank scene has no implicit architecture or actors")
scene.update(blank,beat:1,selected:nil)
scene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:false)
blank.tiles=[Tile(x:0,y:1,z:0,note:60)]
check(blank.valid && blank.events().isEmpty,"First platform never implicitly adds a character")
blank.voices[0].enabled=true
check(!blank.events().isEmpty,"Explicitly adding a character makes the first platform play")
scene.rebuild(blank)
check(scene.pads.count==1,"First platform builds without a prebuilt world")
check(blank.insert(after:0,dx:1,dy:0,dz:0),"First platform can extend")
blank.tiles=[];scene.rebuild(blank)
check(scene.walkers.isEmpty,"Deleting all pads returns to a blank scene")
let world=World.garden
scene.rebuild(world)
for voice in world.voices.indices {
    scene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:true,voice:voice,firstPerson:true)
    check(scene.camera.camera!.usesOrthographicProjection==false,"First-person uses perspective")
    check(scene.camera.camera!.projectionDirection == .horizontal && scene.camera.camera!.fieldOfView==92,"Wide horizontal angle in portrait")
    let expected=scene.sculpture.convertPosition(SCNVector3(scene.walkers[voice].position.x,scene.walkers[voice].position.y+0.6,scene.walkers[voice].position.z),to:nil)
    check(abs(scene.camera.position.x-expected.x)<0.001,"First-person follows selected actor")
    check(scene.walkers[voice].childNodes.allSatisfy{$0.categoryBitMask==2},"Own avatar excluded from eye camera")
    for other in world.voices.indices where other != voice {check(scene.walkers[other].childNodes.allSatisfy{$0.categoryBitMask==1},"Other avatars remain visible")}
    scene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:true,voice:voice)
    check(scene.camera.camera!.usesOrthographicProjection,"Follow returns to orthographic camera")
    check(scene.walkers.allSatisfy{$0.childNodes.allSatisfy{$0.categoryBitMask==1}},"Leaving eye view restores every avatar")
}
scene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:false)
check(scene.camera.camera!.usesOrthographicProjection,"Overview restored")
// A clear straight path supports a jump over a waiting actor.
let flat=World(tiles:(-2...3).map{Tile(x:Float($0),y:1,z:0,note:60)})
let encounter=EncounterMotion()
let desired=[SpaceBody(point:SpacePoint(x:1.5,y:1,z:0),radius:0.2,height:0.8),SpaceBody(point:SpacePoint(x:-1,y:1,z:0),radius:0.2,height:0.8)]
var previous=[SpacePoint(x:0,y:1,z:0),SpacePoint(x:0.7,y:1,z:0)]
var maxHeight=1.0,lockedFrames=0
for _ in 0..<70 {
    let next=encounter.step(desired,previous:previous,world:flat,obstacles:[],seconds:1/60,portals:[])
    if !next.locked.isEmpty {lockedFrames+=1}
    for i in previous.indices {
        let p=next.points[i],old=previous[i]
        check(sqrt(pow(p.x-old.x,2)+pow(p.y-old.y,2)+pow(p.z-old.z,2))<0.15,"Encounter follows a continuous trajectory")
    }
    var a=desired[0],b=desired[1];a.point=next.points[0];b.point=next.points[1]
    check(!CharacterSpace.intersects(a,b),"Jump never crosses the waiting body")
    maxHeight=max(maxHeight,next.points[0].y);previous=next.points
}
check(encounter.jumps==1 && maxHeight>2.2 && lockedFrames>40,"Committed hop, with partner waiting and cooldown")
check(previous[0].x>previous[1].x && abs(previous[0].y-1)<0.001,"Jumper lands beyond its partner")
// A low ceiling forbids jumping; choose a deliberate reverse maneuver instead.
encounter.reset();previous=[SpacePoint(x:0,y:1,z:0),SpacePoint(x:0.7,y:1,z:0)]
let ceiling=SpaceObstacle(min:SpacePoint(x:-1,y:1.95,z:-1),max:SpacePoint(x:2,y:2.2,z:1))
for _ in 0..<50 {previous=encounter.step(desired,previous:previous,world:flat,obstacles:[ceiling],seconds:1/60,portals:[]).points}
check(encounter.turns==1 && encounter.jumps==0 && previous[0].x < -0.5,"Low ceiling triggers a turn instead of a jump")
print("\(checks) empty-world, camera and encounter checks passed.")

var atmosphere=World.garden
let atmosphereScene=GardenScene(atmosphere)
let atmosphereBounds=atmosphereScene.boundsMax
var backgrounds=Set<Data>()
for environment in WorldEnvironment.allCases {
    atmosphere.environment=environment
    let decoded=try! JSONDecoder().decode(World.self,from:atmosphere.encoded())
    check(decoded.environment==environment,"Backdrop survives world export/import")
    atmosphereScene.applyEnvironment(atmosphere)
    check(atmosphereScene.boundsMax.x==atmosphereBounds.x && atmosphereScene.boundsMax.y==atmosphereBounds.y,"Backdrop cannot change world bounds or collision framing")
    check(GardenScene.photographicBackdrop(environment) != nil,"Every environment ships its photographic image")
    let image=GardenScene.backdrop(environment,seed:123)!
    check(image.width>=1024 && image.height>=1024,"Backdrop texture has a valid native image")
    backgrounds.insert(image.dataProvider!.data! as Data)
}
check(backgrounds.count==WorldEnvironment.allCases.count,"Each environment has a distinct visual backdrop")
var legacyEnvironment=try! JSONSerialization.jsonObject(with:atmosphere.encoded()) as! [String:Any]
legacyEnvironment.removeValue(forKey:"environment")
check((try! JSONDecoder().decode(World.self,from:JSONSerialization.data(withJSONObject:legacyEnvironment))).environment == .sky,"Existing worlds load with a default sky")
check(Set((0..<100).map{World.generate(seed:UInt64($0)).environment})==Set(WorldEnvironment.allCases),"Random covers every backdrop")
print("Backdrop persistence, native textures, bounds and random coverage passed.")

var living=World.blank;living.environment = .sky
let skyScene=GardenScene(living)
check(GardenScene.photographicBackdrop(.sky) != nil,"Photographic artwork is part of the project")
check(skyScene.atmosphere?.clouds.count==3,"Sky uses three independent cloud layers")
let layer=skyScene.atmosphere!
layer.resize(CGSize(width:1080,height:1920));layer.update(time:0)
let firstPosition=layer.clouds[0].position
layer.update(time:15)
check(layer.clouds[0].position != firstPosition,"Clouds drift over time")
let later=layer.clouds[0].position
layer.update(time:15)
check(layer.clouds[0].position==later,"Background time is deterministic for video and split screen")
let photo=layer.photo.size,viewport=layer.canvas.size,native=layer.photo.texture!.size()
check(abs(photo.width/photo.height-native.width/native.height)<0.0001 && photo.width>=viewport.width && photo.height>=viewport.height,"Panorama retains its aspect ratio in spherical coordinates")
living.environment = .space;living.seed=123
let starScene=GardenScene(living),starLayer=starScene.atmosphere!
starLayer.update(time:6.4)
check(starLayer.meteor.alpha>0,"Seeded space backdrop occasionally shows a meteor")
starLayer.update(time:8)
check(starLayer.meteor.alpha==0,"Meteors disappear between brief sightings")
check(starScene.sculpture.childNodes.isEmpty,"Animated atmosphere adds no collision geometry to an empty world")
print("Animated photography, cloud drift, meteor timing and portrait framing passed.")

check(layer.content.yScale == -1 && layer.content.position.y==layer.canvas.size.height,"SceneKit vertical-origin correction covers the whole background")
check(layer.photo.parent===layer.content && layer.clouds.allSatisfy{$0.parent===layer.content},"Photography and animated clouds share one orientation correction")
check(starLayer.meteor.parent===starLayer.content,"Meteor orientation matches the background")
var smoothSky=World.blank;smoothSky.environment = .sky
let smoothScene=GardenScene(smoothSky),smoothLayer=smoothScene.atmosphere!
for frame in 0..<180 {
    let time=40+Double(frame)/60
    smoothScene.update(smoothSky,beat:frame<90 ? 8 : 0,selected:nil,playing:frame<90,atmosphereTime:time)
    let positions=smoothLayer.clouds.map(\.position),opacity=smoothLayer.clouds.map(\.alpha)
    smoothLayer.update(time:time)
    check(smoothLayer.clouds.map(\.position)==positions && smoothLayer.clouds.map(\.alpha)==opacity,"Live background uses the requested clock across pause and music restart")
    smoothLayer.update(time:time+1/60)
    for (i,cloud) in smoothLayer.clouds.enumerated() {
        check(abs(cloud.position.x-positions[i].x)<1 && abs(cloud.alpha-opacity[i])<0.001,"Cloud position and opacity remain continuous between frames")
    }
}
print("Background orientation and single-clock continuity regression checks passed.")

for environment in WorldEnvironment.allCases {
    let panorama=GardenScene.bundledBackdrop("Panorama-"+environment.rawValue)
    check(panorama != nil && panorama!.width==panorama!.height*2,"Every environment ships a complete 2:1 panorama")
}
print("All five panoramic environment assets passed.")

let sunsetTexture=GardenScene.bundledBackdrop("Panorama-sunset")!
let seamBytes=sunsetTexture.dataProvider!.data! as Data
for y in 0..<sunsetTexture.height {
    let left=y*sunsetTexture.bytesPerRow,right=left+(sunsetTexture.width-1)*4
    check((0..<4).allSatisfy{seamBytes[left+$0]==seamBytes[right+$0]},"Sunset photographic wrap has identical RGBA values on both edges")
}
check(GardenScene.bundledBackdrop("Panorama-sunset") === sunsetTexture,"Seam correction is cached instead of recomputed per frame")
var ocean=World.garden;ocean.environment = .sunset
let oceanScene=GardenScene(ocean)
check((oceanScene.scene.lightingEnvironment.contents as AnyObject) === sunsetTexture,"Sunset reflections use the same continuous texture as the background")
let testContext=CGContext(data:nil,width:100,height:4,bitsPerComponent:8,bytesPerRow:400,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
testContext.setFillColor(CGColor(red:0.2,green:0.6,blue:0.8,alpha:1));testContext.fill(CGRect(x:0,y:0,width:100,height:4))
let testImage=testContext.makeImage()!,periodic=GardenScene.closePanoramaWrap(testImage)!
let before=testImage.dataProvider!.data! as Data,after=periodic.dataProvider!.data! as Data
var centerUnchanged=true
for x in 8..<92 {for channel in 0..<4 {
    if before[x*4+channel] != after[x*4+channel] {centerUnchanged=false}
}}
check(centerUnchanged,"Wrap repair leaves the central image unchanged")
print("Sunset wrap continuity, untouched center, shared reflections and cached texture preparation passed.")

let reconstructed=GardenScene.reconstructPanorama(testImage,maxWidth:200)!
check(reconstructed.width==200 && reconstructed.height==8,"Panorama reconstruction preserves image proportions")
check(GardenScene.reconstructPanorama(reconstructed,maxWidth:200) === reconstructed,"Textures at target size are never enlarged again")
let smoothContext=CGContext(data:nil,width:8,height:4,bitsPerComponent:8,bytesPerRow:32,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
smoothContext.setFillColor(CGColor(gray:0,alpha:1));smoothContext.fill(CGRect(x:0,y:0,width:8,height:4))
smoothContext.setFillColor(CGColor(gray:1,alpha:1));smoothContext.fill(CGRect(x:4,y:0,width:4,height:4))
let smooth=GardenScene.reconstructPanorama(smoothContext.makeImage()!,maxWidth:64)!
let smoothBytes=smooth.dataProvider!.data! as Data
let levels=Set((16..<48).map{smoothBytes[16*smooth.bytesPerRow+$0*4]})
check(levels.count>8,"High-quality reconstruction adds smooth subpixel transitions instead of nearest-neighbor blocks")
for environment in WorldEnvironment.allCases {
    let texture=GardenScene.bundledBackdrop("Panorama-"+environment.rawValue)!
    check(texture.width==4096 && texture.height==2048,"Every environment uses reconstructed panorama sampling")
}
print("Panorama Lanczos reconstruction, smooth interpolation, aspect and resolution limits passed.")
