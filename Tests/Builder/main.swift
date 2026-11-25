import Foundation
import SceneKit
var checks=0
func check(_ condition:@autoclosure()->Bool,_ message:String) {guard condition() else {fatalError(message)};checks+=1}
// Reconstruct every generated world exclusively through the public manual-placement operations.
// World metadata and music settings are copied; every visual record is rebuilt through the shared placement API.
var seen=Set<StructureKind>()
for seed:UInt64 in 0..<200 {
    let original=World.generate(seed:seed)
    var built=original;built.tiles=[];built.structures=[]
    for tile in original.tiles {check(built.placeTile(tile) != nil,"Every generated tile is manually placeable: seed \(seed)")}
    for piece in original.structures {
        seen.insert(piece.kind)
        check(built.placeStructure(piece) != nil,"Every generated structure uses the manual catalogue")
    }
    check(built.valid,"Reconstructed world remains valid")
    check(try! built.encoded()==original.encoded(),"Manual reconstruction exactly reproduces the generated world")
}
check(seen==Set(StructureKind.allCases),"All generated scenery is in the palette")
var blank=World.blank
check(blank.structures.isEmpty,"Blank has no hidden scaffolding")
for kind in StructureKind.allCases {
    let piece=World.piece(kind,x:2,y:1,z:2)
    check(piece.valid && blank.placeStructure(piece) != nil,"Palette defaults can be placed before any path")
}
let sceneryOnly=GardenScene(blank)
check(sceneryOnly.structureNodes.count==StructureKind.allCases.count && sceneryOnly.walkers.isEmpty,"Scenery-only worlds render without implicit characters")
sceneryOnly.update(blank,beat:1,selected:nil)
sceneryOnly.frame(size:CGSize(width:393,height:852),zoom:1,pan:.zero,follow:false)
let original=World.garden
var old=try! JSONSerialization.jsonObject(with:original.encoded()) as! [String:Any]
old.removeValue(forKey:"structures")
var migrated=try! JSONDecoder().decode(World.self,from:JSONSerialization.data(withJSONObject:old))
migrated.repairMechanisms()
check(migrated.structures==original.structures,"Legacy scenery becomes editable without visual reinvention")
var cleared=migrated;cleared.structures=[]
let loaded=try! JSONDecoder().decode(World.self,from:cleared.encoded())
check(loaded.structures.isEmpty,"Deleted structures never regenerate after reload")
let scene=GardenScene(original)
check(scene.structureNodes.count==original.structures.count,"One selectable root per stored piece")
for (i,node) in scene.structureNodes.enumerated() {check(node.name=="structure_\(i)","Stored structure can be hit-tested")}
let before=scene.boundsMax
scene.lockBuilderCamera(true)
var moved=original;moved.structures[0].x+=10
scene.rebuild(moved)
check(scene.builderBounds?.1.x==before.x,"Placing and dragging cannot recenter the camera")
scene.showBuilderGuide(enabled:true,height:3,structure:0)
check(abs(Double(scene.builderGrid!.position.y)-3.012)<0.00001,"Placement grid follows elevation")
check(scene.builderOutline != nil,"Selected architecture has a visible outline")
scene.showBuilderGuide(enabled:false,height:3,structure:nil)
check(scene.builderGrid?.isHidden==true && scene.builderOutline?.isHidden==true,"Builder guides leave the playback image clean")
var precise=World.blank
let tile=Tile(x:1.234567,y:3.345678,z:-2.987654,note:67,kind:.harp)
check(precise.placeTile(tile)==0,"Fractional coordinates are accepted")
check(!precise.moveTile(0,x:Float.nan,y:1,z:0),"Invalid move rejected without mutation")
check(!precise.moveTile(0,x:Float.infinity,y:1,z:0),"Nonfinite moves are rejected")
check(precise.tiles[0].x==tile.x,"Rejected moves preserve position")
check(precise.moveTile(0,x:210,y:40,z:-80),"Finite placement is no longer confined to a fixed-size world")
var rotated=precise;rotated.tiles[0].rotation=37
let rotatedScene=GardenScene(rotated)
check(rotated.valid && rotatedScene.pads.count==1,"Arbitrary step rotation remains a musical piece")
var invalid=World.blank
var piece=World.piece(.arch);piece.width = .nan;invalid.structures=[piece]
check(!invalid.valid,"Reject nonfinite scenery dimensions")
print("\(checks) shared-catalogue, exact-reconstruction and builder scene checks passed.")
