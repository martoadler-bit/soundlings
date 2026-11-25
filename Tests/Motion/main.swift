import Foundation
import SceneKit
var checks=0, timings=[Double]()
func check(_ condition:Bool,_ message:String) {if !condition {fatalError(message)};checks+=1}
// Deliberately move a target through a solid wall: continuous motion must wait/slide,
// never jump to the other side or be ejected upward.
var world=World.blank
world.tiles=(0..<4).map{Tile(x:Float($0),y:1,z:0,note:60)}
let t=world.tiles[0],point=CharacterSpace.grounded(SpacePoint(x:Double(t.x),y:Double(t.y),z:Double(t.z)),radius:0.2,world:world)
var bodies=[SpaceBody(point:point,radius:0.2,height:0.8)]
var poses=[point]
let wall=SpaceObstacle(min:SpacePoint(x:point.x+0.3,y:point.y,z:point.z-1),max:SpacePoint(x:point.x+0.5,y:point.y+2,z:point.z+1))
for frame in 0..<180 {
    bodies[0].point.x=point.x+Double(frame)/60
    let next=CharacterSpace.advance(bodies,previous:poses,world:world,obstacles:[wall],maxStep:0.04,portals:[])
    let dx=next[0].x-poses[0].x,dy=next[0].y-poses[0].y,dz=next[0].z-poses[0].z
    check(sqrt(dx*dx+dy*dy+dz*dz)<=0.040001,"Bounded 3D motion")
    var collider=bodies[0];collider.point=next[0]
    check(!wall.intersects(collider),"Swept wall clearance")
    check(abs(next[0].y-point.y)<0.00001,"No upward collision teleport")
    poses=next
}
// Raised landings must remain traversable in both directions, including a late
// musical target. Check progress as well as clearance; merely waiting is not a pass.
for reverse in [false,true] {
    var stairs=World.blank
    stairs.tiles=[Tile(x:0,y:1,z:0,note:60),Tile(x:1,y:1.5,z:0,note:62),Tile(x:2,y:2,z:0,note:64)]
    let blocks=stairs.tiles.map {tile in SpaceObstacle(min:SpacePoint(x:Double(tile.x)-0.47,y:Double(tile.y)-0.24,z:-0.47),max:SpacePoint(x:Double(tile.x)+0.47,y:Double(tile.y),z:0.47),walkSurface:true)}
    var positions=[SpacePoint(x:reverse ? 2 : 0,y:reverse ? 2 : 1,z:0)]
    let navigation=NavigationMemory()
    for frame in 1...400 {
        let x=reverse ? max(0,2-Double(frame)/120) : min(2,Double(frame)/120)
        var actor=SpaceBody(point:SpacePoint(x:x,y:1+x*0.5,z:0),radius:0.2,height:0.95)
        let next=CharacterSpace.advance([actor],previous:positions,world:stairs,obstacles:blocks,maxStep:0.04,portals:[],memory:navigation)
        actor.point=next[0]
        check(!blocks.contains{$0.intersects(actor)},"Ascending/descending body never clips a raised step")
        check(sqrt(pow(next[0].x-positions[0].x,2)+pow(next[0].y-positions[0].y,2)+pow(next[0].z-positions[0].z,2))<0.041,"Step motion remains bounded")
        positions=next
    }
    check(abs(positions[0].x-(reverse ? 0 : 2))<0.1,"Character completes stairs instead of remaining stuck")
}
var corner=World.blank
corner.tiles=[Tile(x:0,y:1,z:0,note:60),Tile(x:1,y:1,z:0,note:60),Tile(x:1,y:1,z:1,note:60),Tile(x:2,y:1,z:1,note:60)]
var cornerPosition=[SpacePoint(x:0,y:1,z:0)]
let cornerMemory=NavigationMemory()
for _ in 0..<240 {
    cornerPosition=CharacterSpace.advance([SpaceBody(point:SpacePoint(x:1.8,y:1,z:1),radius:0.2,height:0.95)],previous:cornerPosition,world:corner,obstacles:[],maxStep:0.04,portals:[],memory:cornerMemory)
}
check(cornerPosition[0].distance(SpacePoint(x:1.8,y:1,z:1))<0.1,"A late walker follows intermediate corners instead of cutting across empty space and stalling")
// Render two real loop boundaries at 60 Hz. Check body displacement, collisions,
// visibility around portals and camera framing stability, using production scenes.
for world in [World.garden,World.moon,World.generate(seed:42,architecture:.spiral)] {
    let scene=GardenScene(world),plan=world.plan()
    var last=scene.walkers.map(\.position), previousTiles=world.voices.indices.map{plan.motion(voice:$0,beat:0,fallback:0).tile}
    var travelled=Array(repeating:0.0,count:world.voices.count)
    var gearAngles=scene.gears.map{Double($0.eulerAngles.y)}
    let bounds=scene.boundsMax,frames=Int(world.loopBeats*60/world.tempo*60*2)
    for frame in 1...frames {
        let beat=(Double(frame)/60*world.tempo/60).truncatingRemainder(dividingBy:world.loopBeats)
        let start=Date()
        scene.update(world,beat:beat,selected:nil,playing:true)
        timings.append(Date().timeIntervalSince(start)*1000)
        check(scene.collisionFree,"Frame-by-frame production collision clearance")
        check(scene.boundsMax.y==bounds.y,"No camera reframing caused by collision correction")
        for i in scene.gears.indices {
            let angle=Double(scene.gears[i].eulerAngles.y),difference=atan2(sin(angle-gearAngles[i]),cos(angle-gearAngles[i]))
            check(abs(difference)<0.1,"Gears turn continuously through loop seams")
            gearAngles[i]=angle
        }
        for i in scene.walkers.indices where world.voices[i].enabled {
            let motion=plan.motion(voice:i,beat:beat,fallback:0),p=scene.walkers[i].position
            let portal=world.isPortal(from:previousTiles[i],to:motion.tile)
            let delta=sqrt(pow(Double(p.x-last[i].x),2)+pow(Double(p.y-last[i].y),2)+pow(Double(p.z-last[i].z),2))
            // Portal transfers are allowed; ordinary stepping, including loop seams, is bounded.
            if !portal && !scene.transferredVoices.contains(i) && delta>0.5 {check(false,"Unexpected motion jump: role \(i), frame \(frame), delta \(delta)")}
            if !portal && !scene.transferredVoices.contains(i) {travelled[i]+=delta}
            if scene.transferredVoices.contains(i) {check(scene.walkers[i].opacity==0,"Portal transfer hidden until fade-in")}
            previousTiles[i]=motion.tile;last[i]=p
        }
    }
    for i in world.voices.indices where world.voices[i].enabled && [.melody,.arpeggio,.bass].contains(world.voices[i].role) {
        check(travelled[i]>2,"Avoidance must still allow walking progress: \(world.name), role \(i), distance \(travelled[i])")
    }
}
timings.sort()
print("\(checks) temporal motion checks passed; scene update median \(timings[timings.count/2]) ms, p95 \(timings[timings.count*95/100]) ms on this Mac (CPU only).")
