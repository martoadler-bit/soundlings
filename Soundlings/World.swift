import Foundation

enum PadKind: String, Codable, CaseIterable {
    case note, drum, chord, transpose, rest, harp, wind, wood, filter, octave
    var title: String { self == .filter ? "Filter Gate" : self == .octave ? "Octave Bloom" : rawValue.capitalized }
}
enum ChordQuality:String,Codable,CaseIterable {
    case major, minor, sus2
    var intervals:[Int] {
        switch self { case .major:return [0,4,7]; case .minor:return [0,3,7]; case .sus2:return [0,2,7] }
    }
}
struct Tile: Codable {
    var x: Float
    var y: Float
    var z: Float
    var note: Int
    var kind: PadKind = .note
    var enabled = true
    var moduleID:UUID?
    var filterCutoff:Double=0.35
    // Highest solid sounding detail above the stored platform elevation.
    var footClearance:Double {
        switch kind {
        case .drum:return 0.205
        case .note,.harp:return 0.11
        case .chord:return 0.09
        case .wind:return 0.14
        case .wood:return 0.10
        case .filter:return 0.165
        case .octave:return 0.16
        case .transpose,.rest:return 0.065
        }
    }
    var arpOctaves=2
    var shift = 7
    var rotation:Float=0
    var quality:ChordQuality = .major
    enum CodingKeys: String, CodingKey { case x,y,z,note,kind,enabled,shift,drum,quality,rotation,filterCutoff,arpOctaves,moduleID }
    init(x:Float,y:Float,z:Float,note:Int,kind:PadKind = .note,enabled:Bool = true,shift:Int = 7) {
        self.x=x; self.y=y; self.z=z; self.note=note; self.kind=kind; self.enabled=enabled; self.shift=shift
    }
    init(from decoder:Decoder) throws {
        let c = try decoder.container(keyedBy:CodingKeys.self)
        x = try c.decode(Float.self,forKey:.x); y = try c.decode(Float.self,forKey:.y); z = try c.decode(Float.self,forKey:.z)
        moduleID = try c.decodeIfPresent(UUID.self,forKey:.moduleID)
        note = try c.decode(Int.self,forKey:.note)
        enabled = try c.decodeIfPresent(Bool.self,forKey:.enabled) ?? true
        filterCutoff = try c.decodeIfPresent(Double.self,forKey:.filterCutoff) ?? 0.35
        arpOctaves = try c.decodeIfPresent(Int.self,forKey:.arpOctaves) ?? 2
        shift = try c.decodeIfPresent(Int.self,forKey:.shift) ?? 7
        rotation = try c.decodeIfPresent(Float.self,forKey:.rotation) ?? 0
        quality = try c.decodeIfPresent(ChordQuality.self,forKey:.quality) ?? .major
        kind = try c.decodeIfPresent(PadKind.self,forKey:.kind) ?? ((try c.decodeIfPresent(Bool.self,forKey:.drum) ?? false) ? .drum : .note)
    }
    func encode(to encoder:Encoder) throws {
        var c = encoder.container(keyedBy:CodingKeys.self)
        try c.encode(x,forKey:.x); try c.encode(y,forKey:.y); try c.encode(z,forKey:.z)
        try c.encodeIfPresent(moduleID,forKey:.moduleID)
        try c.encode(note,forKey:.note); try c.encode(kind,forKey:.kind)
        try c.encode(enabled,forKey:.enabled); try c.encode(shift,forKey:.shift); try c.encode(quality,forKey:.quality);try c.encode(rotation,forKey:.rotation);try c.encode(filterCutoff,forKey:.filterCutoff);try c.encode(arpOctaves,forKey:.arpOctaves)
    }
}
enum VoiceRole:String,Codable,CaseIterable {
    case melody, arpeggio, bass, drone, pad, percussion
    var title:String { rawValue.capitalized }
    var creature:String { ["Azure","Coral","Gold","Violet","Sage","Ember"][index] }
    var index:Int { Self.allCases.firstIndex(of:self)! }
    var behavior:String {
        switch self {
        case .melody:return "Walks a melodic phrase; each arrival plays a note."
        case .arpeggio:return "Plays the harmony; Filter Gates shape its tone and Octave Blooms expand its range."
        case .bass:return "Takes heavy steps on low chord roots."
        case .drone:return "Hovers safely above its beacon, sustaining a glowing tonic pedal."
        case .pad:return "Flies over architecture and opens its canopy to sustain each chord."
        case .percussion:return "Stays at a drum station, striking each rhythmic hit."
        }
    }
    var timbres:[Timbre] {
        switch self {
        case .melody:return [.bell,.marimba,.reed,.string,.flute,.clarinet]
        case .arpeggio:return [.pluck,.glass,.marimba,.string,.flute]
        case .bass:return [.roundBass,.acidBass,.string]
        case .drone:return [.subDrone,.bowedDrone]
        case .pad:return [.warmPad,.choir,.flute,.clarinet]
        case .percussion:return [.analogKit,.woodKit]
        }
    }
    var rhythms:[Rhythm] {
        switch self {
        case .pad:return [.whole,.halves]
        case .drone:return [.whole]
        case .bass:return [.halves,.quarters,.syncopated,.clave]
        case .arpeggio:return [.eighths,.sixteenths,.triplets]
        default:return [.quarters,.eighths,.sixteenths,.triplets,.syncopated,.clave]
        }
    }
}
enum Timbre:String,Codable,CaseIterable {
    case string,flute,clarinet,bell,marimba,reed,pluck,glass,roundBass,acidBass,subDrone,bowedDrone,warmPad,choir,analogKit,woodKit
    var title:String {
        switch self {
        case .roundBass:return "Round bass"
        case .acidBass:return "Resonant bass"
        case .subDrone:return "Sub pedal"
        case .bowedDrone:return "Bowed pedal"
        case .warmPad:return "Warm pad"
        case .analogKit:return "Analog drums"
        case .woodKit:return "Wood & shakers"
        default:return rawValue.capitalized
        }
    }
}
enum Rhythm:String,Codable,CaseIterable {
    case whole,halves,quarters,eighths,sixteenths,triplets,syncopated,clave
    var title:String {
        switch self {
        case .whole:return "Whole notes"
        case .halves:return "Half notes"
        case .quarters:return "Quarter notes"
        case .eighths:return "Eighth notes"
        case .sixteenths:return "Sixteenth notes"
        case .triplets:return "Eighth-note triplets"
        default:return rawValue.capitalized
        }
    }
    var offsets:[Double] {
        switch self {
        case .whole:return [0]
        case .halves:return [0,2]
        case .quarters:return [0,1,2,3]
        case .eighths:return (0..<8).map{Double($0)/2}
        case .sixteenths:return (0..<16).map{Double($0)/4}
        case .triplets:return (0..<12).map{Double($0)/3}
        case .syncopated:return [0,0.75,1.5,2.5,3.25]
        case .clave:return [0,0.75,1.5,2.5,3]
        }
    }
}
enum MusicalScale:String,Codable,CaseIterable {
    case major,minor,dorian,pentatonic
    var intervals:[Int] {
        switch self {
        case .major:return [0,2,4,5,7,9,11]
        case .minor:return [0,2,3,5,7,8,10]
        case .dorian:return [0,2,3,5,7,9,10]
        case .pentatonic:return [0,2,4,7,9]
        }
    }
    func degree(_ index:Int)->Int {
        let n=intervals.count
        let octave=Int(floor(Double(index)/Double(n)))
        return intervals[(index % n+n)%n]+12*octave
    }
    func nearestDegree(to pitch:Int)->Int {
        let octave=Int(floor(Double(pitch)/12)),count=intervals.count
        return ((octave-1)*count...(octave+2)*count).min {a,b in
            let da=abs(degree(a)-pitch),db=abs(degree(b)-pitch)
            return da==db ? a<b : da<db
        } ?? 0
    }
    func quantize(_ pitch:Int)->Int {degree(nearestDegree(to:pitch))}
}
enum Architecture:String,Codable,CaseIterable { case terraces,islands,spiral,ribbon,amphitheater; var title:String { rawValue.capitalized } }
enum WorldPalette:String,Codable,CaseIterable { case sunrise,moonlight,forest,copper,glacier; var title:String { rawValue.capitalized } }
struct Voice:Codable {
    var name:String
    var role:VoiceRole
    var timbre:Timbre
    var rhythm:Rhythm
    var offset:Int
    var octave:Int=0
    var gain:Double=0.65
    var enabled=true
    var density:Double=0.8
    var gate:Double=0.8
    var tone:Double=0.5
    var pan:Double=0
    var pattern:Int=0
    enum CodingKeys:String,CodingKey { case name,role,timbre,rhythm,offset,octave,gain,enabled,density,gate,tone,pan,pattern }
    init(role:VoiceRole,offset:Int=0) {
        self.role=role;name=role.creature;self.offset=offset;timbre=role.timbres[0]
        switch role {
        case .melody:rhythm = .syncopated;gain=0.66;pan = -0.45
        case .arpeggio:rhythm = .sixteenths;gain=0.44;density=0.8;pan=0.5;gate=0.65
        case .bass:rhythm = .halves;gain=0.78;density=1;gate=0.85
        case .drone:rhythm = .whole;gain=0.42;density=1;gate=1;pan = -0.15
        case .pad:rhythm = .whole;gain=0.55;density=1;gate=1.1;pan=0.2
        case .percussion:rhythm = .eighths;gain=0.65;density=0.9;pan = -0.3
        }
    }
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        let role=try c.decodeIfPresent(VoiceRole.self,forKey:.role) ?? .melody
        self.init(role:role)
        name=try c.decodeIfPresent(String.self,forKey:.name) ?? name
        timbre=try c.decodeIfPresent(Timbre.self,forKey:.timbre) ?? timbre
        rhythm=try c.decodeIfPresent(Rhythm.self,forKey:.rhythm) ?? rhythm
        offset=try c.decodeIfPresent(Int.self,forKey:.offset) ?? 0
        octave=try c.decodeIfPresent(Int.self,forKey:.octave) ?? 0
        gain=try c.decodeIfPresent(Double.self,forKey:.gain) ?? gain
        enabled=try c.decodeIfPresent(Bool.self,forKey:.enabled) ?? true
        density=try c.decodeIfPresent(Double.self,forKey:.density) ?? density
        gate=try c.decodeIfPresent(Double.self,forKey:.gate) ?? gate
        tone=try c.decodeIfPresent(Double.self,forKey:.tone) ?? tone
        pan=try c.decodeIfPresent(Double.self,forKey:.pan) ?? pan
        pattern=try c.decodeIfPresent(Int.self,forKey:.pattern) ?? 0
    }
    static var ensemble:[Voice] { VoiceRole.allCases.enumerated().map { Voice(role:$0.element,offset:$0.offset*7) } }
}
enum HitKind:String { case note,kick,snare,hat,rim,drone }
struct MusicalEvent {
    let beat:Double
    var duration:Double
    let tile:Int
    let voice:Int
    let notes:[Int]
    let hit:HitKind
    let velocity:Double
    var filterCutoff:Double?=nil
    var arpOctaves:Int=1
}
struct ActorMotion {
    var tile:Int
    var nextTile:Int
    var progress:Double
    var age:Double
    var duration:Double
    var travelDuration:Double
    var energy:Double
    var hit:HitKind
    var filterCutoff:Double?=nil
    var arpOctaves:Int=1
}
struct MusicalPlan {
    let loopBeats:Double
    let events:[MusicalEvent]
    let byVoice:[[MusicalEvent]]
    func motion(voice:Int,beat:Double,fallback:Int)->ActorMotion {
        let list=byVoice[voice]
        guard !list.isEmpty else { return ActorMotion(tile:fallback,nextTile:fallback,progress:0,age:0,duration:0,travelDuration:0,energy:0,hit:.note) }
        let remainder=beat.truncatingRemainder(dividingBy:loopBeats)
        let phase=remainder<0 ? remainder+loopBeats : remainder
        // Upper bound search: every onset is also the exact arrival at its visible station.
        var lo=0,hi=list.count
        while lo<hi { let mid=(lo+hi)/2;if list[mid].beat<=phase+1e-9 { lo=mid+1 } else { hi=mid } }
        let index=lo==0 ? list.count-1 : lo-1
        let event=list[index],next=list[(index+1)%list.count]
        let age=phase+1e-9>=event.beat ? max(0,phase-event.beat) : phase+loopBeats-event.beat
        let span=next.beat>event.beat ? next.beat-event.beat : next.beat+loopBeats-event.beat
        return ActorMotion(tile:event.tile,nextTile:next.tile,progress:min(1,age/max(0.001,span)),age:age,duration:event.duration,travelDuration:span,energy:event.velocity,hit:event.hit,filterCutoff:event.filterCutoff,arpOctaves:event.arpOctaves)
    }
}
// SplitMix64: stable seeds make Random, save/load and shared worlds reproducible.
struct WorldRandom {
    var state:UInt64
    mutating func next()->UInt64 { state &+= 0x9E3779B97F4A7C15;var z=state;z=(z^(z>>30)) &* 0xBF58476D1CE4E5B9;z=(z^(z>>27)) &* 0x94D049BB133111EB;return z^(z>>31) }
    mutating func unit()->Double { Double(next()>>11)/9_007_199_254_740_992 }
    mutating func int(_ count:Int)->Int { Int(next()%UInt64(count)) }
    mutating func pick<T>(_ choices:[T])->T { choices[int(choices.count)] }
    mutating func range(_ a:Double,_ b:Double)->Double { a+(b-a)*unit() }
}
enum WorldEnvironment:String,Codable,CaseIterable {
    case sky,space,underwater,mist,sunset
    var title:String {self == .underwater ? "Underwater" : rawValue.capitalized}
    var symbol:String {switch self {case .sky:return "cloud.sun";case .space:return "sparkles";case .underwater:return "water.waves";case .mist:return "cloud.fog";case .sunset:return "sunset"}}
}
struct World:Codable {
    var schemaVersion=2
    var name="The Hanging Gardens"
    var seed:UInt64=1207
    var tempo:Double=108
    var tiles:[Tile]
    var structures:[Structure]=[]
    var voices:[Voice]=Voice.ensemble
    var reversed=false
    var root=0
    var stayInScale=true
    var scale:MusicalScale = .major
    var progression=[0,3,4,0]
    var loopBars=8
    var chordBeats=4
    var swing:Double=0.12
    var echo:Double=0.14
    var architecture:Architecture = .terraces
    var palette:WorldPalette = .sunrise
    var ornament:Double=0.7
    var environment:WorldEnvironment = .sky
    var walkwayWidth:Double=0.83
    var routeSynchronized=false
    var percussionStageDistance:Double?
    enum CodingKeys:String,CodingKey { case schemaVersion,name,seed,tempo,tiles,structures,voices,reversed,root,scale,stayInScale,progression,loopBars,chordBeats,swing,echo,architecture,palette,ornament,environment,walkwayWidth,routeSynchronized,percussionStageDistance }
    init(name:String="The Hanging Gardens",tempo:Double=108,tiles:[Tile],voices:[Voice]=Voice.ensemble,reversed:Bool=false) {
        self.name=name;self.tempo=tempo;self.tiles=tiles;self.voices=voices;self.reversed=reversed
        structures=suggestedStructures()
    }
    init(from decoder:Decoder)throws {
        let c=try decoder.container(keyedBy:CodingKeys.self)
        schemaVersion=try c.decodeIfPresent(Int.self,forKey:.schemaVersion) ?? 1
        name=try c.decodeIfPresent(String.self,forKey:.name) ?? "Imported Garden"
        seed=try c.decodeIfPresent(UInt64.self,forKey:.seed) ?? 1207
        tempo=try c.decode(Double.self,forKey:.tempo);tiles=try c.decode([Tile].self,forKey:.tiles)
        voices=try c.decodeIfPresent([Voice].self,forKey:.voices) ?? Voice.ensemble
        reversed=try c.decodeIfPresent(Bool.self,forKey:.reversed) ?? false
        root=try c.decodeIfPresent(Int.self,forKey:.root) ?? 0
        scale=try c.decodeIfPresent(MusicalScale.self,forKey:.scale) ?? .major
        stayInScale=try c.decodeIfPresent(Bool.self,forKey:.stayInScale) ?? true
        progression=try c.decodeIfPresent([Int].self,forKey:.progression) ?? [0,3,4,0]
        loopBars=try c.decodeIfPresent(Int.self,forKey:.loopBars) ?? 8
        chordBeats=try c.decodeIfPresent(Int.self,forKey:.chordBeats) ?? 4
        swing=try c.decodeIfPresent(Double.self,forKey:.swing) ?? 0.12
        echo=try c.decodeIfPresent(Double.self,forKey:.echo) ?? 0.14
        architecture=try c.decodeIfPresent(Architecture.self,forKey:.architecture) ?? .terraces
        palette=try c.decodeIfPresent(WorldPalette.self,forKey:.palette) ?? .sunrise
        ornament=try c.decodeIfPresent(Double.self,forKey:.ornament) ?? 0.7
        environment=try c.decodeIfPresent(WorldEnvironment.self,forKey:.environment) ?? .sky
        walkwayWidth=try c.decodeIfPresent(Double.self,forKey:.walkwayWidth) ?? 0.83
        routeSynchronized=try c.decodeIfPresent(Bool.self,forKey:.routeSynchronized) ?? false
        percussionStageDistance=try c.decodeIfPresent(Double.self,forKey:.percussionStageDistance)
        if percussionStageDistance==nil && seed==1207 && name=="The Hanging Gardens" && tiles.count==56 {percussionStageDistance=2.2}
        if schemaVersion==1 {
            let previous=voices
            voices=Voice.ensemble
            let roles:[VoiceRole]=[.melody,.bass,.arpeggio,.pad]
            for (i,old) in previous.prefix(4).enumerated() {
                let index=roles[i].index
                voices[index].gain=old.gain;voices[index].enabled=old.enabled;voices[index].offset=old.offset
            }
            schemaVersion=2
        }
        structures=try c.decodeIfPresent([Structure].self,forKey:.structures) ?? suggestedStructures()
    }
    var valid:Bool {
        (percussionStageDistance.map{(1.5...8).contains($0)} ?? true) && (0.83...2.0).contains(walkwayWidth) && structures.allSatisfy(\.valid) && schemaVersion==2 && !name.isEmpty && name.count<=100 && (60...160).contains(tempo) &&
        voices.count==6 && Set(voices.map(\.role)).count==6 && (0...11).contains(root) && [4,8,12].contains(loopBars) && [4,8].contains(chordBeats) &&
        progression.count==4 && progression.allSatisfy{(0...6).contains($0)} && (0...0.4).contains(swing) && (0...0.45).contains(echo) && (0...1).contains(ornament) &&
        voices.allSatisfy { $0.name.count<=80 && $0.offset>=0 && (-24...24).contains($0.octave) && (0...1).contains($0.gain) &&
            (0...1).contains($0.density) && (0.15...1.5).contains($0.gate) && (0...1).contains($0.tone) && (-1...1).contains($0.pan) &&
            (0...2).contains($0.pattern) && $0.role.timbres.contains($0.timbre) && $0.role.rhythms.contains($0.rhythm) } &&
        tiles.allSatisfy { (0...1).contains($0.filterCutoff) && (1...3).contains($0.arpOctaves) && $0.rotation.isFinite && (-360...360).contains($0.rotation) && [$0.x,$0.y,$0.z].allSatisfy(\.isFinite) && (48...84).contains($0.note) && (-12...12).contains($0.shift) }
    }
    var loopBeats:Double { Double(loopBars*4) }
    var keyName:String { ["C","C♯","D","E♭","E","F","F♯","G","A♭","A","B♭","B"][root]+" "+scale.rawValue }
    var seedCode:String { String(seed,radix:36).uppercased() }
    var route:[Int] { reversed ? Array(tiles.indices.reversed()) : Array(tiles.indices) }
    func tileIndex(at step:Int,voice:Int)->Int { route[((step+voices[voice].offset)%tiles.count+tiles.count)%tiles.count] }
    func requiresPortalLink(from:Int,to:Int)->Bool {
        let a=tiles[from],b=tiles[to]
        return hypot(a.x-b.x,a.z-b.z)>1.6 || abs(a.y-b.y)>0.65
    }
    // Musical rests can skip stations. A continuous walkway is still walked, rather than teleported.
    func isPortal(from:Int,to:Int)->Bool {
        guard tiles.indices.contains(from),tiles.indices.contains(to),from != to else {return false}
        let direction=reversed ? -1 : 1
        var index=from
        for _ in tiles.indices {
            let next=(index+direction+tiles.count)%tiles.count
            if requiresPortalLink(from:index,to:next) {return true}
            if next==to {return false}
            index=next
        }
        return false
    }
    func plan()->MusicalPlan {
        let events=events()
        return MusicalPlan(loopBeats:loopBeats,events:events,byVoice:voices.indices.map { v in events.filter{$0.voice==v} })
    }
    func arrangedPitch(_ pitch:Int,transpose:Int=0)->Int {
        guard stayInScale else {return min(108,max(24,pitch+transpose))}
        let tonic=60+root
        let degree=scale.nearestDegree(to:pitch-tonic)+scale.nearestDegree(to:transpose)
        var target=tonic+scale.degree(degree)
        // Fold the register by octaves, preserving the degree (especially the tonic pedal).
        while target<24 {target+=12}
        while target>108 {target-=12}
        return target
    }
    func events()->[MusicalEvent] {
        guard !tiles.isEmpty else {return []}
        var result=[MusicalEvent](),shifts=[Int:Int](),shift=0
        for index in route {
            if tiles[index].enabled && tiles[index].kind == .transpose { shift=tiles[index].shift }
            shifts[index]=shift
        }
        for (v,voice) in voices.enumerated() where voice.enabled && voice.gain>0 && voice.density>0 {
            var random=WorldRandom(state:seed &+ UInt64(v+1) &* 0xD1B54A32D192ED03)
            if voice.role == .drone {
                let index=tileIndex(at:0,voice:v)
                if tiles[index].enabled && tiles[index].kind != .rest {
                    result.append(MusicalEvent(beat:0,duration:loopBeats,tile:index,voice:v,notes:[arrangedPitch(36+root+voice.octave)],hit:.drone,velocity:0.85))
                }
                continue
            }
            let cycle=voice.role == .pad ? Double(chordBeats) : 4.0
            var onsets=[Double]()
            for bar in 0..<Int(ceil(loopBeats/cycle)) {
                for offset in voice.rhythm.offsets {
                    var beat=Double(bar)*cycle+offset/4*cycle
                    if voice.rhythm != .triplets && voice.role != .pad {
                        let offbeat=Int((beat*2).rounded())%2==1 && abs(beat*2-(beat*2).rounded())<0.001
                        if offbeat { beat+=swing*0.5 }
                    }
                    if beat<loopBeats && (random.unit()<voice.density || beat==0) { onsets.append(beat) }
                }
            }
            var arpCutoff:Double?=nil,arpSpan=1
            for (i,beat) in onsets.enumerated() {
                let step=routeSynchronized ? Int(Double(i)*Double(tiles.count)/Double(max(1,onsets.count))) : i
                let index=tileIndex(at:voice.role == .percussion ? 0 : step,voice:v),tile=tiles[index]
                guard tile.enabled && tile.kind != .rest else { continue }
                let degree=progression[(Int(beat)/chordBeats)%progression.count]
                let chord=[0,2,4].map { scale.degree(degree+$0) }
                let transpose=shifts[index] ?? 0
                let next=i+1<onsets.count ? onsets[i+1] : loopBeats+onsets[0]
                let gap=next-beat
                var duration=max(0.08,min(2,gap*voice.gate)),notes=[Int](),hit:HitKind = .note
                var playedOctaves=1
                switch voice.role {
                case .melody:
                    let pitch=60+root+scale.quantize(tile.note-60)+voice.octave
                    if tile.kind == .chord && stayInScale {
                        let degree=scale.nearestDegree(to:pitch-60-root)
                        let offsets=tile.quality == .sus2 ? [0,1,4] : [0,2,4]
                        notes=offsets.map{60+root+scale.degree(degree+$0)}
                    } else {notes=tile.kind == .chord ? tile.quality.intervals.map{pitch+$0} : [pitch]}
                case .arpeggio:
                    if tile.kind == .filter {arpCutoff=150*pow(80,tile.filterCutoff)}
                    if tile.kind == .octave {arpSpan=tile.arpOctaves}
                    let shiftedRoot=arrangedPitch(60+root+chord[0]+voice.octave,transpose:transpose)
                    let correction=shiftedRoot>96 ? -12 : 0
                    playedOctaves=min(arpSpan,max(1,(108-shiftedRoot-correction)/12))
                    let top=playedOctaves*3,cycle=top+1
                    let forward=i%cycle
                    let bounce=i%max(1,top*2)
                    let step=voice.pattern==0 ? forward : voice.pattern==1 ? top-forward : (bounce<=top ? bounce : top*2-bounce)
                    notes=[60+root+chord[step%3]+12*(step/3)+voice.octave+correction]
                    duration=min(0.7,gap*voice.gate)
                case .bass:
                    let fifth=stayInScale ? scale.degree(degree+4)-scale.degree(degree) : 7
                    notes=[36+root+scale.degree(degree)+(voice.pattern==2 && i%4==3 ? fifth : voice.pattern==1 && i%2==1 ? 12 : 0)+voice.octave]
                case .pad:
                    notes=chord.map {48+root+$0+voice.octave}
                    duration=gap*voice.gate
                case .percussion:
                    notes=[];duration=0.2
                    let position=beat.truncatingRemainder(dividingBy:4)
                    if abs(position-position.rounded())<0.21 {
                        hit=Int(position.rounded())%2==0 ? .kick : .snare
                    } else { hit=(i+voice.pattern)%4==3 ? .rim : .hat }
                case .drone:break
                }
                let accent=abs(beat.truncatingRemainder(dividingBy:4))<0.001 ? 1.0 : (tile.kind == .drum ? 0.95 : 0.65+random.unit()*0.25)
                result.append(MusicalEvent(beat:beat,duration:duration,tile:index,voice:v,notes:notes.map{arrangedPitch($0,transpose:transpose)},hit:hit,velocity:accent,filterCutoff:voice.role == .arpeggio ? arpCutoff : nil,arpOctaves:playedOctaves))
            }
        }
        return result.sorted { $0.beat == $1.beat ? $0.voice<$1.voice : $0.beat<$1.beat }
    }
    static func terrace(level:Int,radius:Int,centerX:Float=0,centerZ:Float=0)->[Tile] {
        var points=[(Float,Float)]()
        for x in -radius..<radius {points.append((Float(x),Float(-radius)))}
        for z in -radius..<radius {points.append((Float(radius),Float(z)))}
        for x in stride(from:radius,to:-radius,by:-1){points.append((Float(x),Float(radius)))}
        for z in stride(from:radius,to:-radius,by:-1){points.append((Float(-radius),Float(z)))}
        return points.enumerated().map {i,p in
            let rise=Float(i<radius*2 ? i : max(0,radius*4-i))*0.16
            return Tile(x:p.0+centerX,y:Float(level)*3+1+rise,z:p.1+centerZ,note:[60,64,67,69,72,67,64,62][i%8])
        }
    }
    static func connectedLayout(_ source:[Tile],limit:Int=96)->[Tile] {
        guard !source.isEmpty else {return []}
        var result=[Tile](),remaining=limit-source.count
        for i in source.indices {
            let a=source[i],b=source[(i+1)%source.count]
            result.append(a)
            let horizontal=Double(hypot(b.x-a.x,b.z-a.z)),rise=Double(abs(b.y-a.y))
            // One intentional return portal is preferable to a near-vertical stair stack.
            if i==source.count-1 && rise>2.5 {continue}
            var points=[a,b]
            if rise>0.35 && rise>horizontal*0.24 {
                let length=max(0.001,horizontal),nx=Double(b.z-a.z)/length,nz = -Double(b.x-a.x)/length
                let side=nx*Double(a.x+b.x)+nz*Double(a.z+b.z)>=0 ? 1.0 : -1.0
                let detour=max(0.8,(rise/0.22-horizontal)/2+0.5)
                let dx=Float(nx*detour*side),dz=Float(nz*detour*side)
                var p=a,q=b;p.x+=dx;p.z+=dz;q.x+=dx;q.z+=dz
                let total=2*detour+horizontal
                p.y=a.y+(b.y-a.y)*Float(detour/total)
                q.y=a.y+(b.y-a.y)*Float((detour+horizontal)/total)
                points=[a,p,q,b]
            }
            var additions=[Tile]()
            for leg in 1..<points.count {
                let u=points[leg-1],v=points[leg]
                let distance=Double(hypot(v.x-u.x,v.z-u.z)),dy=Double(abs(v.y-u.y))
                let steps=max(1,max(Int(ceil(distance/1.35)),Int(ceil(dy/0.18))))
                for step in 1...steps {
                    if leg==points.count-1 && step==steps {continue}
                    let t=Float(step)/Float(steps)
                    additions.append(Tile(x:u.x+(v.x-u.x)*t,y:u.y+(v.y-u.y)*t,z:u.z+(v.z-u.z)*t,note:60))
                }
            }
            guard additions.count<=remaining,additions.allSatisfy({abs($0.x)<=20 && abs($0.z)<=20}) else {continue}
            result+=additions;remaining-=additions.count
        }
        return result
    }
    static func generate(seed:UInt64,architecture fixed:Architecture?=nil,palette fixedPalette:WorldPalette?=nil)->World {
        var rng=WorldRandom(state:seed)
        let architecture=fixed ?? rng.pick(Architecture.allCases)
        let palette=fixedPalette ?? rng.pick(WorldPalette.allCases)
        let tiles=logicalLayout(architecture,random:&rng)
        var world=World(tiles:tiles)
        world.walkwayWidth=1.55;world.routeSynchronized=true
        world.seed=seed;world.architecture=architecture;world.palette=palette
        world.environment=WorldEnvironment.allCases[Int((seed ^ (seed >> 9)) % UInt64(WorldEnvironment.allCases.count))]
        world.root=rng.int(12);world.scale=rng.pick(MusicalScale.allCases)
        world.tempo=Double(68+rng.int(57));world.loopBars=8;world.chordBeats=rng.pick([4,8])
        world.progression=[0,rng.int(world.scale.intervals.count),rng.int(world.scale.intervals.count),rng.int(world.scale.intervals.count)]
        world.swing=rng.range(0,0.32);world.echo=rng.range(0.03,0.35);world.ornament=rng.range(0.3,1)
        world.reversed=rng.int(2)==0
        world.name=rng.pick(["Amber","Velvet","Lunar","Hidden","Glass","Drifting","Copper","Moss"]) + " " + rng.pick(["Sanctuary","Orchard","Orbit","Lanterns","Tides","Steps","Isles","Spiral"])
        let family:PadKind=[.harp,.wind,.wood,.note][Int(seed%4)]
        for i in world.tiles.indices {
            world.tiles[i].note=60+world.scale.degree(rng.int(10)-2)
            world.tiles[i].kind=rng.pick([family,family,family,.note,.note,.chord,.drum,.transpose,.rest,.filter,.octave])
            world.tiles[i].enabled=rng.unit()>0.08
            world.tiles[i].shift=rng.pick([-12,-7,0,5,7,12])
            world.tiles[i].quality=rng.pick(ChordQuality.allCases)
            world.tiles[i].filterCutoff=rng.range(0.12,0.95);world.tiles[i].arpOctaves=2+rng.int(2)
        }
        for i in world.voices.indices {
            var voice=world.voices[i]
            voice.timbre=rng.pick(voice.role.timbres);voice.rhythm=rng.pick(voice.role.rhythms)
            voice.offset=rng.int(world.tiles.count);voice.gain=rng.range(0.35,0.8)
            voice.density=voice.role == .drone ? 1 : rng.range(0.45,1)
            voice.gate=rng.range(voice.role == .pad ? 0.9 : 0.3,voice.role == .pad ? 1.4 : 1.1)
            voice.tone=rng.unit();voice.pan=rng.range(-0.8,0.8);voice.pattern=rng.int(3)
            voice.octave=rng.pick(voice.role == .bass || voice.role == .drone ? [0,0,12] : [-12,0,0,12])
            voice.enabled=rng.unit()>0.10
            world.voices[i]=voice
            let station=world.tileIndex(at:0,voice:i)
            world.tiles[station].enabled=true
            if world.tiles[station].kind == .rest {world.tiles[station].kind = .note}
        }
        if world.voices.filter(\.enabled).count<4 {for i in 0..<4 {world.voices[i].enabled=true}}
        if let arp=world.voices.firstIndex(where:{$0.role == .arpeggio && $0.enabled}) {
            let filter=world.tileIndex(at:2,voice:arp),bloom=world.tileIndex(at:5,voice:arp)
            world.tiles[filter].kind = .filter;world.tiles[filter].enabled=true
            world.tiles[bloom].kind = .octave;world.tiles[bloom].enabled=true
        }
        // Separate walking starts, keep the stationary drummer off the main route.
        let start=rng.int(world.tiles.count)
        for (slot,index) in [0,1,2].enumerated() {
            world.voices[index].offset=(start+slot*world.tiles.count/3)%world.tiles.count
            let station=world.tileIndex(at:0,voice:index)
            world.tiles[station].enabled=true
            if world.tiles[station].kind == .rest {world.tiles[station].kind = .note}
        }
        world.structures=world.suggestedStructures().filter {world.sceneryClearsRoute($0)}
        // Perimeter scenery shares the editable catalogue and keeps the promenade clear.
        for slot in 0..<(3+Int(world.ornament*3)) {
            let kind=rng.pick(StructureKind.allCases)
            for attempt in 0..<12 {
                let angle=Double(slot)*2 * Double.pi/5+Double(attempt)*0.35
                var piece=Self.piece(kind,x:Float(cos(angle)*11),y:0.5,z:Float(sin(angle)*11))
                piece.rotation=Float(angle*180/Double.pi).truncatingRemainder(dividingBy:360)
                if world.sceneryClearsRoute(piece) && !world.structures.contains(where:{hypot($0.x-piece.x,$0.z-piece.z)<max($0.width,piece.width)+0.5}) {
                    world.structures.append(piece);break
                }
            }
        }
        // Purpose-built supports stop below the deck; they provide architecture
        // without turning the walking corridor into an obstacle course.
        for index in stride(from:0,to:world.tiles.count,by:7) {
            let tile=world.tiles[index]
            let kind:StructureKind=architecture == .terraces || architecture == .amphitheater ? .arch : architecture == .islands ? .island : .column
            var support=Self.piece(kind,x:tile.x,y:0,z:tile.z)
            support.height=max(0.6,tile.y-0.45)
            if kind == .island {support.width=1.5;support.depth=1.5}
            let next=world.tiles[(index+1)%world.tiles.count]
            support.rotation=Float(atan2(next.x-tile.x,next.z-tile.z))*180/Float.pi
            if world.sceneryClearsRoute(support) {world.structures.append(support)}
        }
        world.repairMechanisms()
        return world
    }
    static var blank:World {
        var world=World(name:"My New World",tiles:[])
        world.ornament=0
        for i in world.voices.indices {world.voices[i].enabled=false}
        world.structures=world.suggestedStructures()
        world.repairMechanisms()
        return world
    }
    static var garden:World {
        var world=generate(seed:1207,architecture:.terraces,palette:.sunrise)
        world.walkwayWidth=0.83;world.routeSynchronized=false
        world.percussionStageDistance=2.2
        world.name="The Hanging Gardens";world.tempo=108;world.root=0;world.scale = .major
        world.progression=[0,3,4,0];world.swing=0.16;world.loopBars=8;world.chordBeats=4
        world.voices=Voice.ensemble
        world.tiles=terrace(level:0,radius:3)+terrace(level:1,radius:2,centerX:0.5)+terrace(level:2,radius:2,centerX:-0.5,centerZ:-0.5)
        for i in world.tiles.indices {world.tiles[i].kind = i%11==0 ? .chord : .note}
        world.structures=world.suggestedStructures()
        world.repairMechanisms()
        return world
    }
    static var moon:World {
        var world=generate(seed:8902,architecture:.islands,palette:.moonlight)
        world.walkwayWidth=0.83;world.routeSynchronized=false
        world.name="The Moon Courtyard";world.tempo=72;world.root=2;world.scale = .dorian
        world.progression=[0,5,2,0];world.swing=0;world.echo=0.3;world.loopBars=8;world.chordBeats=8
        world.voices=Voice.ensemble
        for i in world.tiles.indices {world.tiles[i].kind = .note;world.tiles[i].note=60+world.scale.degree(i%5);world.tiles[i].enabled=true}
        for i in world.voices.indices {
            world.voices[i].offset=(i*5)%world.tiles.count
            switch world.voices[i].role {
            case .melody:world.voices[i].timbre = .reed;world.voices[i].rhythm = .quarters;world.voices[i].density=0.35;world.voices[i].gain=0.4
            case .arpeggio:world.voices[i].timbre = .glass;world.voices[i].rhythm = .triplets;world.voices[i].density=0.4;world.voices[i].gain=0.3
            case .bass:world.voices[i].timbre = .roundBass;world.voices[i].rhythm = .halves;world.voices[i].gain=0.45
            case .drone:world.voices[i].timbre = .bowedDrone;world.voices[i].gain=0.65
            case .pad:world.voices[i].timbre = .choir;world.voices[i].gain=0.7;world.voices[i].gate=1.25
            case .percussion:world.voices[i].timbre = .woodKit;world.voices[i].rhythm = .clave;world.voices[i].density=0.6;world.voices[i].gain=0.35
            }
        }
        world.structures=world.suggestedStructures()
        world.repairMechanisms()
        return world
    }
    static let saveURL=URL.documentsDirectory.appending(path:"soundlings-world-v2.json")
    static func load()->World {
        guard let data=try? Data(contentsOf:saveURL),var world=try? JSONDecoder().decode(World.self,from:data),world.valid else{return .garden}
        world.repairMechanisms()
        return world
    }
    func encoded()throws->Data {let encoder=JSONEncoder();encoder.outputFormatting=[.prettyPrinted,.sortedKeys];return try encoder.encode(self)}
    func save()throws {try encoded().write(to:Self.saveURL,options:.atomic)}
    mutating func insert(after index:Int,dx:Float,dy:Float,dz:Float)->Bool {
        guard tiles.indices.contains(index) else{return false}
        var tile=tiles[index];tile.x+=dx;tile.y+=dy;tile.z+=dz;tile.kind = .note;tile.moduleID=nil
        guard [tile.x,tile.y,tile.z].allSatisfy(\.isFinite),!tiles.contains(where:{abs($0.x-tile.x)<0.1 && abs($0.y-tile.y)<0.1 && abs($0.z-tile.z)<0.1}) else{return false}
        tiles.insert(tile,at:reversed ? index : index+1);return true
    }
}

