import Foundation
import SceneKit
var checks=0
func check(_ condition:@autoclosure()->Bool,_ message:String) {guard condition() else {fatalError(message)};checks+=1}
for fps in [30.0,60.0,120.0] {
    var fade=PortalTransition(),values=[Double]()
    for frame in 0...Int(fps*2) {
        let time=Double(frame)/fps
        fade.update(seconds:1/fps,nextIn:time<1 ? 1-time : nil,waiting:false,transferred:frame==Int(fps))
        values.append(fade.alpha)
        check((0...1).contains(fade.alpha),"Bounded screen shade")
    }
    let peak=values.firstIndex(of:1)!
    check(values[..<peak].enumerated().dropFirst().allSatisfy{values[$0.offset-1]<=$0.element+1e-12},"One monotonic fade to black")
    check(values[peak...].enumerated().dropFirst().allSatisfy{values[peak+$0.offset-1]+1e-12 >= $0.element},"One monotonic reveal with no second black flash")
    check(values.last==0,"Complete single transition")
}
var chain=PortalTransition()
chain.update(seconds:1/60,nextIn:0.01,waiting:false,transferred:false)
chain.update(seconds:1/60,nextIn:0.12,waiting:false,transferred:true)
for _ in 0..<6 {chain.update(seconds:1/60,nextIn:0.05,waiting:false,transferred:false);check(chain.alpha==1,"No reveal between close portal transfers")}
chain.update(seconds:1/60,nextIn:nil,waiting:false,transferred:true)
var last=chain.alpha
for _ in 0..<30 {chain.update(seconds:1/60,nextIn:nil,waiting:false,transferred:false);check(chain.alpha<=last,"Portal chain reveals only once");last=chain.alpha}
var paused=PortalTransition();paused.update(seconds:1/60,nextIn:0.07,waiting:false,transferred:false)
let held=paused.alpha
paused.update(seconds:0,nextIn:nil,waiting:false,transferred:false)
check(paused.alpha==held,"Pause does not restart a fade")
// The real scene uses onset-to-onset travel time, independent of the note's gate length.
for gate in [0.15,1.5] {
    var world=World.blank;world.voices[0].enabled=true;world.tempo=120;world.loopBars=4
    world.tiles=[Tile(x:0,y:1,z:0,note:60),Tile(x:5,y:1,z:0,note:62),Tile(x:6,y:1,z:0,note:64)]
    world.voices[0].rhythm = .halves;world.voices[0].density=1;world.voices[0].gate=gate;world.voices[0].offset=0
    let scene=GardenScene(world)
    var envelope=[Double](),transfers=0
    for frame in 0...108 {
        let beat=Double(frame)/60*world.tempo/60
        scene.update(world,beat:beat,selected:nil,playing:true)
        let alpha=Double(scene.portalShade(for:0));envelope.append(alpha)
        check(abs(alpha-(1-Double(scene.walkers[0].opacity)))<0.000001,"Viewport/export shade uses the same single envelope as the avatar")
        if scene.transferredVoices.contains(0) {transfers+=1;check(alpha==1,"Camera relocates only while fully covered")}
    }
    check(transfers==1,"One actual portal transfer in fixture")
    check(envelope[0..<45].allSatisfy{$0==0},"No premature fade based on sound duration")
    check(envelope.last==0,"Scene reveals normally after transfer")
    let peak=envelope.firstIndex(of:1)!
    check(envelope[peak...].enumerated().dropFirst().allSatisfy{envelope[peak+$0.offset-1]+1e-12 >= $0.element},"Production scene never double-fades after arrival")
}
print("\(checks) single portal-envelope and production scene transition checks passed.")
