import SwiftUI
import SceneKit

@MainActor final class BuildTutorialController:ObservableObject {
    let plan:BuildTutorialPlan
    let garden:GardenScene
    @Published private(set) var stepIndex=0
    @Published var focused=false
    private var bare=[SCNNode]()
    private var connections=[(SCNNode,Int)]()
    private let outline=SCNNode()
    var step:TutorialStep {plan.steps[stepIndex]}
    var last:Bool {stepIndex==plan.steps.count-1}
    init(_ world:World) {
        plan=BuildTutorialPlan(world);garden=GardenScene(world)
        // Bare platforms show the foundation before musical tops are installed.
        for tile in world.tiles {
            let root=SCNNode();root.position=SCNVector3(tile.x,tile.y,tile.z);root.eulerAngles.y=SceneScalar(tile.rotation * .pi/180)
            garden.sculpture.addChildNode(root)
            garden.box(0.94,0.24,0.94,garden.stone,SCNVector3(0,-0.12,0),parent:root)
            bare.append(root)
        }
        for node in garden.sculpture.childNodes where node.name=="walkSurface" {
            var nearest=0,distance=Double.infinity
            for i in world.tiles.indices {
                let a=world.tiles[i],b=world.tiles[(i+1)%world.tiles.count]
                let dx=Double(b.x-a.x),dz=Double(b.z-a.z),length=dx*dx+dz*dz
                let t=length<0.0001 ? 0 : max(0,min(1,((Double(node.position.x)-Double(a.x))*dx+(Double(node.position.z)-Double(a.z))*dz)/length))
                let d=hypot(Double(node.position.x)-Double(a.x)-dx*t,Double(node.position.z)-Double(a.z)-dz*t)
                if d<distance {distance=d;nearest=i}
            }
            connections.append((node,max(nearest,(nearest+1)%max(1,world.tiles.count))))
        }
        outline.name="tutorialHighlight";garden.sculpture.addChildNode(outline)
        apply()
    }
    func setStep(_ value:Int) {stepIndex=min(plan.steps.count-1,max(0,value));apply()}
    func advance(_ delta:Int=1) {setStep(stepIndex+delta)}
    func jump(_ chapter:TutorialChapter) {if let index=plan.steps.firstIndex(where:{$0.chapter==chapter}) {setStep(index)}}
    private func apply() {
        let step=self.step,world=plan.world
        let chapterOrder=TutorialChapter.allCases.firstIndex(of:step.chapter)!
        func passed(_ chapter:TutorialChapter)->Bool {chapterOrder>TutorialChapter.allCases.firstIndex(of:chapter)!}
        let overview=step.chapter == .overview,complete=step.chapter == .finished
        func opacity(_ built:Bool,_ current:Bool=false)->CGFloat {current ? 1 : built ? 0.95 : 0.055}
        for i in world.tiles.indices {
            let path=passed(.path) || (step.chapter == .path && i<=step.index)
            let instrument=passed(.instruments) || (step.chapter == .instruments && i<=step.index)
            bare[i].isHidden=instrument || overview || complete
            bare[i].opacity=opacity(path,step.chapter == .path && i==step.index)
            garden.tileNodes[i].opacity=overview || complete ? 1 : instrument ? 1 : 0
        }
        for (node,lastTile) in connections {node.opacity=overview || complete ? 1 : opacity(passed(.path) || (step.chapter == .path && lastTile<=step.index))}
        for portal in garden.portals {portal.parent?.opacity=overview || complete || passed(.path) ? 1 : 0.055}
        for i in world.structures.indices {
            let node=garden.structureNodes[i],current=step.chapter == .scenery && step.index==i
            node.isHidden = !world.structures[i].enabled && !current
            node.opacity=overview || complete ? 1 : opacity(passed(.scenery) || (step.chapter == .scenery && i<=step.index),current)
        }
        for i in garden.walkers.indices {
            let current=step.chapter == .characters && i==step.index
            let visible=(overview || complete || passed(.characters) || (step.chapter == .characters && i<=step.index)) && world.voices[i].enabled
            garden.walkers[i].isHidden = !visible && !current
            garden.walkers[i].opacity=world.voices[i].enabled ? 1 : 0.35
            if garden.contactShadows.indices.contains(i) {garden.contactShadows[i].isHidden=garden.walkers[i].isHidden}
        }
        let percussion=world.voices.firstIndex{$0.role == .percussion} ?? 5
        garden.sculpture.childNode(withName:"drumStageRoot",recursively:false)?.isHidden = !(garden.walkers.indices.contains(percussion) && !garden.walkers[percussion].isHidden)
        garden.selection.isHidden=true
        outline.childNodes.forEach{$0.removeFromParentNode()}
        if let target=targetNode {
            let b=target.boundingBox
            var points=[SCNVector3]()
            for x in [b.min.x,b.max.x] {for y in [b.min.y,b.max.y] {for z in [b.min.z,b.max.z] {points.append(target.convertPosition(SCNVector3(x,y,z),to:garden.sculpture))}}}
            let minX=points.map(\.x).min()!,maxX=points.map(\.x).max()!,minY=points.map(\.y).min()!,maxY=points.map(\.y).max()!,minZ=points.map(\.z).min()!,maxZ=points.map(\.z).max()!
            let box=garden.box(CGFloat(maxX-minX)+0.12,CGFloat(maxY-minY)+0.12,CGFloat(maxZ-minZ)+0.12,.systemYellow,SCNVector3((minX+maxX)/2,(minY+maxY)/2,(minZ+maxZ)/2),parent:outline)
            box.geometry?.firstMaterial?.fillMode = .lines;box.geometry?.firstMaterial?.lightingModel = .constant
            box.geometry?.firstMaterial?.emission.contents=UIColor.systemYellow
        }
    }
    var targetNode:SCNNode? {
        switch step.chapter {
        case .path:return bare[step.index]
        case .instruments:return garden.tileNodes[step.index]
        case .scenery:return garden.structureNodes[step.index]
        case .characters:return garden.walkers.indices.contains(step.index) ? garden.walkers[step.index] : nil
        default:return nil
        }
    }
    func frame(_ size:CGSize) {
        guard size.width>0,size.height>0 else {return}
        garden.frame(size:size,zoom:1.04,pan:.zero,follow:false)
        if focused,let node=targetNode {
            let b=node.boundingBox
            let center=node.convertPosition(SCNVector3((b.min.x+b.max.x)/2,(b.min.y+b.max.y)/2,(b.min.z+b.max.z)/2),to:nil)
            garden.camera.position=SCNVector3(center.x+24,center.y+19,center.z+27)
            garden.camera.look(at:center,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
            let width=Double(b.max.x-b.min.x),height=Double(b.max.y-b.min.y),depth=Double(b.max.z-b.min.z)
            let scale=max(1.8,max(height,max(width,depth)*Double(size.height/size.width))*0.85+0.6)
            garden.camera.camera?.orthographicScale=scale
            let aspect=Double(size.width/size.height)
            garden.placeEnvironment(radius:max(12,scale*sqrt(1+aspect*aspect)*1.2))
        }
    }
}