// Editing decisions use musical beats, shared by picture and sound.
enum MovieDuration:String,CaseIterable,Identifiable {
    case loop,short,medium,long
    var id:String {rawValue}
    var title:String {switch self {case .loop:return "One loop";case .short:return "About 15 seconds";case .medium:return "About 30 seconds";case .long:return "About 60 seconds"}}
    var seconds:Double? {switch self {case .loop:return nil;case .short:return 15;case .medium:return 30;case .long:return 60}}
}
enum MovieShotKind:String {case overview,follow,firstPerson,split}
struct MovieShot {
    var start:Double,end:Double
    var kind:MovieShotKind
    var voice:Int
}
struct MovieEditPlan {
    var beats:Double
    var shots:[MovieShot]
    init(world:World,duration:MovieDuration,splitScreen:Bool=true) {
        beats=duration.seconds.map{max(4,($0*world.tempo/60/4).rounded()*4)} ?? world.loopBeats
        let active=world.voices.indices.filter{world.voices[$0].enabled}
        let walkers=active.filter{[VoiceRole.melody,.arpeggio,.bass].contains(world.voices[$0].role)}
        shots=[]
        var start=0.0,index=0,person=0
        while start<beats {
            let end=min(beats,start+8)
            var kind:MovieShotKind = .overview,voice=active.first ?? 0
            if index%4==1,!active.isEmpty {kind = .follow;voice=active[person%active.count]}
            if index%4==2,!walkers.isEmpty {kind = .firstPerson;voice=walkers[person%walkers.count];person+=1}
            if index%4==3,!active.isEmpty {if splitScreen {kind = .split;voice=active[person%active.count]};person+=1}
            shots.append(MovieShot(start:start,end:end,kind:kind,voice:voice))
            start=end;index+=1
        }
    }
    func shot(at beat:Double)->MovieShot {shots.first{beat<$0.end} ?? shots[shots.count-1]}
}
