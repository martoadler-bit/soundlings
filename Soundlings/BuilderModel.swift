import Foundation

// This is the entire visual piece catalogue. Random and the manual builder store the same records.
enum StructureKind:String,Codable,CaseIterable {
    case arch,pavilion,basin,island,column,gear,waterfall,tree,orbit
    var title:String {rawValue.capitalized}
    var symbol:String {
        switch self {
        case .arch:return "door.left.hand.open"
        case .pavilion:return "building.columns"
        case .basin:return "water.waves"
        case .island:return "mountain.2"
        case .column:return "building.columns.fill"
        case .gear:return "gearshape"
        case .waterfall:return "drop.fill"
        case .tree:return "tree.fill"
        case .orbit:return "atom"
        }
    }
}
struct Structure:Codable,Equatable {
    var kind:StructureKind
    var moduleID:UUID?
    var x:Float=0,y:Float=1,z:Float=0
    var width:Float=1,height:Float=1,depth:Float=1
    var rotation:Float=0
    var detail:Float=0.45
    var enabled=true
    // All stored elevations refer to the foot of a piece, so placement layers behave consistently.
    var anchorHeight:Float {
        switch kind {
        case .arch:return 0
        case .pavilion:return height/2.5*0.125
        case .tree:return height/1.45*0.955
        case .gear:return 0.92*height/1.36
        case .orbit:return max(detail,1.7*abs(sin(1.4))+0.035)*height/3.4
        default:return height/2
        }
    }
    var valid:Bool {
        (kind != .arch || height>width/2) && [x,y,z,width,height,depth,rotation,detail].allSatisfy(\.isFinite) &&
        [width,height,depth].allSatisfy{(0.02...48).contains($0)} &&
        (-360...360).contains(rotation) && (0.1...1.5).contains(detail)
    }
}
enum BuildItem:Hashable,Identifiable {
    case tile(PadKind),structure(StructureKind)
    var id:String {switch self {case .tile(let k):return "tile-"+k.rawValue;case .structure(let k):return "structure-"+k.rawValue}}
    var title:String {switch self {case .tile(let k):return k == .rest ? "Silent Step" : k.title;case .structure(let k):return k.title}}
    var symbol:String {
        switch self {
        case .structure(let k):return k.symbol
        case .tile(let k):switch k {
        case .note:return "pianokeys"
        case .drum:return "circle.inset.filled"
        case .chord:return "music.note.list"
        case .transpose:return "arrow.up.arrow.down"
        case .rest:return "square"
        case .harp:return "guitars"
        case .wind:return "wind"
        case .wood:return "rectangle.split.3x1"
        case .filter:return "line.3.horizontal.decrease.circle"
        case .octave:return "arrow.up.right.square"
        }
        }
    }
    static var instruments:[BuildItem] {PadKind.allCases.map{.tile($0)}}
    static var scenery:[BuildItem] {StructureKind.allCases.map{.structure($0)}}
}
enum BuildTool:String,CaseIterable {case select,place,move;var title:String {rawValue.capitalized}}

