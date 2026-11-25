import Foundation
import SceneKit
var checks=0
func check(_ value:Bool,_ message:String) {guard value else {fatalError(message)};checks+=1}
for world in [World.garden,World.moon,World.generate(seed:8)] {
    check(world.mechanismsClear,"Preset moving geometry clears all scenery and paths")
    let scene=GardenScene(world)
    for phase in 0..<24 {
        scene.update(world,beat:Double(phase)/24*world.loopBeats,selected:nil,playing:true)
        for index in world.structures.indices where world.structures[index].moving && world.structures[index].enabled {
            let bounds=world.structures[index].envelope,root=scene.structureNodes[index]
            root.enumerateChildNodes {node,_ in
                guard let source=node.geometry?.sources(for:.vertex).first,source.bytesPerComponent==4,source.componentsPerVector>=3 else {return}
                source.data.withUnsafeBytes {data in
                    var low=[Float](repeating:Float.infinity,count:3),high=[Float](repeating:-Float.infinity,count:3)
                    for vertex in 0..<source.vectorCount {for axis in 0..<3 {
                        let value=data.loadUnaligned(fromByteOffset:source.dataOffset+vertex*source.dataStride+axis*4,as:Float.self)
                        low[axis]=min(low[axis],value);high[axis]=max(high[axis],value)
                    }}
                    let box=node.geometry!.boundingBox
                    func scaled(_ value:Float,_ axis:Int)->Float {
                        let a=[Float(box.min.x),Float(box.min.y),Float(box.min.z)][axis],b=[Float(box.max.x),Float(box.max.y),Float(box.max.z)][axis]
                        return a+(value-low[axis])/max(0.00001,high[axis]-low[axis])*(b-a)
                    }
                    for vertex in stride(from:0,to:source.vectorCount,by:3) {
                        let base=source.dataOffset+vertex*source.dataStride
                        let x=data.loadUnaligned(fromByteOffset:base,as:Float.self),y=data.loadUnaligned(fromByteOffset:base+4,as:Float.self),z=data.loadUnaligned(fromByteOffset:base+8,as:Float.self)
                        let point=node.convertPosition(SCNVector3(scaled(x,0),scaled(y,1),scaled(z,2)),to:scene.sculpture)
                        check(Double(point.x)>=bounds.minX-0.001 && Double(point.x)<=bounds.maxX+0.001 && Double(point.y)>=bounds.minY-0.001 && Double(point.y)<=bounds.maxY+0.001 && Double(point.z)>=bounds.minZ-0.001 && Double(point.z)<=bounds.maxZ+0.001,"Animated vertices stay inside the reserved full-turn envelope: \(world.structures[index]), phase \(phase), point \(point), bounds \(bounds)")
                    }
                }
            }
        }
    }
}
var home=World.garden
let homeScene=GardenScene(home),stage=home.percussionStage()
check(abs(Double(homeScene.walkers[5].position.x)-Double(stage.x))<0.01 && abs(Double(homeScene.walkers[5].position.z)-Double(stage.z))<0.01,"Initial drummer stands at the dedicated stage")
check(homeScene.sculpture.childNode(withName:"drumStageRoot",recursively:false) != nil,"Home stage exists before playback")
home.voices[5].enabled=false;homeScene.rebuild(home)
check(homeScene.sculpture.childNode(withName:"drumStageRoot",recursively:false)!.isHidden,"Disabled initial drummer hides its prepared stage")
home.voices[5].enabled=true;homeScene.update(home,beat:1,selected:nil)
check(!homeScene.sculpture.childNode(withName:"drumStageRoot",recursively:false)!.isHidden,"Enabling drummer reveals the stage without rebuilding or restarting")
var custom=World.blank;custom.tiles=[Tile(x:0,y:1,z:0,note:60)]
check(custom.percussionStage().x==0 && custom.percussionStage().y==1,"Existing narrow custom stage behavior is preserved")
var overlap=World.blank;overlap.structures=[World.piece(.gear),World.piece(.column)]
check(!overlap.mechanismsClear,"Full-turn overlap is detected before placement")
overlap.repairMechanisms()
check(overlap.mechanismsClear && overlap.structures[0].enabled,"Legacy overlapping wheel is relocated to an enabled clear position")
let decoded=try! JSONDecoder().decode(World.self,from:overlap.encoded())
check(decoded.structures==overlap.structures,"Repaired wheel positions persist exactly")
print("\(checks) full-turn vertex, mechanism separation and initial-stage checks passed.")
