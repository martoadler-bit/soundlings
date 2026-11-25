// Only the platform audio/video services are substituted; tests compile the production Game and builder controller.
import Foundation
struct VideoCamera {var follow:Bool;var firstPerson:Bool;var voice:Int;var yaw:Double;var rotation:Float;var zoom:Double;var pan:CGPoint;var frontView=false}
struct SharedMovie:Identifiable {let id=UUID();let url:URL}
enum VideoExporter {
    static func render(world:World,camera:VideoCamera,duration:MovieDuration = .loop,edit:MovieEditPlan?=nil,progress:@escaping @Sendable(Double)->Void) async throws ->URL {throw CocoaError(.featureUnsupported)}
}
final class MusicEngine {
    var prepared=false
    var beat:Double=0
    var stops=0
    var toggles=0
    func prepare(_ rendered:[RenderedLoop],enabled:[Bool])throws {prepared=true}
    func setVoiceEnabled(_ index:Int,_ enabled:Bool) {toggles+=1}
    func play() {}
    func pause() {}
    func stop() {stops+=1;prepared=false;beat=0}
}
