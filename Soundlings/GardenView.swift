import SwiftUI
import SceneKit
import UniformTypeIdentifiers

final class WorldViewport:SCNView {
    var onLayout:(()->Void)?
    let transitionShade=UIView()
    override init(frame:CGRect,options:[String:Any]?=nil) {
        super.init(frame:frame,options:options)
        transitionShade.backgroundColor = .black;transitionShade.alpha=0
        transitionShade.isUserInteractionEnabled=false;addSubview(transitionShade)
    }
    required init?(coder:NSCoder) {fatalError("Use programmatic initialization")}

    override func layoutSubviews() {
        super.layoutSubviews()
        transitionShade.frame=bounds
        SCNTransaction.begin(); SCNTransaction.disableActions=true
        onLayout?()
        SCNTransaction.commit()
        setNeedsDisplay()
    }
}
struct GardenView:UIViewRepresentable {
    @ObservedObject var game:Game
    var beat:Double
    var atmosphereTime:Double?
    func makeCoordinator() -> Coordinator { Coordinator(game) }
    func makeUIView(context:Context) -> SCNView {
        let view=WorldViewport(frame:.zero);view.addInteraction(UIDropInteraction(delegate:context.coordinator)); view.scene=game.garden.scene; view.pointOfView=game.garden.camera
        view.antialiasingMode = .multisampling4X; view.isPlaying=true
        view.rendersContinuously=true
        view.preferredFramesPerSecond=60
        view.onLayout = { [weak view, weak game=game] in
            guard let view,let game else { return }
            game.garden.frame(size:view.bounds.size,zoom:game.zoom,pan:game.pan,follow:game.follow,voice:game.cameraVoice,firstPerson:game.firstPerson,lookYaw:game.lookYaw,frontView:game.frontView)
        }
        let hold=UILongPressGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.hold(_:)))
        hold.minimumPressDuration=0.25
        let tap=UITapGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.tap(_:)))
        let pinch=UIPinchGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.pinch(_:)))
        let orbit=UIPanGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.orbit(_:)))
        orbit.maximumNumberOfTouches=1
        let pan=UIPanGestureRecognizer(target:context.coordinator,action:#selector(Coordinator.pan(_:)))
        pan.minimumNumberOfTouches=2; pan.maximumNumberOfTouches=2
        orbit.require(toFail:hold)
        tap.require(toFail:hold)
        for gesture in [tap,pinch,orbit,pan,hold] { gesture.delegate=context.coordinator; view.addGestureRecognizer(gesture) }
        view.accessibilityLabel="Soundlings three-dimensional musical world. Pinch to zoom, drag to rotate, two fingers to move."
        return view
    }
    func updateUIView(_ view:SCNView,context:Context) {
        SCNTransaction.begin(); SCNTransaction.disableActions=true
        game.garden.update(game.world,beat:beat,selected:game.editing && game.selectedStructure==nil ? game.selected : nil,playing:game.playing,atmosphereTime:atmosphereTime)
        game.garden.frame(size:view.bounds.size,zoom:game.zoom,pan:game.pan,follow:game.follow,voice:game.cameraVoice,firstPerson:game.firstPerson,lookYaw:game.lookYaw,frontView:game.frontView)
        game.garden.showBuilderGuide(enabled:game.building && !game.simpleBuilding,height:game.buildHeight,structure:game.selectedStructure)
        if let viewport=view as? WorldViewport {
            let index=game.cameraVoice
            viewport.transitionShade.alpha=game.firstPerson && game.garden.walkers.indices.contains(index) ? game.garden.portalShade(for:index) : 0
        }
        SCNTransaction.commit()
    }
    @MainActor final class Coordinator:NSObject,UIGestureRecognizerDelegate,UIDropInteractionDelegate {
        let game:Game
        var dragOffset=SCNVector3Zero
        init(_ game:Game) { self.game=game }
        func gestureRecognizer(_ gestureRecognizer:UIGestureRecognizer,shouldRecognizeSimultaneouslyWith otherGestureRecognizer:UIGestureRecognizer) -> Bool {
            gestureRecognizer is UIPinchGestureRecognizer || otherGestureRecognizer is UIPinchGestureRecognizer
        }
        func dropInteraction(_ interaction:UIDropInteraction,canHandle session:UIDropSession)->Bool {
            game.building && game.simpleBuilding && session.canLoadObjects(ofClass:NSString.self)
        }
        func dropInteraction(_ interaction:UIDropInteraction,sessionDidUpdate session:UIDropSession)->UIDropProposal {
            UIDropProposal(operation:.copy)
        }
        func dropInteraction(_ interaction:UIDropInteraction,performDrop session:UIDropSession) {
            guard let view=interaction.view as? SCNView,let point=gridPoint(session.location(in:view),view:view) else {return}
            session.loadObjects(ofClass:NSString.self) { [weak self] values in
                let payload=values.compactMap{$0 as? String}.first
                Task {@MainActor in
                    guard let self, self.game.building,let payload,let module=WorldModule(dragValue:payload) else {return}
                    self.game.addModule(module,x:point.x,z:point.z)
                }
            }
        }
        @objc func tap(_ gesture:UITapGestureRecognizer) {
            if game.fullScreen {game.fullScreen=false;return}
            guard let view=gesture.view as? SCNView else { return }
            if game.building && !game.simpleBuilding && (game.buildTool == .place || game.buildTool == .move) {
                guard let point=gridPoint(gesture.location(in:view),view:view) else {game.message="Tap the grid closer to the center of the world.";return}
                if game.buildTool == .place {game.placeBuildItem(x:point.x,z:point.z)}
                else {game.moveBuildSelection(x:point.x,y:game.buildHeight,z:point.z)}
                return
            }
            if selectPiece(at:gesture.location(in:view),view:view),!game.building {game.beginBuilding()}
        }
        func selectPiece(at location:CGPoint,view:SCNView)->Bool {
            guard let hit=view.hitTest(location,options:[.searchMode:SCNHitTestSearchMode.closest.rawValue,.categoryBitMask:1,.ignoreHiddenNodes:true]).first else {return false}
            var node:SCNNode?=hit.node
            while let current=node {
                if let name=current.name,name.hasPrefix("tile_"),let index=Int(name.dropFirst(5)) {game.selectBuildTile(index);return true}
                if let name=current.name,name.hasPrefix("structure_"),let index=Int(name.dropFirst(10)) {game.selectBuildStructure(index);return true}
                node=current.parent
            }
            return false
        }
        func gridPoint(_ location:CGPoint,view:SCNView)->SCNVector3? {
            let near=view.unprojectPoint(SCNVector3(Float(location.x),Float(location.y),0))
            let far=view.unprojectPoint(SCNVector3(Float(location.x),Float(location.y),1))
            let a=game.garden.sculpture.convertPosition(near,from:nil),b=game.garden.sculpture.convertPosition(far,from:nil)
            let dy=b.y-a.y
            guard abs(dy)>0.00001 else {return nil}
            let t=(game.buildHeight-a.y)/dy
            guard t>=0,t<=1 else {return nil}
            return SCNVector3(a.x+(b.x-a.x)*t,game.buildHeight,a.z+(b.z-a.z)*t)
        }
        @objc func hold(_ gesture:UILongPressGestureRecognizer) {
            guard game.building,game.buildTool != .place,let view=gesture.view as? SCNView else {return}
            switch gesture.state {
            case .began:
                if selectPiece(at:gesture.location(in:view),view:view) {
                    game.beginBuildDrag();dragOffset=SCNVector3Zero
                    if let point=gridPoint(gesture.location(in:view),view:view) {
                        if let i=game.selectedStructure {let p=game.world.structures[i];dragOffset=SCNVector3(point.x-p.x,0,point.z-p.z)}
                        else {let p=game.world.tiles[game.selected];dragOffset=SCNVector3(point.x-p.x,0,point.z-p.z)}
                    }
                }
            case .changed:
                if game.dragStart != nil,let point=gridPoint(gesture.location(in:view),view:view) {game.moveBuildSelection(x:point.x-dragOffset.x,y:game.buildHeight,z:point.z-dragOffset.z,continuous:true)}
            case .ended:game.endBuildDrag(cancelled:false)
            case .cancelled,.failed:game.endBuildDrag(cancelled:true)
            default:break
            }
        }
        @objc func pinch(_ gesture:UIPinchGestureRecognizer) {
            game.zoom=min(3.2,max(0.65,game.zoom*Double(gesture.scale))); gesture.scale=1
        }
        @objc func orbit(_ gesture:UIPanGestureRecognizer) {
            let delta=gesture.translation(in:gesture.view)
            if game.firstPerson {
                game.lookYaw+=Double(delta.x)*0.006;gesture.setTranslation(.zero,in:gesture.view);return
            }
            game.garden.orbitYaw-=Double(delta.x)*0.008
            gesture.setTranslation(.zero,in:gesture.view)
            // Publish a view update even while the musical transport is stopped.
            game.pan=game.pan
        }
        @objc func pan(_ gesture:UIPanGestureRecognizer) {
            guard let view=gesture.view else { return }
            let delta=gesture.translation(in:view)
            game.pan=CGPoint(x:min(1.5,max(-1.5,game.pan.x+delta.x/view.bounds.width*2)),y:min(1.5,max(-1.5,game.pan.y+delta.y/view.bounds.height*2)))
            gesture.setTranslation(.zero,in:view)
        }
    }
}