extension World {
    // Defaults also define the dimensions offered to people in the palette.
    static func piece(_ kind:StructureKind,x:Float=0,y:Float=1,z:Float=0)->Structure {
        var p=Structure(kind:kind,x:x,y:y,z:z)
        switch kind {
        case .arch:p.width=0.92;p.height=2.5;p.depth=0.7
        case .pavilion:p.width=1.7;p.height=2.5;p.depth=1.7
        case .basin:p.width=4;p.height=0.5;p.depth=4
        case .island:p.width=3;p.height=2;p.depth=3
        case .column:p.width=0.26;p.height=3;p.depth=0.26
        case .gear:p.width=1.36;p.height=1.36;p.depth=0.4
        case .waterfall:p.width=0.33;p.height=2.8;p.depth=0.035
        case .tree:p.width=0.54;p.height=1.45;p.depth=0.54
        case .orbit:p.width=3.4;p.height=3.4;p.depth=3.4
        }
        return p
    }
    // Legacy scenery is materialized once. No uneditable structures are invented by the renderer.
    func suggestedStructures()->[Structure] {
        guard let minX=tiles.map(\.x).min(),let maxX=tiles.map(\.x).max(),
              let minZ=tiles.map(\.z).min(),let maxZ=tiles.map(\.z).max(),let maxY=tiles.map(\.y).max() else {return []}
        let cx=(minX+maxX)/2,cz=(minZ+maxZ)/2
        var result=[Structure]()
        if architecture == .terraces && ornament>0.2 {
            var p=Self.piece(.basin,x:cx,y:-0.8,z:cz);p.width=maxX-minX+1.8;p.depth=maxZ-minZ+1.8;result.append(p)
        }
        for (i,t) in tiles.enumerated() {
            if architecture == .islands && i%8==0 {result.append(Self.piece(.island,x:t.x,y:t.y-1.2,z:t.z))}
            if architecture == .spiral && i%4==0 {
                var p=Self.piece(.column,x:t.x,y:(t.y-0.5)/2,z:t.z);p.height=max(0.2,t.y+0.5);result.append(p)
            }
            if architecture == .terraces && i%4==0 {
                let base=min(t.y-0.65,max(-0.45,t.y-3))
                var p=Self.piece(.arch,x:t.x,y:base,z:t.z);p.height=t.y-base-0.15
                p.rotation=abs(t.x-cx)>abs(t.z-cz) ? 90 : 0;result.append(p)
            }
        }
        if ornament>0.2 {
            if architecture == .terraces {result.append(Self.piece(.pavilion,x:cx,y:maxY+0.15,z:cz))}
            else {var p=Self.piece(.orbit,x:cx,y:maxY+0.8,z:cz);p.detail=architecture == .islands ? 0.8 : 0.45;result.append(p)}
        }
        if ornament>0.4 {
            for (i,x) in [minX+0.2,maxX-0.2].enumerated() {
                var p=Self.piece(.gear,x:x,y:Float(i)*3+0.6,z:maxZ+0.5)
                p.width=i==0 ? 1.36 : 1.84;p.height=p.width;result.append(p)
            }
            for x in [minX+0.45,maxX-0.45] {result.append(Self.piece(.waterfall,x:x,y:0.9,z:minZ-0.5))}
            for x in [minX+0.7,maxX-0.7] {result.append(Self.piece(.tree,x:x,y:0.5,z:maxZ-0.5))}
        }
        return result.map {piece in var p=piece;p.y-=p.anchorHeight;return p}
    }
    func canPlaceTile(x:Float,y:Float,z:Float,excluding:Int?=nil)->Bool {
        guard [x,y,z].allSatisfy(\.isFinite) else {return false}
        return !tiles.enumerated().contains {i,t in i != excluding && abs(t.x-x)<0.08 && abs(t.y-y)<0.08 && abs(t.z-z)<0.08}
    }
    @discardableResult mutating func placeTile(_ tile:Tile,after index:Int?=nil)->Int? {
        guard canPlaceTile(x:tile.x,y:tile.y,z:tile.z), (48...84).contains(tile.note) else {return nil}
        let position=index.map{min(tiles.count,max(0,$0+1))} ?? tiles.count
        tiles.insert(tile,at:position);return position
    }
    @discardableResult mutating func placeStructure(_ piece:Structure)->Int? {
        guard piece.valid else {return nil}
        structures.append(piece);return structures.count-1
    }
    @discardableResult mutating func moveTile(_ index:Int,x:Float,y:Float,z:Float)->Bool {
        guard tiles.indices.contains(index),canPlaceTile(x:x,y:y,z:z,excluding:index) else {return false}
        tiles[index].x=x;tiles[index].y=y;tiles[index].z=z;return true
    }
}

