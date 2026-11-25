import Foundation
var checks=0
func check(_ condition:@autoclosure()->Bool,_ message:String) {
    guard condition() else { fatalError(message) }; checks+=1
}
func fingerprint(_ world:World)->String {
    world.events().map { "\($0.beat):\($0.duration):\($0.tile):\($0.voice):\($0.notes):\($0.hit):\($0.velocity):\(String(describing:$0.filterCutoff)):\($0.arpOctaves)" }.joined(separator:"|")
}
let garden=World.garden, moon=World.moon
check(garden.valid && moon.valid,"Valid presets")
check(garden.architecture != moon.architecture && garden.palette != moon.palette && garden.keyName != moon.keyName,"Distinct preset identities")
var architectures=Set<Architecture>(), palettes=Set<WorldPalette>(), keys=Set<Int>(), timbres=Set<Timbre>()
for seed:UInt64 in 0..<200 {
    let world=World.generate(seed:seed)
    check(world.valid,"Valid generation \(seed)")
    check(try! world.encoded()==World.generate(seed:seed).encoded(),"Deterministic seed")
    let decoded=try! JSONDecoder().decode(World.self,from:world.encoded())
    check(fingerprint(world)==fingerprint(decoded),"Share/import reproduces events")
    check(world.voices.filter(\.enabled).count>=4,"Random enables at least four roles")
    architectures.insert(world.architecture);palettes.insert(world.palette);keys.insert(world.root)
    world.voices.forEach { timbres.insert($0.timbre) }
    check(world.stayInScale,"Random always locks its common mode")
    let plan=world.plan()
    for event in plan.events {
        for note in event.notes {check(world.scale.intervals.contains(((note-world.root)%12+12)%12),"Every generated instrument shares the world mode: seed \(seed), voice \(event.voice), note \(note)")}
        check(event.beat>=0 && event.beat<world.loopBeats && event.duration>0,"Bounded event time")
        let motion=plan.motion(voice:event.voice,beat:event.beat,fallback:0)
        check(motion.tile==event.tile && motion.age<0.000001,"Visible arrival equals audio onset")
    }
}
check(architectures.count==Architecture.allCases.count && palettes.count==5 && keys.count==12 && timbres.count==Timbre.allCases.count,"Random explores architecture, color, key and timbres")
check(garden.events().contains{$0.beat != $0.beat.rounded()},"Fractional rhythms")
check(garden.events().contains{$0.duration>4},"Sustained pad")
check(Set(garden.events().filter{$0.voice==5}.map(\.hit)).count>=3,"Multiple percussion articulations")
var changed=garden; changed.progression=[6,5,4,3]
check(garden.events().filter{$0.hit == .drone}.map(\.notes)==changed.events().filter{$0.hit == .drone}.map(\.notes),"Pedal independent of harmony")
var legacy=try! JSONSerialization.jsonObject(with:garden.encoded()) as! [String:Any]
legacy.removeValue(forKey:"schemaVersion")
legacy["voices"]=[["name":"Azure","offset":0,"gain":0.5,"enabled":true]]
let migrated=try! JSONDecoder().decode(World.self,from:JSONSerialization.data(withJSONObject:legacy))
check(migrated.valid && migrated.voices.count==6,"Old saved worlds migrate")
for tempo in [60.0,137.0,160.0] {
    var world=garden;world.tempo=tempo;world.loopBars=4
    let loop=LoopRenderer.render(world)
    check(loop.left.count==Int((world.loopBeats*48000*60/tempo).rounded()),"Exact frame count")
    check(zip(loop.left,loop.right).allSatisfy{$0.isFinite && $1.isFinite && abs($0)<1 && abs($1)<1},"Finite limited output")
    check(loop.events.allSatisfy{abs(($0.beat*loop.beatFrames).rounded()-$0.beat*loop.beatFrames)<=0.500001},"Onsets within half sample")
    check(loop.left.contains{abs($0)>0.05},"Audible signal")
    check(LoopRenderer.wav(loop).count==44+loop.left.count*4,"Complete stereo WAV")
}
var isolated=garden;isolated.loopBars=4;isolated.echo=0
for i in isolated.voices.indices { isolated.voices[i].enabled=false }
check(LoopRenderer.render(isolated).left.allSatisfy{$0==0},"Muted world silent")
isolated.voices[3].enabled=true
let drone=LoopRenderer.render(isolated)
check(abs(drone.left.first!-drone.left.last!)<0.003,"Pedal loop seam continuous")
for start in stride(from:0,to:drone.left.count-4800,by:4800) {
    check(drone.left[start..<start+4800].contains{abs($0)>0.01},"Pedal never falls silent")
}
isolated.voices[3].enabled=false;isolated.voices[0].enabled=true
let bell=LoopRenderer.render(isolated)
isolated.voices[0].timbre = .reed
let reed=LoopRenderer.render(isolated)
check(zip(bell.left,reed.left).contains{abs($0-$1)>0.01},"Timbres create different waveforms")
var single=garden;single.loopBars=4;single.echo=0;single.swing=0;single.reversed=false
for i in single.voices.indices {single.voices[i].enabled=i==0}
single.voices[0].offset=0;single.voices[0].density=1;single.voices[0].rhythm = .quarters
for i in single.tiles.indices {single.tiles[i].enabled=i==3;single.tiles[i].kind = .note}
let one=LoopRenderer.render(single), onset=Int((3*one.beatFrames).rounded())
check(one.events.count==1 && one.events[0].beat==3,"Isolated fractional scheduler route")
check(one.left[..<onset].allSatisfy{$0==0},"No premature audio before scheduled onset")
check(one.left[onset..<onset+4800].contains{abs($0)>0.01},"Scheduled note actually renders at its onset")
var invalid=garden;invalid.tempo = .nan
check(!invalid.valid,"Reject nonfinite tempo")
invalid=garden;invalid.voices[0].timbre = .warmPad
check(!invalid.valid,"Reject incompatible timbre")
invalid=garden;invalid.schemaVersion=99
check(!invalid.valid,"Reject future schema without migration")
// Instrument surfaces must actually change sound, preserve event times and round-trip.
var variants=[[Float]]()
for kind:PadKind in [.harp,.wind,.wood] {
    var instrument=single;instrument.tiles[3].kind=kind
    let audio=LoopRenderer.render(instrument)
    check(audio.events.map(\.beat)==one.events.map(\.beat),"Instrument changes preserve scheduling")
    check(audio.left[..<onset].allSatisfy{$0==0},"New instruments never sound early")
    check(audio.left.allSatisfy{$0.isFinite && abs($0)<1},"Instrument output is finite")
    check((try! JSONDecoder().decode(World.self,from:instrument.encoded())).tiles[3].kind==kind,"Instrument round trip")
    variants.append(audio.left)
}
for i in 0..<variants.count {for j in 0..<i {
    check(zip(variants[i],variants[j]).contains{abs($0-$1)>0.01},"Material families have distinct audio")
}}
// Boundaries, octave registers and arbitrary shifts must not escape the selected mode.
for scale in MusicalScale.allCases {for root in 0..<12 {
    var world=World.blank;world.scale=scale;world.root=root
    for note in stride(from:12,through:120,by:3) {for shift in [-12,-7,-1,0,1,5,7,12] {
        let pitch=world.arrangedPitch(note,transpose:shift)
        check((24...108).contains(pitch) && scale.intervals.contains(((pitch-root)%12+12)%12),"Modal pitch at MIDI bounds")
    }}
}}
for root in 0..<12 {
    var pedal=World.blank;pedal.root=root
    for octave in [-24,-12,0,12,24] {check(pedal.arrangedPitch(36+root+octave)%12==root,"Pedal keeps the tonic even at register bounds")}
}
var chromatic=World.blank;chromatic.tiles=[Tile(x:0,y:1,z:0,note:60,kind:.chord)]
chromatic.voices[0].enabled=true
chromatic.tiles[0].quality = .minor
check(chromatic.events().flatMap(\.notes).allSatisfy{chromatic.scale.intervals.contains($0%12)},"Diatonic chord overrides a conflicting minor triad in C major")
chromatic.stayInScale=false
check(chromatic.events().flatMap(\.notes).contains(63),"Explicit chromatic mode keeps a chosen minor third")
let chromaticRoundTrip=try! JSONDecoder().decode(World.self,from:chromatic.encoded())
check(!chromaticRoundTrip.stayInScale,"Chromatic opt-out survives sharing")
var legacyScale=try! JSONSerialization.jsonObject(with:chromatic.encoded()) as! [String:Any]
legacyScale.removeValue(forKey:"stayInScale")
check((try! JSONDecoder().decode(World.self,from:JSONSerialization.data(withJSONObject:legacyScale))).stayInScale,"Existing worlds default to the common mode")
// Coral's floor controls are persistent musical modifiers, not cosmetic labels.
var arp=World.blank;arp.tiles=(0..<12).map{Tile(x:Float($0),y:1,z:0,note:60)}
for i in arp.voices.indices {arp.voices[i].enabled=arp.voices[i].role == .arpeggio}
arp.loopBars=4;arp.swing=0;arp.echo=0;arp.progression=[0,0,0,0]
arp.voices[1].offset=0;arp.voices[1].rhythm = .eighths;arp.voices[1].density=1;arp.voices[1].gate=0.4;arp.voices[1].pattern=0
arp.tiles[1].kind = .filter;arp.tiles[1].filterCutoff=0
arp.tiles[2].kind = .octave;arp.tiles[2].arpOctaves=3
arp.tiles[4].kind = .filter;arp.tiles[4].filterCutoff=1
let arpEvents=arp.events()
check(arpEvents[0].filterCutoff==nil && arpEvents[0].arpOctaves==1,"Arpeggio starts without an activated modifier")
check(arpEvents[1].filterCutoff==150 && arpEvents[3].filterCutoff==150,"Filter persists after leaving its pad")
check(arpEvents[4].filterCutoff==12000,"Next filter changes the cutoff")
check(arpEvents[2].arpOctaves==3 && arpEvents[3].arpOctaves==3,"Octave bloom expands following arpeggio steps")
check(arpEvents.prefix(10).flatMap(\.notes).max()!>=96,"Three-octave arpeggio reaches the expanded register")
let arpPlan=arp.plan(),visible=arpPlan.motion(voice:1,beat:arpEvents[2].beat,fallback:0)
check(visible.arpOctaves==3 && visible.filterCutoff==150,"Visible character modifier state is exactly the audio event state")
check((try! JSONDecoder().decode(World.self,from:arp.encoded())).tiles[2].arpOctaves==3,"Floor modifiers survive world sharing")
var low=arp,high=arp
for i in low.tiles.indices {low.tiles[i].kind = .filter;low.tiles[i].filterCutoff=0;high.tiles[i].kind = .filter;high.tiles[i].filterCutoff=1}
low.voices[1].timbre = .pluck;high.voices[1].timbre = .pluck
let lowLoop=LoopRenderer.render(low),highLoop=LoopRenderer.render(high)
func edgeEnergy(_ samples:[Float])->Double {zip(samples.dropFirst(),samples).reduce(0){$0+pow(Double($1.0-$1.1),2)}}
check(edgeEnergy(lowLoop.left)<edgeEnergy(highLoop.left)*0.6,"Filter gate actually removes high-frequency signal energy")
let liveParts=LoopRenderer.stems(garden)
check(liveParts.count==6 && liveParts.allSatisfy{$0.left.count==liveParts[0].left.count},"Every voice shares the same sample-length loop")
var soloGarden=garden
for i in soloGarden.voices.indices {soloGarden.voices[i].enabled = i==5}
let soloLoop=LoopRenderer.render(soloGarden)
check(soloLoop.left == liveParts[5].left.map{tanh($0)},"Muted export preserves percussion noise and matches the live post-sum limiter")
for i in soloGarden.voices.indices {soloGarden.voices[i].enabled=false}
let silentLoop=LoopRenderer.render(soloGarden)
check(silentLoop.left.allSatisfy{$0==0} && silentLoop.right.allSatisfy{$0==0},"All-muted mix is silent without changing loop duration")
print("\(checks) model, scheduling, generation and audio checks passed.")

if CommandLine.arguments.count>1 {
    try! LoopRenderer.wav(LoopRenderer.render(garden)).write(to:URL(fileURLWithPath:CommandLine.arguments[1]),options:.atomic)
}
