import Foundation
import SceneKit
import AVFoundation
var checks=0
func check(_ condition:@autoclosure()->Bool,_ message:String) {guard condition() else {fatalError(message)};checks+=1}
for index in 0..<3300 {
    check(OceanLoop.frame(at:Double(index)/30)==index%330,"Movie frame clock wraps at exactly 330 frames")
}
check(OceanLoop.frame(at:Double.nan)==0 && OceanLoop.frame(at:-1)==0,"Invalid movie timestamps cannot create invalid frames")
let garden=GardenScene(World.garden),layer=garden.atmosphere!
garden.camera.position=SCNVector3Zero;garden.camera.eulerAngles=SCNVector3Zero
garden.camera.camera!.usesOrthographicProjection=true;garden.camera.camera!.orthographicScale=10
layer.dome.position=SCNVector3Zero;layer.dome.eulerAngles=SCNVector3Zero;layer.dome.scale=SCNVector3(12,12,12)
func u(_ source:SCNGeometrySource,_ index:Int)->Float {source.data.withUnsafeBytes{$0.loadUnaligned(fromByteOffset:source.dataOffset+source.dataStride*index,as:Float.self)}}
for turn in [0.0,Double.pi/2,Double.pi,Double.pi*1.5] {
    garden.camera.eulerAngles.y=SceneScalar(turn)
    layer.projectOcean(camera:garden.camera,viewport:CGSize(width:393,height:852),radius:12)
    let uv=layer.dome.geometry!.sources(for:.texcoord)[0]
    let center=u(uv,24*65+32)
    var delta=Double(center)-turn/(2*Double.pi);delta -= delta.rounded()
    check(abs(delta)<0.00001,"A quarter camera turn samples exactly a quarter of the true spherical video")
    check(u(uv,24*65+64)<u(uv,24*65),"Ocean video orientation matches the inside-facing sphere")
}
print("\(checks) ocean clock and world-bearing projection checks passed.")
if ProcessInfo.processInfo.environment["SOUNDLINGS_DECODE_VIDEO"] == "1" {
    guard let movie=OceanMovie.bundled() else {fatalError("Bundled movie missing")}
    do {try await movie.prepareForExport()} catch {
        print("Native AVFoundation decoding unavailable in this execution environment: \(error)")
        exit(1)
    }
    let first=movie.content(at:0) as! CGImage
    check(first.width==3840 && first.height==1920,"Native offline decoding preserves pilot dimensions")
    let next=movie.content(at:1.0/30) as! CGImage
    check((movie.content(at:1.0/30) as! CGImage) === next,"Split-screen views share the exact same decoded frame")
    _=movie.content(at:10.9666666667)
    let wrap=movie.content(at:11) as! CGImage
    check((first.dataProvider!.data! as Data)==(wrap.dataProvider!.data! as Data),"Offline decoding wraps to exactly the same first frame")
    check(movie.failure==nil,"Offline video decoding completes without errors")
    print("Native sequential AVFoundation decode, frame reuse and loop reset passed.")
}