extension World {
    // A route is designed first. Decoration is then admitted only outside its
    // complete walking corridor, not merely outside the centres of its tiles.
    static func logicalLayout(_ architecture:Architecture,random:inout WorldRandom)->[Tile] {
        let count=architecture == .spiral ? 64 : 48
        let radius=random.range(5.5,6.8),phase=random.range(0,Double.pi*2)
        let lift=random.range(0.35,0.8)
        return (0..<count).map {i in
            let t=Double(i)/Double(architecture == .spiral ? count-1 : count),a=t*2 * Double.pi
            var x=0.0,z=0.0,y=1.8+lift*(1+sin(a+phase))
            switch architecture {
            case .terraces:
                func rounded(_ value:Double)->Double {copysign(pow(abs(value),0.8),value)}
                x=radius*rounded(cos(a));z=radius*0.78*rounded(sin(a))
            case .islands:
                let r=radius+0.6*cos(a*3+phase)
                x=r*cos(a);z=r*sin(a)
            case .ribbon:x=radius*1.15*cos(a);z=radius*0.58*sin(a)+0.4*sin(a*2)
            case .amphitheater:x=radius*cos(a);z=radius*0.8*sin(a);y=1.5+lift*(1-cos(a))
            case .spiral:
                let angle=a*1.5,r=radius-0.5*t
                x=r*cos(angle);z=r*sin(angle);y=1.5+t*5
            }
            return Tile(x:Float(x),y:Float(y),z:Float(z),note:60)
        }
    }
    func percussionStage()->(x:Float,y:Float,z:Float) {
        guard !tiles.isEmpty else {return(0,1,0)}
        let index=tileIndex(at:0,voice:voices.firstIndex(where:{$0.role == .percussion}) ?? 5),tile=tiles[index]
        let a=tiles[(index+tiles.count-1)%tiles.count],b=tiles[(index+1)%tiles.count]
        let length=max(0.001,hypot(b.x-a.x,b.z-a.z))
        var nx=(b.z-a.z)/length,nz = -(b.x-a.x)/length
        if length<0.01 {nx=1;nz=0}
        let cx=tiles.map(\.x).reduce(0,+)/Float(tiles.count),cz=tiles.map(\.z).reduce(0,+)/Float(tiles.count)
        if nx*(tile.x-cx)+nz*(tile.z-cz)<0 {nx = -nx;nz = -nz}
        if percussionStageDistance==nil {
            guard walkwayWidth>1 else {return(tile.x,tile.y,tile.z)}
            let distance=Float(walkwayWidth/2)+0.78
            return(tile.x+nx*distance,tile.y,tile.z+nz*distance)
        }
        let heading=atan2(Double(nz),Double(nx)),height=tile.y+0.35
        for extra in 0..<14 {
            let distance=(percussionStageDistance ?? 2.2)+Double(extra)*0.4
            for turn in [0.0,0.35,-0.35,0.7,-0.7,1.2,-1.2,Double.pi] {
                let x=Double(tile.x)+cos(heading+turn)*distance,z=Double(tile.z)+sin(heading+turn)*distance
                guard abs(x)<24,abs(z)<24 else {continue}
                let stage=PieceEnvelope(minX:x-0.95,minY:Double(height)-0.45,minZ:z-0.95,maxX:x+0.95,maxY:Double(height)+1.2,maxZ:z+0.95)
                if structures.contains(where:{$0.enabled && stage.overlaps($0.envelope)}) {continue}
                var clear=true
                for i in tiles.indices {
                    let u=tiles[i],v=tiles[(i+1)%tiles.count]
                    let dx=Double(v.x-u.x),dz=Double(v.z-u.z),length=dx*dx+dz*dz
                    let t=length<0.0001 ? 0 : max(0,min(1,((x-Double(u.x))*dx+(z-Double(u.z))*dz)/length))
                    let floor=Double(u.y)+Double(v.y-u.y)*t
                    if abs(floor-Double(tile.y))<1.6 && hypot(x-Double(u.x)-t*dx,z-Double(u.z)-t*dz)<walkwayWidth/2+1.2 {clear=false;break}
                }
                if clear {return(Float(x),height,Float(z))}
            }
        }
        return(tile.x+Float(walkwayWidth/2+8),height,tile.z)
    }
    func sceneryClearsRoute(_ piece:Structure)->Bool {
        guard !tiles.isEmpty else {return true}
        let centerY=Double(piece.y+piece.height/2)
        // Generous bounds include rotating rims, caps and decorative overhangs.
        let halfX=Double(max(piece.width,piece.depth))*0.62+walkwayWidth/2+0.3
        let halfY=Double(piece.height)*0.5+0.35
        for i in tiles.indices {
            let a=tiles[i],b=tiles[(i+1)%tiles.count]
            let steps=max(1,Int(ceil(hypot(b.x-a.x,b.z-a.z)/0.2)))
            for step in 0...steps {
                let t=Double(step)/Double(steps)
                let x=Double(a.x)+Double(b.x-a.x)*t,z=Double(a.z)+Double(b.z-a.z)*t,y=Double(a.y)+Double(b.y-a.y)*t
                if abs(x-Double(piece.x))<halfX && abs(z-Double(piece.z))<halfX && centerY+halfY>y-0.12 && centerY-halfY<y+1.5 {return false}
            }
        }
        let stage=percussionStage()
        return !(abs(Double(stage.x-piece.x))<halfX && abs(Double(stage.z-piece.z))<halfX && centerY+halfY>Double(stage.y)-0.12 && centerY-halfY<Double(stage.y)+1.3)
    }
}

