import Foundation
import SceneKit
var checks=0
func check(_ value:Bool,_ message:String) {guard value else {fatalError(message)};checks+=1}
MainActor.assumeIsolated {
    for seed:UInt64 in 0..<5 {
        let world=World.generate(seed:seed),original=try! world.encoded()
        let tutorial=BuildTutorialController(world)
        check(tutorial.plan.steps.first?.chapter == .overview && tutorial.plan.steps.last?.chapter == .finished,"Guide has introduction and completion")
        check(tutorial.plan.steps.filter{$0.chapter == .path}.count==world.tiles.count,"Every foundation piece is taught")
        check(tutorial.plan.steps.filter{$0.chapter == .instruments}.count==world.tiles.filter{$0.kind != .rest}.count,"Every sounding top is taught")
        check(tutorial.plan.steps.filter{$0.chapter == .scenery}.count==world.structures.count,"Every scenery piece is taught")
        for i in tutorial.plan.steps.indices {
            tutorial.setStep(i)
            check(!tutorial.plan.title(tutorial.step).isEmpty && !tutorial.plan.instruction(tutorial.step).isEmpty,"Every step has clear instructions")
            check(!tutorial.plan.details(tutorial.step).isEmpty,"Every step provides exact settings")
            if [.path,.instruments,.scenery,.characters].contains(tutorial.step.chapter) {check(tutorial.targetNode != nil,"Every placed piece has a visible target")}
        }
        check(try! tutorial.plan.world.encoded()==original,"Tutorial never mutates the source or its musical settings")
        check(tutorial.garden.structureNodes.enumerated().allSatisfy{$0.element.isHidden == !world.structures[$0.offset].enabled},"Completed scene preserves hidden scenery")
        check(tutorial.garden.walkers.enumerated().allSatisfy{$0.element.isHidden == !world.voices[$0.offset].enabled},"Completed scene preserves exact character states")
        tutorial.setStep(-10);check(tutorial.stepIndex==0,"Back is clamped at the beginning")
        tutorial.setStep(10000);check(tutorial.last,"Forward is clamped at completion")
        for chapter in tutorial.plan.chapters {
            tutorial.jump(chapter);check(tutorial.step.chapter==chapter,"Chapter navigation lands correctly")
        }
        tutorial.jump(.path);tutorial.focused=true
        tutorial.frame(CGSize(width:393,height:350))
        check(tutorial.garden.camera.camera!.orthographicScale>0,"Piece focus keeps a valid camera")
    }
    var scenery=World.blank;scenery.structures=[World.piece(.orbit)]
    let isolated=BuildTutorialController(scenery)
    check(!isolated.plan.chapters.contains(.path) && !isolated.plan.chapters.contains(.characters),"Scenery-only guides do not invent paths or characters")
    isolated.jump(.scenery);check(isolated.targetNode != nil,"Scenery-only guide highlights the actual structure")
    let empty=BuildTutorialController(.blank)
    empty.setStep(0);empty.frame(.zero)
    check(empty.targetNode==nil,"Empty sources remain safe")
}
print("\(checks) exact-world tutorial coverage, reveal, navigation and immutable-source checks passed.")
