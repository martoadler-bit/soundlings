import Foundation
import SceneKit
var checks=0
func check(_ value:@autoclosure()->Bool,_ message:String) {guard value() else {fatalError(message)};checks+=1}
let style=VisualStyle()
var surfaces=Set<Data>()
for kind in SurfaceFinish.allCases {
    let maps=VisualStyle.maps[kind]!,material=style.material(kind,tint:.white)
    check(maps.albedo.width==128 && maps.normal.width==128 && maps.roughness.height==128,"Surface maps have bounded texture size")
    check(material.lightingModel == .physicallyBased && material.normal.contents != nil,"All finishes use physically based surface detail")
    surfaces.insert(maps.normal.dataProvider!.data! as Data)
}
check(surfaces.count>=6,"Material families have genuinely different microstructure")
let metal=style.material(.metal,tint:.white),wood=style.material(.wood,tint:.white)
check((metal.metalness.contents as! NSNumber).doubleValue>0.7 && (wood.metalness.contents as! NSNumber).doubleValue==0,"Wood and metal have distinct optical behavior")
for world in [World.garden,World.moon,World.generate(seed:47)] {
    let scene=GardenScene(world)
    check(scene.scene.lightingEnvironment.contents != nil,"Every scene receives panoramic reflection lighting")
    check(scene.scene.rootNode.childNode(withName:"rimLight",recursively:false) != nil,"Characters and architecture share soft rim lighting")
    check(scene.contactShadows.count==scene.walkers.count,"Every character has a soft contact shadow")
    check(scene.contactShadows.allSatisfy{$0.categoryBitMask==64 && !$0.castsShadow && $0.parent===scene.sculpture},"Contact accents are visual-only and independent of the actor")
    for actor in scene.walkers {
        check(actor.childNode(withName:"body",recursively:false)?.geometry?.firstMaterial?.name=="finish-cloth","Character clothing has a matte woven finish")
        check(actor.childNode(withName:"head",recursively:false)?.geometry?.firstMaterial?.name=="finish-enamel","Character faces remain smooth and readable")
    }
    var vaults=0
    scene.sculpture.enumerateChildNodes {node,_ in
        guard let geometry=node.geometry,!(geometry is SCNBox),!(geometry is SCNSphere),!(geometry is SCNCylinder),!(geometry is SCNCone),!(geometry is SCNTorus),!(geometry is SCNPlane),!(geometry is SCNCapsule),geometry.sources(for:.normal).first != nil else {return}
        if geometry.firstMaterial?.name=="finish-stone" {vaults+=1;check(geometry.firstMaterial?.lightingModel == .physicallyBased,"Vault meshes receive proper lighting instead of constant color")}
    }
    check(vaults>0 || world.structures.allSatisfy{$0.kind != .arch && $0.kind != .pavilion},"Stored arches have normal-mapped stone vaults")
    scene.update(world,beat:0,selected:nil,playing:true,atmosphereTime:4.65)
    let eye=scene.walkers[0].childNode(withName:"head",recursively:false)?.childNode(withName:"eye",recursively:false)
    check(eye != nil && Double(eye!.scale.y)<0.2,"Blink is an eyelid-scale expression, without moving the avatar collider")
    scene.update(world,beat:0,selected:nil,playing:false,atmosphereTime:5)
    check(Double(eye!.scale.y)>0.9,"Eyes reopen smoothly after a short blink")
    scene.walkers[0].eulerAngles.y+=1
    scene.update(world,beat:0,selected:nil,playing:false,atmosphereTime:5)
    check(abs(Double(scene.walkers[0].childNode(withName:"body",recursively:false)!.eulerAngles.z))>0.01 && scene.walkers[0].eulerAngles.z==0,"Torso anticipates turns without tilting the navigation root")
    check(scene.collisionFree,"Appearance updates preserve collision separation")
}
var waterWorld=World.blank
waterWorld.structures=[World.piece(.basin,x:0,y:0,z:0),World.piece(.waterfall,x:4,y:0,z:0)]
let water=GardenScene(waterWorld)
check(water.waterVisuals.count==2,"Basins and cascades have distinct animated water materials")
check(water.structureNodes.flatMap{$0.childNodes}.filter{["finish-water","finish-waterfall"].contains($0.geometry?.firstMaterial?.name ?? "")}.allSatisfy{!$0.castsShadow},"Transparent water does not cast opaque sheet shadows")
water.update(waterWorld,beat:0,selected:nil,playing:false,atmosphereTime:10)
let transforms=water.waterVisuals.map{$0.material.normal.contentsTransform.m42}
water.update(waterWorld,beat:0,selected:nil,playing:false,atmosphereTime:11)
check(zip(transforms,water.waterVisuals).allSatisfy{$0.0 != $0.1.material.normal.contentsTransform.m42},"Water keeps moving with music paused, including scenery-only worlds")
check(water.waterVisuals.allSatisfy{$0.foam?.categoryBitMask==64 && $0.material.writesToDepthBuffer==false},"Foam and translucent water avoid opaque depth occlusion")
let repeated=water.waterVisuals.map{$0.material.normal.contentsTransform.m42}
water.update(waterWorld,beat:0,selected:nil,playing:false,atmosphereTime:11)
check(water.waterVisuals.map{$0.material.normal.contentsTransform.m42}==repeated,"Water motion is deterministic for exported video")
let floorWorld=World.garden,t=floorWorld.tiles[0]
check(CharacterSpace.shadowFloor(SpacePoint(x:Double(t.x),y:Double(t.y)+2,z:Double(t.z)),world:floorWorld) != nil,"Airborne characters project shadows onto actual paths")
check(CharacterSpace.shadowFloor(SpacePoint(x:100,y:2,z:100),world:floorWorld)==nil,"Contact shadows disappear over empty space")
var instrumentWorld=World.blank
let kinds:[PadKind]=[.note,.drum,.harp,.wind,.wood,.rest]
instrumentWorld.tiles=kinds.enumerated().map{Tile(x:Float($0.offset)*1.4,y:1,z:0,note:60+$0.offset,kind:$0.element)}
instrumentWorld.voices=Voice.ensemble
for i in instrumentWorld.voices.indices {instrumentWorld.voices[i].enabled = i==0}
let instruments=GardenScene(instrumentWorld)
var tested=Set<PadKind>()
for event in instrumentWorld.events().filter({$0.voice==0}) {
    let kind=kinds[event.tile]
    guard !tested.contains(kind),[PadKind.note,.drum,.harp,.wind,.wood].contains(kind) else {continue}
    instruments.resetMotion();instruments.update(instrumentWorld,beat:event.beat+0.02,selected:nil,playing:true)
    let pad=instruments.pads[event.tile]
    check(pad.geometry!.firstMaterial!.emission.intensity>0,"Instrument response follows a sounding onset")
    if kind == .note {check(instruments.tileNodes[event.tile].childNodes.filter{$0.name=="pianoKey"}.allSatisfy{Double($0.position.y)<0.065},"Piano keys depress while sounding")}
    if kind == .drum {check(Double(pad.scale.y)<1,"Drum membrane compresses while sounding")}
    if kind == .wood {check(pad.geometry!.firstMaterial!.name=="finish-wood","Wood instruments retain a wood finish")}
    tested.insert(kind)
}
check(tested.count==5,"Every acoustic instrument family has an exercised visual response")
instruments.update(instrumentWorld,beat:0,selected:nil,playing:false)
check(instruments.pads.allSatisfy{$0.geometry!.firstMaterial!.emission.intensity==0},"Stopping playback clears instrument glow")
print("\(checks) shared surface, lighting, expression, shadow and animated-water checks passed.")

