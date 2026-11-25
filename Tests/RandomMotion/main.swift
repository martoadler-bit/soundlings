import Foundation
import SceneKit
var checks=0
func check(_ value:Bool,_ message:String) {guard value else {fatalError(message)};checks+=1}
for seed:UInt64 in 0..<1000 {
    let world=World.generate(seed:seed)
    check(world.valid,"Valid coherent generation: seed \(seed)")
    let decoded=try! JSONDecoder().decode(World.self,from:world.encoded())
    check(decoded.walkwayWidth==world.walkwayWidth && decoded.routeSynchronized,"Wide synchronized routes survive sharing")
    check(world.structures.allSatisfy{world.sceneryClearsRoute($0)},"Scenery preserves walking corridor and drum plaza: seed \(seed)")
    check(world.mechanismsClear,"Moving mechanisms reserve a full turn against scenery: seed \(seed)")
    check(world.walkwayWidth>=1.5,"Promenade permits passing")
    let starts=[0,1,2].map {world.tiles[world.tileIndex(at:0,voice:$0)]}
    for i in starts.indices {for j in 0..<i {check(sqrt(pow(starts[i].x-starts[j].x,2)+pow(starts[i].y-starts[j].y,2)+pow(starts[i].z-starts[j].z,2))>1.5,"Walkers start in separate spaces: seed \(seed)")}}
}
for seed:UInt64 in 0..<30 {
    let world=World.generate(seed:seed),scene=GardenScene(world)
    var last=scene.walkers.map(\.position),travelled=[Double](repeating:0,count:6),still=[Int](repeating:0,count:6),longest=still
    check(scene.collisionFree,"Clear spawn: seed \(seed)")
    for voice in 0..<3 where world.voices[voice].enabled {
        let p=scene.walkers[voice].position
        let station=world.tiles[world.tileIndex(at:0,voice:voice)]
        check(abs(Double(p.y)-Double(station.y))<0.35,"No elevated emergency spawn: seed \(seed), voice \(voice)")
    }
    let frames=Int(ceil(world.loopBeats*60/world.tempo*60*2))
    for tick in 1...frames {
        let beat=(Double(tick)/60*world.tempo/60).truncatingRemainder(dividingBy:world.loopBeats)
        scene.update(world,beat:beat,selected:nil,playing:true)
        check(scene.collisionFree,"Clear ongoing motion: seed \(seed), tick \(tick)")
        for voice in 0..<3 where world.voices[voice].enabled {
            let p=scene.walkers[voice].position
            let distance=hypot(Double(p.x-last[voice].x),Double(p.z-last[voice].z))
            let dy=Double(p.y-last[voice].y)
            check(scene.transferredVoices.contains(voice) || hypot(distance,dy)<0.5,"Smooth movement through the loop boundary: seed \(seed), voice \(voice), tick \(tick)")
            travelled[voice]+=min(0.3,distance)
            still[voice]=distance<0.0001 && scene.walkers[voice].opacity>0.5 ? still[voice]+1 : 0
            longest[voice]=max(longest[voice],still[voice]);last[voice]=p
        }
    }
    for voice in 0..<3 where world.voices[voice].enabled {
        check(travelled[voice]>2,"Walker makes progress: seed \(seed), voice \(voice), distance \(travelled[voice])")
        check(longest[voice]<240,"No persistent trapping: seed \(seed), voice \(voice), stalled frames \(longest[voice])")
    }
}
var legacy=try! JSONSerialization.jsonObject(with:World.generate(seed:4).encoded()) as! [String:Any]
legacy.removeValue(forKey:"walkwayWidth");legacy.removeValue(forKey:"routeSynchronized")
let migrated=try! JSONDecoder().decode(World.self,from:JSONSerialization.data(withJSONObject:legacy))
check(migrated.walkwayWidth==0.83 && !migrated.routeSynchronized,"Existing saved worlds keep legacy route and width settings")
print("\(checks) coherent random-world corridor, spawn and sustained-motion checks passed.")