struct PieceEnvelope {
    var minX:Double,minY:Double,minZ:Double,maxX:Double,maxY:Double,maxZ:Double
    func overlaps(_ other:PieceEnvelope,margin:Double=0.08)->Bool {
        minX<other.maxX+margin && maxX>other.minX-margin && minY<other.maxY+margin && maxY>other.minY-margin && minZ<other.maxZ+margin && maxZ>other.minZ-margin
    }
}
extension Structure {
    var moving:Bool {kind == .gear || kind == .orbit}
    // Includes every tooth and every orientation of an animated rim.
    var envelope:PieceEnvelope {
        let a=Double(rotation)*Double.pi/180,c=abs(cos(a)),s=abs(sin(a))
        let hx=Double(width)*(kind == .orbit ? 0.54 : 0.67),hz=Double(depth)*(kind == .orbit ? 0.54 : 0.67)
        let x=c*hx+s*hz,z=s*hx+c*hz
        let low:Double,high:Double
        if kind == .gear {let radius=Double(height)*0.67;low=Double(y+anchorHeight)-radius;high=Double(y+anchorHeight)+radius}
        else if kind == .orbit {low=Double(y+anchorHeight)-Double(height)*0.54;high=Double(y+anchorHeight)+Double(height)*0.54}
        else {low=Double(y)-0.1;high=Double(y)+Double(height)*(kind == .tree ? 1.17 : kind == .pavilion ? 1.06 : 1)+0.3}
        return PieceEnvelope(minX:Double(self.x)-x,minY:low,minZ:Double(self.z)-z,maxX:Double(self.x)+x,maxY:high,maxZ:Double(self.z)+z)
    }
}
extension World {
    func mechanismIsClear(_ index:Int)->Bool {
        let piece=structures[index]
        guard piece.enabled,piece.moving else {return true}
        let bounds=piece.envelope
        for j in structures.indices where j != index && structures[j].enabled {
            if bounds.overlaps(structures[j].envelope) {return false}
        }
        guard !tiles.isEmpty else {return true}
        if !sceneryClearsRoute(piece) {return false}
        for i in tiles.indices {
            let before=(i+tiles.count-1)%tiles.count,after=(i+1)%tiles.count
            if tiles[i].kind == .transpose || requiresPortalLink(from:i,to:after) || requiresPortalLink(from:before,to:i) {
                let tile=tiles[i],radius=max(1.6,walkwayWidth+0.55)/2
                let arch=PieceEnvelope(minX:Double(tile.x)-radius,minY:Double(tile.y),minZ:Double(tile.z)-radius,maxX:Double(tile.x)+radius,maxY:Double(tile.y)+2.2,maxZ:Double(tile.z)+radius)
                if bounds.overlaps(arch) {return false}
            }
        }
        let stage=percussionStage()
        return !bounds.overlaps(PieceEnvelope(minX:Double(stage.x)-0.95,minY:Double(stage.y)-0.45,minZ:Double(stage.z)-0.95,maxX:Double(stage.x)+0.95,maxY:Double(stage.y)+1.1,maxZ:Double(stage.z)+0.95))
    }
    var mechanismsClear:Bool {structures.indices.allSatisfy{mechanismIsClear($0)}}
    // Repair overlapping legacy mechanisms in model space, so the displayed,
    // saved and exported positions agree. User placement uses rejection instead.
    mutating func repairMechanisms() {
        for index in structures.indices where structures[index].moving && structures[index].enabled {
            guard !mechanismIsClear(index) else {continue}
            let original=structures[index]
            var found=false
            for radius in stride(from:0.5,through:24.0,by:0.5) {
                for sector in 0..<32 {
                    let angle=Double(sector)*Double.pi/16
                    structures[index].x=original.x+Float(cos(angle)*radius)
                    structures[index].z=original.z+Float(sin(angle)*radius)
                    if structures[index].valid && mechanismIsClear(index) {found=true;break}
                }
                if found {break}
            }
            if !found {structures[index]=original;structures[index].enabled=false}
        }
    }
}

// Modules expand into the same editable world records as individual pieces.
enum WorldModule:String,CaseIterable,Identifiable {
    case stairs,rhythm,strings,wind,garden,courtyard,cascade,maze
    var id:String {rawValue}
    var title:String {switch self {case .stairs:return "Musical stairs";case .rhythm:return "Rhythm terrace";case .strings:return "String bridge";case .wind:return "Wind tower";case .garden:return "Quiet garden";case .courtyard:return "Echo courtyard";case .cascade:return "Waterfall walk";case .maze:return "Woodland maze"}}
    var symbol:String {switch self {case .stairs:return "stairs";case .rhythm:return "drum.fill";case .strings:return "guitars";case .wind:return "wind";case .garden:return "leaf.fill";case .courtyard:return "building.columns";case .cascade:return "water.waves";case .maze:return "square.split.2x2"}}
    var kind:PadKind {switch self {case .stairs:return .note;case .rhythm:return .drum;case .strings:return .harp;case .wind:return .wind;case .garden,.courtyard:return .chord;case .cascade:return .harp;case .maze:return .wood}}
    var voice:Int {switch self {case .stairs,.strings,.wind,.cascade:return 0;case .maze:return 1;case .rhythm:return 5;case .garden,.courtyard:return 4}}
    var dragValue:String {"soundlings-module:"+rawValue}
    init?(dragValue:String) {guard dragValue.hasPrefix("soundlings-module:") else {return nil};self.init(rawValue:String(dragValue.dropFirst(18)))}
}

