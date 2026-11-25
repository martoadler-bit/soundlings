import Foundation

extension Game {
    var hasBuildSelection:Bool {
        if let selectedStructure {return world.structures.indices.contains(selectedStructure)}
        return world.tiles.indices.contains(selected)
    }
    var selectionTitle:String {
        if let i=selectedStructure,world.structures.indices.contains(i) {return world.structures[i].kind.title}
        return world.tiles.indices.contains(selected) ? "Step \(selected+1) · \(world.tiles[selected].kind.title)" : "Choose your first piece"
    }
    func sanitizeBuilderSelection() {if let i=selectedStructure,!world.structures.indices.contains(i) {selectedStructure=nil}}
    func beginBuilding() {
        world.recoverLegacyModules()
        stop();fullScreen=false;building=true;panel=nil;home();buildTool = .select
        if let i=selectedStructure,world.structures.indices.contains(i) {buildHeight=world.structures[i].y}
        else if world.tiles.indices.contains(selected) {buildHeight=world.tiles[selected].y}
        else {buildHeight=1}
        garden.lockBuilderCamera(true)
        message=simpleBuilding ? "Drag a module here, or tap one to start." : "Choose a piece and tap to place. Hold a piece to drag it."
    }
    func finishBuilding() {
        endBuildDrag(cancelled:false);building=false;panel=nil;buildTool = .select
        garden.lockBuilderCamera(false)
    }
    func chooseBuildItem(_ item:BuildItem) {buildItem=item;buildTool = .place;message="Tap beside your path to add \(item.title). Connections take care of themselves."}
    func selectBuildTile(_ index:Int) {
        guard world.tiles.indices.contains(index) else {return}
        selected=index;selectedStructure=nil;buildHeight=world.tiles[index].y;buildTool = .select
        message=simpleBuilding && selectedModuleID != nil ? "Hold any piece to move the whole module." : "\(selectionTitle). Hold to move it, or change its sound."
    }
    func selectBuildStructure(_ index:Int) {
        guard world.structures.indices.contains(index) else {return}
        selectedStructure=index;buildHeight=world.structures[index].y;buildTool = .select
        message=simpleBuilding && selectedModuleID != nil ? "Hold any piece to move the whole module." : "\(selectionTitle). Hold to move it, or change its sound."
    }
    func snapped(_ value:Float)->Float {snapToGrid ? value.rounded() : value}
    func placeBuildItem(x:Float,z:Float) {
        var candidate=world
        var x=snapped(x),z=snapped(z)
        var height=buildHeight
        if simpleBuilding,case .tile = buildItem,!world.tiles.isEmpty {
            let anchor=world.tiles[world.tiles.indices.contains(selected) ? selected : world.tiles.count-1]
            let dx=x-anchor.x,dz=z-anchor.z
            let spacing=Float(max(1.2,world.walkwayWidth))
            if abs(dx)>=abs(dz) {x=anchor.x+(dx<0 ? -spacing : spacing);z=anchor.z}
            else {x=anchor.x;z=anchor.z+(dz<0 ? -spacing : spacing)}
            height=anchor.y
        }
        switch buildItem {
        case .tile(let kind):
            let tile=Tile(x:x,y:height,z:z,note:world.tiles.indices.contains(selected) ? world.tiles[selected].note : 60,kind:kind)
            let after=world.tiles.isEmpty || selectedStructure != nil ? nil : (world.reversed ? selected-1 : selected)
            guard let index=candidate.placeTile(tile,after:after),candidate.valid else {message="That space is occupied or outside the world. Try another spot.";return}
            guard candidate.mechanismsClear else {message="Leave room around rotating mechanisms.";return}
            mutate{$0=candidate};selected=index;selectedStructure=nil
        case .structure(let kind):
            let piece=World.piece(kind,x:x,y:buildHeight,z:z)
            guard let index=candidate.placeStructure(piece),candidate.valid else {message="That piece is outside the world limits.";return}
            guard candidate.mechanismsClear else {message="This piece overlaps a rotating mechanism or its full sweep. Choose a clear spot.";return}
            mutate{$0=candidate};selectedStructure=index
        }
        buildHeight=height
        message="\(buildItem.title) added. Tap beside it to keep building."
    }
    func extendBuildPath() {
        if case .structure = buildItem {buildItem = .tile(.rest)}
        guard world.tiles.indices.contains(selected) else {placeBuildItem(x:0,z:0);return}
        let tile=world.tiles[selected]
        let previous=world.tiles.indices.contains(selected-1) ? world.tiles[selected-1] : nil
        let dx=tile.x-(previous?.x ?? tile.x-1),dz=tile.z-(previous?.z ?? tile.z)
        placeBuildItem(x:tile.x+dx,z:tile.z+dz)
    }
    func changeBuildSound(_ kind:PadKind) {
        guard selectedStructure==nil,world.tiles.indices.contains(selected) else {return}
        let index=selected
        mutate {$0.tiles[index].kind=kind}
        message="Sound changed. Press Play to hear your world."
    }
    func addModule(_ module:WorldModule,x:Float?=nil,z:Float?=nil) {
        guard !rendering,!exporting else {return}
        var candidate=world
        let end=world.tiles.last
        let baseX=end?.x ?? snapped(x ?? 0),baseZ=end?.z ?? snapped(z ?? 0),baseY=end?.y ?? 1
        let dx=(x ?? (baseX+2))-baseX,dz=(z ?? baseZ)-baseZ
        let ux:Float=abs(dx)>=abs(dz) ? (dx<0 ? -1 : 1) : 0
        let uz:Float=ux==0 ? (dz<0 ? -1 : 1) : 0
        let spacing=Float(max(1.4,world.walkwayWidth+0.1))
        let moduleID=UUID()
        for (i,point) in module.path.enumerated() {
            let forward=(point.0+(end == nil ? 0 : 1))*spacing,lateral=point.2*spacing
            var tile=Tile(x:baseX+ux*forward-uz*lateral,y:baseY+point.1,z:baseZ+uz*forward+ux*lateral,note:60+[0,2,4,7,4,2][i%6],kind:module.complex ? [module.kind,.rest,module.kind,.filter][i%4] : module.kind)
            tile.moduleID=moduleID
            guard candidate.canPlaceTile(x:tile.x,y:tile.y,z:tile.z),
                !world.tiles.contains(where:{hypot($0.x-tile.x,$0.z-tile.z)<spacing*0.7 && abs($0.y-tile.y)<1}) else {message="That direction is busy. Drop beside the end of the path in another direction.";return}
            candidate.tiles.append(tile)
        }
        // Ornaments stay on the opposite side of the route's bends.
        let side=Float(max(2,world.walkwayWidth+1.2))
        let slots=module.complex ? [2,module.path.count/2,module.path.count-3] : [module.path.count-3]
        for (slot,index) in slots.enumerated() {
            let center=candidate.tiles[world.tiles.count+index]
            let decoration:StructureKind=module == .garden || module == .maze ? .tree : module == .wind ? .column : module == .cascade ? .waterfall : module == .courtyard && slot==1 ? .pavilion : .arch
            var ornament=World.piece(decoration,x:center.x+uz*side+uz*module.path[index].2*spacing,y:baseY-0.3,z:center.z-ux*side-ux*module.path[index].2*spacing)
            ornament.moduleID=moduleID
            candidate.structures.append(ornament)
        }
        guard candidate.valid,candidate.mechanismsClear else {message="Leave a little more room for this module. Try another direction.";return}
        guard candidate.moduleHasRoom(moduleID) else {message="Leave room beside the path for this module.";return}
        if candidate.voices.indices.contains(module.voice) {candidate.voices[module.voice].enabled=true}
        candidate.stayInScale=true
        mutate {$0=candidate}
        selected=world.tiles.count-1;selectedStructure=nil;buildHeight=world.tiles[selected].y;buildTool = .select
        garden.lockBuilderCamera(false);home();garden.lockBuilderCamera(true)
        message="\(module.title) ready. Drag another module beside the end, or press Play."
    }
    var selectedModuleID:UUID? {
        if let i=selectedStructure,world.structures.indices.contains(i) {return world.structures[i].moduleID}
        return world.tiles.indices.contains(selected) ? world.tiles[selected].moduleID : nil
    }
    var buildSelectionPoint:(Float,Float,Float) {
        if let i=selectedStructure,world.structures.indices.contains(i) {let p=world.structures[i];return(p.x,p.y,p.z)}
        if world.tiles.indices.contains(selected) {let p=world.tiles[selected];return(p.x,p.y,p.z)}
        return(0,1,0)
    }
    func moveBuildSelection(x:Float,y:Float,z:Float,continuous:Bool=false,snap:Bool=true) {
        guard hasBuildSelection else {return}
        let requestedX=x,requestedZ=z
        var x=snap ? snapped(x) : x,z=snap ? snapped(z) : z
        if continuous && snap && snapToGrid {
            let ox=selectedStructure.map{world.structures[$0].x} ?? world.tiles[selected].x
            let oz=selectedStructure.map{world.structures[$0].z} ?? world.tiles[selected].z
            x=ox+(requestedX-ox).rounded();z=oz+(requestedZ-oz).rounded()
        }
        var candidate=world
        if simpleBuilding,let id=selectedModuleID {
            let anchor=buildSelectionPoint
            let dx=x-anchor.0,dy=y-anchor.1,dz=z-anchor.2
            for i in candidate.tiles.indices where candidate.tiles[i].moduleID==id {candidate.tiles[i].x+=dx;candidate.tiles[i].y+=dy;candidate.tiles[i].z+=dz}
            for i in candidate.structures.indices where candidate.structures[i].moduleID==id {candidate.structures[i].x+=dx;candidate.structures[i].y+=dy;candidate.structures[i].z+=dz}
            guard candidate.moduleHasRoom(id) else {message="That module needs more room. Try a clear spot.";return}
        } else if let index=selectedStructure {
            candidate.structures[index].x=x;candidate.structures[index].y=y;candidate.structures[index].z=z
        } else if !candidate.moveTile(selected,x:x,y:y,z:z) {message="That space is occupied or outside the world.";return}
        guard candidate.valid else {message="Keep the piece inside the world limits.";return}
        guard candidate.mechanismsClear else {message="Leave room for the full turn of every wheel.";return}
        if continuous {dragCandidate=candidate;garden.moveBuildPreview(x:x,y:y,z:z)} else {mutate{$0=candidate}}
        buildHeight=y
        if !continuous {buildTool = .select;message="Piece moved. Connections updated."}
    }
    func beginBuildDrag() {
        guard building,hasBuildSelection else {return}
        stop();dragStart=world;dragCandidate=world;buildTool = .move
        if simpleBuilding,let id=selectedModuleID {
            garden.beginModulePreview(world,id:id,anchor:buildSelectionPoint)
            return
        }
        garden.beginBuildPreview(tile:selectedStructure==nil ? selected : nil,structure:selectedStructure,anchorHeight:selectedStructure.map{world.structures[$0].anchorHeight} ?? 0)
    }
    func endBuildDrag(cancelled:Bool) {
        guard let original=dragStart else {return}
        let candidate=dragCandidate ?? original
        dragStart=nil;dragCandidate=nil;garden.endBuildPreview()
        if !cancelled && (try? original.encoded()) != (try? candidate.encoded()) {
            history.append(original);if history.count>24 {history.removeFirst()};future=[]
            world=candidate;garden.rebuild(world)
            if simpleBuilding {garden.lockBuilderCamera(false);home()}
        }
        buildTool = .select;message=cancelled ? "Move cancelled." : "Piece moved. Undo is always available."
    }
    func rotateBuildSelection() {
        guard hasBuildSelection else {return}
        var candidate=world
        if let i=selectedStructure {candidate.structures[i].rotation=(candidate.structures[i].rotation+90).truncatingRemainder(dividingBy:360)}
        else {candidate.tiles[selected].rotation=(candidate.tiles[selected].rotation+90).truncatingRemainder(dividingBy:360)}
        guard candidate.mechanismsClear else {message="That rotation needs more space.";return}
        mutate{$0=candidate}
        message="Rotated 90°."
    }
    func deleteBuildSelection() {
        guard hasBuildSelection else {return}
        if let i=selectedStructure {mutate{$0.structures.remove(at:i)};selectedStructure=nil}
        else {remove()}
        buildTool = .select;message="Piece removed. Undo brings it back."
    }
    func duplicateBuildSelection() {
        guard hasBuildSelection else {return}
        if let i=selectedStructure {
            let original=world.structures[i]
            var candidate=world,placed:Int?
            outer: for radius in 1...8 {for direction in [(1,0),(0,1),(-1,0),(0,-1)] {
                var piece=original;piece.moduleID=nil;piece.x+=Float(direction.0*radius);piece.z+=Float(direction.1*radius)
                var trial=world
                if let index=trial.placeStructure(piece),trial.valid,trial.mechanismsClear {candidate=trial;placed=index;break outer}
            }}
            guard let index=placed else {message="No clear room for a copy here.";return}
            mutate{$0=candidate};selectedStructure=index
        } else {
            var piece=world.tiles[selected];piece.moduleID=nil
            var candidate=world
            let spots:[(Float,Float)]=[(1,0),(0,1),(-1,0),(0,-1)]
            guard let spot=spots.first(where:{world.canPlaceTile(x:piece.x+$0.0,y:piece.y,z:piece.z+$0.1)}) else {message="No room for a copy beside this step.";return}
            piece.x+=spot.0;piece.z+=spot.1
            guard let index=candidate.placeTile(piece,after:selected),candidate.valid else {return}
            mutate{$0=candidate};selected=index
        }
        buildTool = .select;message="Copy created. Hold it to move it."
    }
    func updateBuildStructure(_ action:(inout Structure)->Void) {
        guard let i=selectedStructure,world.structures.indices.contains(i) else {return}
        var candidate=world;action(&candidate.structures[i])
        guard candidate.valid else {message="That value is outside the building limits.";return}
        guard candidate.mechanismsClear else {message="Those dimensions would overlap a rotating mechanism.";return}
        mutate{$0=candidate};buildHeight=world.structures[i].y
    }
    func raiseBuildSelection(_ delta:Float) {
        if let i=selectedStructure,world.structures.indices.contains(i) {let p=world.structures[i];moveBuildSelection(x:p.x,y:p.y+delta,z:p.z,snap:false)}
        else if world.tiles.indices.contains(selected) {let p=world.tiles[selected];moveBuildSelection(x:p.x,y:p.y+delta,z:p.z,snap:false)}
    }
}