// Background dynamics use explicit time and spatial masks, independently of audio.
let waterUV=CGPoint(x:0.48,y:0.83)
check(AtmosphereLayer.flowUV(waterUV,environment:.sunset,time:0,panoramic:false) != AtmosphereLayer.flowUV(waterUV,environment:.sunset,time:2,panoramic:false),"Sunset photographic water develops animated wave motion")
let horizonUV=CGPoint(x:0.5,y:0.63)
check(AtmosphereLayer.flowUV(horizonUV,environment:.sunset,time:7,panoramic:false)==horizonUV,"Ocean horizon remains stable while the water moves")
let rockUV=CGPoint(x:0.5,y:0.91)
check(AtmosphereLayer.flowUV(rockUV,environment:.underwater,time:4,panoramic:false)==rockUV,"Central underwater rocks do not sway with plants")
let plantUV=CGPoint(x:0.17,y:0.45)
check(AtmosphereLayer.flowUV(plantUV,environment:.underwater,time:1,panoramic:false) != AtmosphereLayer.flowUV(plantUV,environment:.underwater,time:3,panoramic:false),"Underwater plant areas sway with the current")
let rootUV=CGPoint(x:0.15,y:1)
check(AtmosphereLayer.flowUV(rootUV,environment:.underwater,time:5,panoramic:false)==rootUV,"Vegetation stays anchored at the seabed boundary")
for environment in WorldEnvironment.allCases {
    for time in [0.0,1,27,1000] {
        for v in [0.0,0.1,0.3,0.6,0.8,1] {
            let left=AtmosphereLayer.flowUV(CGPoint(x:0,y:v),environment:environment,time:time,panoramic:false)
            let right=AtmosphereLayer.flowUV(CGPoint(x:1,y:v),environment:environment,time:time,panoramic:false)
            check(abs(right.x-left.x-1)<0.000001 && abs(right.y-left.y)<0.000001,"Animated photographic textures remain continuous across the wrap")
            check(left.x.isFinite && right.y>=0 && right.y<=1,"Background flow stays finite and vertically bounded")
        }
    }
}
for environment:WorldEnvironment in [.underwater,.sunset,.sky] {
    var world=World.blank;world.environment=environment
    let scene=GardenScene(world),layer=scene.atmosphere!
    scene.update(world,beat:0,selected:nil,playing:false,atmosphereTime:2)
    scene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:false)
    let before=layer.dome.geometry!.sources(for:.texcoord)[0].data
    scene.update(world,beat:0,selected:nil,playing:false,atmosphereTime:3)
    scene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:false)
    check(before != layer.dome.geometry!.sources(for:.texcoord)[0].data,"Photographic background keeps moving while music is paused")
    let repeated=layer.dome.geometry!
    scene.update(world,beat:0,selected:nil,playing:false,atmosphereTime:3)
    scene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:false)
    check(layer.dome.geometry === repeated,"Repeated export time and camera reuse the same deterministic geometry")
    check(layer.photo.isHidden && (layer.dome.geometry!.firstMaterial!.diffuse.contents as AnyObject) === layer.overviewImage,"Animated photography stays a direct native texture")
    if environment == .underwater {
        check(layer.sunRays.count==6 && layer.caustics.count==12,"Underwater lighting includes feathered sun shafts and seabed caustics")
        let angles=layer.sunRays.map(\.zRotation)
        layer.update(time:5)
        check(layer.sunRays.map(\.zRotation) != angles,"Surface ripples animate underwater sun-shaft angles")
    }
    if environment == .sunset {
        check(layer.glitter.count==40,"Ocean reflection consists of fragmented wave highlights")
        let positions=layer.glitter.map(\.position)
        scene.orbitYaw += 0.6
        scene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:false)
        check(layer.glitter.map(\.position) != positions,"Solar reflection responds to camera angle at the same animation time")
    }
    // Exercise the animated panoramic path with a walking character.
    var inhabited=World.garden;inhabited.environment=environment
    let eyeScene=GardenScene(inhabited)
    eyeScene.update(inhabited,beat:0,selected:nil,atmosphereTime:1)
    eyeScene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:true,voice:0,firstPerson:true)
    let first=eyeScene.atmosphere!.dome.geometry!.sources(for:.texcoord)[0].data
    eyeScene.update(inhabited,beat:0,selected:nil,atmosphereTime:2)
    eyeScene.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:true,voice:0,firstPerson:true)
    check(first != eyeScene.atmosphere!.dome.geometry!.sources(for:.texcoord)[0].data,"First-person panorama receives the same environment-specific flow")
    check(eyeScene.collisionFree,"Background animation adds no collision geometry")
}
print("\(checks) visual checks including environmental flow, sun shafts, vegetation, water glitter, camera response and deterministic export time passed.")
let sunHeading=(0.5-0.89)*2*Double.pi
let towards=AtmosphereLayer.solarSpecular(u:0.89,v:0.8,time:2,heading:sunHeading,pitch:0.2,panoramic:false)
let away=AtmosphereLayer.solarSpecular(u:0.89,v:0.8,time:2,heading:sunHeading+Double.pi,pitch:0.2,panoramic:false)
check(towards>away,"Solar highlight follows sun/view half-vector rather than a fixed painted brightness")
for angle in stride(from:-Double.pi,through:Double.pi,by:0.1) {
    let strength=AtmosphereLayer.solarSpecular(u:0.89,v:0.9,time:3,heading:angle,pitch:0.3,panoramic:false)
    check(strength.isFinite && strength>=0 && strength<=1,"Wave/Fresnel solar reflection remains bounded throughout camera orbit")
}
print("\(checks) visual checks including analytic camera-dependent solar reflection passed.")
