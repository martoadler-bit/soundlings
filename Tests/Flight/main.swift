import Foundation
import SceneKit
var checks=0
func check(_ condition:@autoclosure()->Bool,_ message:String) {guard condition() else {fatalError(message)};checks+=1}
let roof=SpaceObstacle(min:SpacePoint(x:-1,y:2,z:-1),max:SpacePoint(x:1,y:3,z:1))
let start=FlightSpace.hover(SpacePoint(x:0,y:1,z:0),radius:0.4,obstacles:[roof])
check(start.y>roof.max.y,"A hovering creature begins above the roof, not inside it")
let wall=SpaceObstacle(min:SpacePoint(x:1,y:0,z:-1),max:SpacePoint(x:3,y:5,z:1))
let origin=SpacePoint(x:0,y:1,z:0),target=SpacePoint(x:5,y:1,z:0)
let path=FlightSpace.path(from:origin,to:target,radius:0.4,obstacles:[wall])
for i in 1..<path.points.count {for frame in 0...60 {
    let a=path.points[i-1],b=path.points[i],t=Double(frame)/60
    let point=SpacePoint(x:a.x+(b.x-a.x)*t,y:a.y+(b.y-a.y)*t,z:a.z+(b.z-a.z)*t)
    check(!wall.intersects(SpaceBody(point:point,radius:0.4,height:0.95,floating:true)),"Entire flight clears a wall without passing through it")
}}
let navigation=FlightNavigation()
var point=origin,maxHeight=point.y
for _ in 0..<900 {
    let next=navigation.advance(voice:0,current:point,target:target,radius:0.4,seconds:1/60,obstacles:[wall])
    check(hypot(next.distance(point),next.y-point.y)<=2.8/60+0.00001,"Flight has bounded continuous speed")
    check(!wall.intersects(SpaceBody(point:next,radius:0.4,height:0.95,floating:true)),"Navigator never collides with architecture")
    maxHeight=max(maxHeight,next.y);point=next
}
check(maxHeight>5 && point.distance(target)<0.02 && abs(point.y-target.y)<0.02,"Flight climbs over the wall and returns to its destination")
var randomPortals=0
for seed:UInt64 in 0..<200 {
    let world=World.generate(seed:seed)
    let links=world.tiles.indices.filter{world.requiresPortalLink(from:$0,to:($0+1)%world.tiles.count)}.count
    randomPortals+=links
    check(links<=1,"Random keeps at most one portal link: seed \(seed), \(world.architecture), count \(links)")
}
// A skipped silent station does not create a portal on an otherwise connected route.
var line=World.blank;line.tiles=(0..<8).map{Tile(x:Float($0),y:1,z:0,note:60)}
check(!line.isPortal(from:0,to:5),"Walking several connected steps is not teleporting")
line.reversed=true
check(!line.isPortal(from:5,to:0),"Reverse walking uses the same continuous path")
// Production floating characters keep collider clearance, and never enter portal transitions.
var world=World.blank
world.tiles=[Tile(x:0,y:1,z:0,note:60),Tile(x:6,y:1,z:0,note:64),Tile(x:6,y:1,z:3,note:67)]
for i in world.voices.indices {world.voices[i].enabled=[.pad,.drone].contains(world.voices[i].role)}
world.voices[3].offset=0;world.voices[4].offset=0
var column=World.piece(.column,x:3,y:0,z:0);column.width=1;column.depth=2;column.height=5
world.structures=[column]
let scene=GardenScene(world)
var last=scene.walkers.map(\.position)
for frame in 1...900 {
    let beat=(Double(frame)/60*world.tempo/60).truncatingRemainder(dividingBy:world.loopBeats)
    scene.update(world,beat:beat,selected:nil,playing:true)
    check(scene.collisionFree,"Production airborne bodies clear architecture and each other")
    for i in [3,4] {
        check(!scene.transferredVoices.contains(i) && scene.portalShade(for:i)==0,"Floating characters fly through gaps without portal blackouts")
        let p=scene.walkers[i].position,old=last[i]
        check(sqrt(pow(Double(p.x-old.x),2)+pow(Double(p.y-old.y),2)+pow(Double(p.z-old.z),2))<0.25,"Air motion never snaps")
        last[i]=p
    }
}
var ringWorld=World.blank;ringWorld.tiles=[Tile(x:0,y:1,z:0,note:60)]
for i in ringWorld.voices.indices {ringWorld.voices[i].enabled=ringWorld.voices[i].role == .drone}
ringWorld.structures=[World.piece(.orbit,x:0,y:1,z:0)]
let ringScene=GardenScene(ringWorld),ring=ringScene.structureNodes[0]
let top=ring.convertPosition(ring.boundingBox.max,to:ringScene.sculpture)
check(ringScene.walkers[3].position.y>top.y,"Hovering clears thin decorative rings as well as solid boxes")
print("\(checks) flight, clearance and reduced-portal checks passed; \(randomPortals) portal links across 200 random worlds.")