extension WorldModule {
    var path:[(Float,Float,Float)] {
        switch self {
        case .courtyard:
            return [(0,0,0),(1,0,0),(2,0,0),(2,0,1),(2,0,2),(3,0,2),(4,0,2),(4,0,1),(4,0,0),(5,0,0),(6,0,0),(7,0,0)]
        case .maze:
            return [(0,0,0),(1,0,0),(1,0,1),(1,0,2),(2,0,2),(3,0,2),(3,0,1),(3,0,0),(4,0,0),(5,0,0),(5,0,1),(5,0,2),(6,0,2),(7,0,2),(7,0,1),(7,0,0),(8,0,0),(9,0,0)]
        case .cascade:
            return (0..<14).map {i -> (Float,Float,Float) in
                let forward=Float(i),height=Float(i)*0.16,lateral=Float(i<7 ? i : 13-i)*0.3
                return (forward,height,lateral)
            }
        default:
            return (0..<6).map {i -> (Float,Float,Float) in
                let height:Float = self == .stairs || self == .wind ? Float(i+1)*0.18 : 0
                return (Float(i),height,0)
            }
        }
    }
    var complex:Bool {path.count>6}
}

extension World {
    func moduleHasRoom(_ id:UUID)->Bool {
        let owned=tiles.filter{$0.moduleID==id},others=tiles.filter{$0.moduleID != id}
        let clearance=Float(max(0.9,walkwayWidth))
        for t in owned {
            if others.contains(where:{hypot($0.x-t.x,$0.z-t.z)<clearance && abs($0.y-t.y)<1}) {return false}
        }
        func corridor(_ tiles:[Tile],against structures:[Structure])->Bool {
            for t in tiles {
                let r=max(0.5,walkwayWidth/2)
                let body=PieceEnvelope(minX:Double(t.x)-r,minY:Double(t.y)+0.15,minZ:Double(t.z)-r,maxX:Double(t.x)+r,maxY:Double(t.y)+1.3,maxZ:Double(t.z)+r)
                if structures.contains(where:{$0.enabled && body.overlaps($0.envelope)}) {return false}
            }
            return true
        }
        let ownStructures=structures.filter{$0.moduleID==id},otherStructures=structures.filter{$0.moduleID != id}
        guard corridor(owned,against:structures),corridor(others,against:ownStructures) else {return false}
        return !ownStructures.contains {a in otherStructures.contains {b in a.enabled && b.enabled && a.envelope.overlaps(b.envelope)}}
    }
}

extension World {
    // Recover only the exact six-step geometry produced by the earlier module shelf.
    mutating func recoverLegacyModules() {
        guard !tiles.isEmpty,tiles.count%6==0,structures.count==tiles.count/6,
            tiles.allSatisfy({$0.moduleID==nil}),structures.allSatisfy({$0.moduleID==nil}) else {return}
        let spacing=Float(max(1.4,walkwayWidth+0.1)),side=Float(max(2,walkwayWidth+1.2))
        for block in structures.indices {
            let first=tiles[block*6],next=tiles[block*6+1]
            let ux=(next.x-first.x)/spacing,uz=(next.z-first.z)/spacing
            guard abs(abs(ux)+abs(uz)-1)<0.001,(abs(ux)<0.001 || abs(uz)<0.001) else {return}
            let rise=next.y-first.y
            guard abs(rise)<0.001 || abs(rise-0.18)<0.001 else {return}
            for i in 0..<6 {
                let t=tiles[block*6+i]
                guard t.kind==first.kind,abs(t.x-first.x-ux*Float(i)*spacing)<0.001,abs(t.z-first.z-uz*Float(i)*spacing)<0.001,abs(t.y-first.y-rise*Float(i))<0.001 else {return}
            }
            let center=tiles[block*6+3],p=structures[block]
            let lateral=(p.x-center.x)*(-uz)+(p.z-center.z)*ux
            let forward=(p.x-center.x)*ux+(p.z-center.z)*uz
            guard abs(forward)<0.001,abs(abs(lateral)-side)<0.001 else {return}
        }
        for block in structures.indices {
            let id=UUID();structures[block].moduleID=id
            for i in 0..<6 {tiles[block*6+i].moduleID=id}
        }
    }
}
