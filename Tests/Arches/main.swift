import Foundation
import SceneKit
var checks=0
func check(_ value:Bool,_ message:String) {guard value else {fatalError(message)};checks+=1}
for axis in [0,1] {for width in [0.83,1.55] {
    var world=World.blank;world.walkwayWidth=width;world.tempo=120;world.loopBars=4;world.routeSynchronized=true
    world.tiles=(0..<3).map{Tile(x:axis==0 ? Float($0) : 0,y:1,z:axis==1 ? Float($0) : 0,note:60,kind:$0==1 ? .transpose : .rest)}
    world.voices[0].enabled=true;world.voices[0].density=1;world.voices[0].offset=0;world.voices[0].rhythm = .quarters
    let scene=GardenScene(world)
    var hasRing=false,solidVaults=0
    scene.tileNodes[1].enumerateChildNodes {node,_ in
        if node.geometry is SCNTorus {hasRing=true}
        if node.name=="archSolid" {solidVaults+=1;check(node.categoryBitMask==16,"Collision proxies stay invisible to the camera")}
    }
    check(!hasRing && solidVaults==20,"Violet gate is an open arch with solid vault segments")
    let obstacles=Array(Mirror(reflecting:scene).children).first{$0.label=="obstacles"}!.value as! [SpaceObstacle]
    let center=SpacePoint(x:axis==0 ? 1 : 0,y:1.12,z:axis==1 ? 1 : 0)
    let body=SpaceBody(point:center,radius:0.35,height:1.1)
    check(!obstacles.contains{$0.intersects(body)},"Full character body fits through the opening")
    var roof=body;roof.point.y=2.85
    check(obstacles.contains{$0.intersects(roof)},"The vault is solid, not just its two columns")
    var crossing=false
    for tick in 1...600 {
        scene.update(world,beat:(Double(tick)/30).truncatingRemainder(dividingBy:world.loopBeats),selected:nil,playing:true)
        check(scene.collisionFree,"Walker clears arch pillars and roof in both route directions")
        let p=scene.walkers[0].position,along=axis==0 ? p.x : p.z
        if along>0.85 && along<1.15 {crossing=true}
    }
    check(crossing,"Walker actually crosses the opening instead of stopping outside")
}}
print("\(checks) open-gate passage, vault collision and camera-mask checks passed.")
