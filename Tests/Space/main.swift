import Foundation
var checks=0
func check(_ value:Bool,_ message:String) {if !value {fatalError(message)};checks+=1}
var world=World.garden
let tile=world.tiles[0],origin=SpacePoint(x:Double(tile.x),y:Double(tile.y),z:Double(tile.z))
let bodies=(0..<6).map{_ in SpaceBody(point:origin,radius:0.2,height:0.8)}
let obstacle=SpaceObstacle(min:SpacePoint(x:origin.x-0.1,y:origin.y,z:origin.z-0.1),max:SpacePoint(x:origin.x+0.1,y:origin.y+1,z:origin.z+0.1))
let result=CharacterSpace.resolve(bodies,previous:[],world:world,obstacles:[obstacle])
for i in result.indices {
    var a=bodies[i];a.point=result[i]
    check(!obstacle.intersects(a),"Actors avoid solid objects")
    for j in 0..<i {var b=bodies[j];b.point=result[j];check(!CharacterSpace.intersects(a,b),"Crowded actors remain separate")}
}
check(!CharacterSpace.supported(SpaceBody(point:SpacePoint(x:100,y:0,z:100),radius:0.2,height:0.8),world:world),"Cannot walk off a ledge")
for seed:UInt64 in 0..<30 {
    world=World.generate(seed:seed)
    let plan=world.plan()
    var previous=[SpacePoint]()
    for tick in 0..<128 {
        let beat=Double(tick)/4
        var wanted=[SpaceBody]()
        for i in world.voices.indices where world.voices[i].enabled {
            let motion=plan.motion(voice:i,beat:beat,fallback:world.tileIndex(at:0,voice:i))
            let a=world.tiles[motion.tile],b=world.tiles[motion.nextTile],t=world.isPortal(from:motion.tile,to:motion.nextTile) ? 0 : motion.progress
            let role=world.voices[i].role,flight=role == .pad ? 0.95 : role == .drone ? 1.75 : 0
            wanted.append(SpaceBody(point:SpacePoint(x:Double(a.x)+Double(b.x-a.x)*t,y:Double(a.y)+Double(b.y-a.y)*t+flight,z:Double(a.z)+Double(b.z-a.z)*t),radius:role == .percussion ? 0.49 : 0.23,height:0.95,floating:flight>0))
        }
        let placed=CharacterSpace.resolve(wanted,previous:previous,world:world,obstacles:[]);previous=placed
        for i in placed.indices {
            var a=wanted[i];a.point=placed[i]
            check(a.point.x.isFinite && a.point.y.isFinite && a.point.z.isFinite,"Finite pose")
            for j in 0..<i {var b=wanted[j];b.point=placed[j];check(!CharacterSpace.intersects(a,b),"No pair penetrations across generated routes")}
        }
    }
}
print("\(checks) collision checks passed.")
