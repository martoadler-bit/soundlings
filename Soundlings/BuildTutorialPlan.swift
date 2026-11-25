import Foundation

struct BuildTutorialSession:Identifiable {
    let id=UUID()
    let world:World
}
enum TutorialChapter:String,CaseIterable {
    case overview,settings,path,instruments,scenery,characters,finished
    var title:String {switch self {case .overview:return "The plan";case .settings:return "World settings";case .path:return "Build the path";case .instruments:return "Add instruments";case .scenery:return "Add scenery";case .characters:return "Add characters";case .finished:return "Ready to play"}}
    var symbol:String {switch self {case .overview:return "map";case .settings:return "slider.horizontal.3";case .path:return "square.stack.3d.up";case .instruments:return "music.note";case .scenery:return "building.columns";case .characters:return "person.3";case .finished:return "checkmark.circle"}}
}
struct TutorialStep:Equatable {
    let chapter:TutorialChapter
    var index:Int=0
}
struct BuildTutorialPlan {
    let world:World
    let steps:[TutorialStep]
    init(_ world:World) {
        self.world=world
        steps=[TutorialStep(chapter:.overview),TutorialStep(chapter:.settings)]
            + world.tiles.indices.map{TutorialStep(chapter:.path,index:$0)}
            + world.tiles.indices.filter{world.tiles[$0].kind != .rest}.map{TutorialStep(chapter:.instruments,index:$0)}
            + world.structures.indices.map{TutorialStep(chapter:.scenery,index:$0)}
            + (world.tiles.isEmpty ? [] : world.voices.indices.map{TutorialStep(chapter:.characters,index:$0)})
            + [TutorialStep(chapter:.finished)]
    }
    func title(_ step:TutorialStep)->String {
        switch step.chapter {
        case .path:return "Place step \(step.index+1)"
        case .instruments:return "Step \(step.index+1) · \(world.tiles[step.index].kind.title)"
        case .scenery:return "Place \(world.structures[step.index].kind.title)"
        case .characters:return "\(world.voices[step.index].enabled ? "Add" : "Keep off") \(world.voices[step.index].role.creature)"
        default:return step.chapter.title
        }
    }
    func instruction(_ step:TutorialStep)->String {
        switch step.chapter {
        case .overview:return "Watch this exact world come together. Solid pieces are already built; faint pieces show what comes next. The gold outline marks the current piece."
        case .settings:return "Start with New Empty World. In Music & Voices, set the values below. Leave characters and Reverse route off while you build."
        case .path:
            let tile=world.tiles[step.index]
            return "Build → Musical Steps → Silent Step. Set the placement height, then place it at the gold outline.\(step.index>0 ? " Add it after step \(step.index) to preserve the route order." : " This is the first piece.") Use Free placement and Exact position for this world's coordinates.\(tile.y>1.5 ? " This section is raised." : "") Bridges and portals connect automatically."
        case .instruments:return "Select the highlighted step, open Details and choose \(world.tiles[step.index].kind.title). Apply its settings below. The shape and color show its musical role."
        case .scenery:return "Build → Scenery → \(world.structures[step.index].kind.title). Place it at the outline, then open Details to set its size and rotation.\(world.structures[step.index].enabled ? "" : " Keep this piece hidden, as in the original world.")"
        case .characters:return "Build → Characters. \(world.voices[step.index].enabled ? "Add this character after the path is ready." : "Leave this character off.") In Music & Voices, match its musical settings. \(world.voices[step.index].role.behavior)"
        case .finished:return "The path and scenery now match the original world. Set Reverse route to \(world.reversed ? "On" : "Off"), then tap Done and Play. Replay any chapter to take a closer look."
        }
    }
    func details(_ step:TutorialStep)->[(String,String)] {
        func position(_ x:Float,_ y:Float,_ z:Float)->[(String,String)] {[("X",String(x)),("Height",String(y)),("Z",String(z))]}
        switch step.chapter {
        case .settings:return [("Name",world.name),("Backdrop",world.environment.title),("Palette",world.palette.title),("Style",world.architecture.title),("Key / mode",world.keyName),("Tempo",String(world.tempo)),("Loop bars",String(world.loopBars)),("Chord beats",String(world.chordBeats)),("Progression (degrees)",world.progression.map{["I","II","III","IV","V","VI","VII"][$0]}.joined(separator:" · ")),("Swing",String(world.swing)),("Echo",String(world.echo)),("Walkway width",String(world.walkwayWidth)),("Complete route each loop",world.routeSynchronized ? "On" : "Off"),("Reverse route while building","Off"),("Stay in scale / mode",world.stayInScale ? "On" : "Off"),("Variation code",world.seedCode)]
        case .path:return position(world.tiles[step.index].x,world.tiles[step.index].y,world.tiles[step.index].z)+[("Rotation",String(world.tiles[step.index].rotation)),("Enabled",world.tiles[step.index].enabled ? "On" : "Off")]
        case .instruments:
            let t=world.tiles[step.index]
            var values=[("Mechanism",t.kind.title),("Pitch / MIDI",String(t.note)),("Enabled",t.enabled ? "On" : "Off"),("Rotation",String(t.rotation))]
            if t.kind == .transpose {values.append((world.stayInScale ? "Scale steps" : "Semitones",String(world.stayInScale ? world.scale.nearestDegree(to:t.shift) : t.shift)))}
            if t.kind == .chord {values.append((world.stayInScale ? "Voicing" : "Chord",world.stayInScale ? (t.quality == .sus2 ? "Suspended" : "Diatonic triad") : t.quality.rawValue.capitalized))}
            if t.kind == .filter {values.append(("Precise cutoff (0–1)",String(t.filterCutoff)))}
            if t.kind == .octave {values.append(("Arpeggio octaves",String(t.arpOctaves)))}
            return values
        case .scenery:
            let p=world.structures[step.index]
            return position(p.x,p.y,p.z)+[("Width",String(p.width)),("Height / size",String(p.height)),("Depth",String(p.depth)),("Rotation",String(p.rotation)),("Detail",String(p.detail)),("Visible",p.enabled ? "On" : "Off")]
        case .characters:
            let v=world.voices[step.index]
            return [("Enabled",v.enabled ? "On" : "Off"),("Timbre",v.timbre.title),("Rhythm",v.rhythm.title),("Start pad",String(v.offset+1)),("Register",String(v.octave)),("Volume",String(v.gain)),("Density",String(v.density)),("Length",String(v.gate)),("Brightness",String(v.tone)),("Pan",String(v.pan)),("Pattern",["A","B","C"][v.pattern])]
        default:return [("Musical steps",String(world.tiles.count)),("Scenery pieces",String(world.structures.count)),("Active characters",String(world.voices.filter(\.enabled).count)),("Final Reverse route",world.reversed ? "On" : "Off")]
        }
    }
    var chapters:[TutorialChapter] {TutorialChapter.allCases.filter{chapter in steps.contains{$0.chapter==chapter}}}
}
