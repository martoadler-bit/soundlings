import SceneKit
#if canImport(UIKit)
import UIKit
typealias SceneScalar = Float
#else
import AppKit
typealias UIColor = NSColor
typealias SceneScalar = CGFloat
#endif

final class GardenScene {
    let scene=SCNScene(), camera=SCNNode(), sculpture=SCNNode()
    var pads=[SCNNode](), walkers=[SCNNode](), gears=[SCNNode](), portals=[SCNNode]()
    let style=VisualStyle()
    var waterVisuals=[WaterVisual]()
    var contactShadows=[SCNNode]()
    var selection=SCNNode()
    var structureNodes=[SCNNode](),tileNodes=[SCNNode]()
    var moduleConnections=[UUID:[SCNNode]]()
    var buildPreview:SCNNode?
    var previewSources=[SCNNode]()
    var previewSource:SCNNode?
    var previewAnchorHeight:Float=0
    var builderGrid:SCNNode?
    var builderOutline:SCNNode?
    var builderBounds:(SCNVector3,SCNVector3)?
    var builderRoute:SCNNode?
    var builderRoutePoints=[SCNVector3]()
    var boundsMin=SCNVector3(-4,-1,-4), boundsMax=SCNVector3(4,10,4)
    private(set) var viewHalfHeight:Float=8
    var backdropKey=""
    var orbitYaw:Double=0
    var atmosphere:AtmosphereLayer?
    var backdropOriginal:CGImage?
    var backdropViewport=CGSize.zero
    var environmentFog=false
    var stone=UIColor(red:0.86,green:0.73,blue:0.63,alpha:1)
    var copper=UIColor(red:0.64,green:0.43,blue:0.22,alpha:1)
    var water=UIColor(red:0.23,green:0.68,blue:0.72,alpha:1)
    private var obstacles=[SpaceObstacle]()
    private var airObstacles=[SpaceObstacle]()
    private var previous=[SpacePoint]()
    private var previousVoices=[Int]()
    let encounters=EncounterMotion()
    private let navigation=NavigationMemory()
    private let flight=FlightNavigation()
    private var gaitPhase=[Int:Double](),gaitLift=[Int:Double]()
    private var cameraAnchors=[Int:SCNVector3]()
    private var cameraDelta=0.0
    private var cameraKey=""
    private var smoothEye:SCNVector3?
    private var smoothYaw=0.0
    private var lastBeat:Double?
    private var lastTiles=[Int:Int]()
    private var pendingPortals=Set<Int>()
    private var portalTransitions=[Int:PortalTransition]()
    private(set) var transferredVoices=Set<Int>()
    func resetMotion() {flight.reset();smoothEye=nil;cameraKey="";navigation.reset();encounters.reset();previous=[];previousVoices=[];lastBeat=nil;lastTiles=[:];pendingPortals=[];portalTransitions=[:];gaitPhase=[:];gaitLift=[:];cameraAnchors=[:]}

    private var collisionBodies=[SpaceBody]()
    var collisionFree:Bool {
        for i in collisionBodies.indices {
            if obstacles.contains(where:{$0.intersects(collisionBodies[i])}) {return false}
            for j in 0..<i where CharacterSpace.intersects(collisionBodies[i],collisionBodies[j]) {return false}
        }
        return true
    }
    private var plan:MusicalPlan!
    let colors:[UIColor]=[
        .init(red:0.3,green:0.72,blue:0.86,alpha:1),
        .init(red:0.95,green:0.48,blue:0.48,alpha:1),
        .init(red:0.98,green:0.75,blue:0.31,alpha:1),
        .init(red:0.65,green:0.48,blue:0.88,alpha:1),
        .init(red:0.40,green:0.72,blue:0.57,alpha:1),
        .init(red:0.96,green:0.53,blue:0.22,alpha:1)]
    func palette(_ palette:WorldPalette) {
        let values: [(CGFloat,CGFloat,CGFloat)]
        switch palette {
        case .sunrise: values=[(0.86,0.73,0.63),(0.64,0.43,0.22),(0.23,0.68,0.72),(0.28,0.33,0.42)]
        case .moonlight: values=[(0.52,0.57,0.77),(0.73,0.77,0.92),(0.42,0.30,0.69),(0.09,0.10,0.23)]
        case .forest: values=[(0.47,0.62,0.49),(0.70,0.49,0.25),(0.24,0.62,0.51),(0.12,0.23,0.22)]
        case .copper: values=[(0.74,0.43,0.30),(0.92,0.65,0.28),(0.27,0.49,0.49),(0.26,0.14,0.17)]
        case .glacier: values=[(0.72,0.86,0.92),(0.48,0.64,0.79),(0.31,0.78,0.90),(0.17,0.30,0.43)]
        }
        let c=values.map { UIColor(red:$0.0,green:$0.1,blue:$0.2,alpha:1) }
        stone=c[0]; copper=c[1]; water=c[2]
    }
    init(_ world:World) {
        scene.background.contents=UIColor(red:0.28,green:0.33,blue:0.42,alpha:1)
        scene.rootNode.addChildNode(sculpture)
        camera.camera=SCNCamera(); camera.camera?.usesOrthographicProjection=true
        camera.camera?.zNear=0.1; camera.camera?.zFar=200
        camera.camera?.projectionDirection = .vertical
        camera.camera?.automaticallyAdjustsZRange=false
        camera.camera?.wantsHDR=true; camera.camera?.bloomIntensity=0.08
        camera.camera?.screenSpaceAmbientOcclusionIntensity=0.80
        camera.camera?.screenSpaceAmbientOcclusionRadius=0.25
        camera.camera?.exposureOffset = -0.15
        camera.camera?.bloomThreshold=1.1; camera.camera?.bloomBlurRadius=5
        scene.rootNode.addChildNode(camera)
        let ambient=SCNNode();ambient.name="ambientLight"; ambient.light=SCNLight(); ambient.light?.type = .ambient
        ambient.light?.color=UIColor(red:0.76,green:0.82,blue:0.96,alpha:1); ambient.light?.intensity=500
        scene.rootNode.addChildNode(ambient)
        let sun=SCNNode();sun.name="sunLight"; sun.light=SCNLight(); sun.light?.type = .directional
        sun.light?.color=UIColor(red:1,green:0.87,blue:0.71,alpha:1); sun.light?.intensity=1150
        sun.light?.castsShadow=true;sun.light?.shadowSampleCount=16;sun.light?.shadowBias=0.015; sun.light?.shadowRadius=5; sun.light?.shadowMapSize=CGSize(width:2048,height:2048)
        sun.eulerAngles=SCNVector3(-0.8,-0.6,0); scene.rootNode.addChildNode(sun)
        let rim=SCNNode();rim.name="rimLight";rim.light=SCNLight();rim.light?.type = .directional
        rim.light?.intensity=180;rim.light?.color=UIColor(red:0.70,green:0.83,blue:1,alpha:1)
        rim.eulerAngles=SCNVector3(0.3,2.5,0);scene.rootNode.addChildNode(rim)
        rebuild(world)
        // A valid camera exists before UIKit has completed its first layout pass.
        frame(size:CGSize(width:393,height:852),zoom:1.04,pan:.zero,follow:false)
    }
    @discardableResult func node(_ geometry:SCNGeometry,_ color:UIColor,_ position:SCNVector3,parent:SCNNode?=nil) -> SCNNode {
        let finish:SurfaceFinish=VisualStyle.matches(color,stone) ? .stone : VisualStyle.matches(color,copper) ? .metal : VisualStyle.matches(color,water) ? .water : .enamel
        let material=style.material(finish,tint:color)
        if finish == .stone {
            let c=VisualStyle.components(color)
            let variation=CGFloat(0.97+sin(Double(position.x)*2.7+Double(position.y)*1.9+Double(position.z)*3.1)*0.025)
            material.diffuse.contents=UIColor(red:c.0*variation,green:c.1*variation,blue:c.2*variation,alpha:c.3)
        }
        if let sphere=geometry as? SCNSphere {sphere.segmentCount=32}
        if let cylinder=geometry as? SCNCylinder {cylinder.radialSegmentCount=32}
        if let cone=geometry as? SCNCone {cone.radialSegmentCount=32}
        geometry.materials=[material]
        let n=SCNNode(geometry:geometry);n.position=position
        n.castsShadow=finish != .water && VisualStyle.components(color).3>=0.8
        (parent ?? sculpture).addChildNode(n);return n
    }
    @discardableResult func box(_ w:CGFloat,_ h:CGFloat,_ d:CGFloat,_ color:UIColor,_ p:SCNVector3,parent:SCNNode?=nil) -> SCNNode {
        let geometry=SCNBox(width:w,height:h,length:d,chamferRadius:min(0.045,min(w,min(h,d))/5))
        geometry.chamferSegmentCount=3
        return node(geometry,color,p,parent:parent)
    }
    func color(for tile:Tile) -> UIColor {
        guard tile.enabled else { return .init(white:0.42,alpha:1) }
        switch tile.kind {
        case .filter: return colors[4]
        case .octave: return colors[1]
        case .harp: return colors[2]
        case .wind: return water
        case .wood: return copper
        case .note: return colors[0]
        case .drum: return colors[5]
        case .chord: return colors[2]
        case .transpose: return .init(red:0.65,green:0.50,blue:0.84,alpha:1)
        case .rest: return .init(white:0.53,alpha:1)
        }
    }
    // An actual open arch: two piers and a mesh vault, rather than a solid rectangular wall.
    func arch(width:Float,height:Float,depth:Float,at position:SCNVector3,angle:Float=0,container:SCNNode?=nil,tint:UIColor?=nil) {
        let parent=SCNNode(); parent.position=position; parent.eulerAngles.y=SceneScalar(angle); (container ?? sculpture).addChildNode(parent)
        let archColor=tint ?? stone
        let radius=width/2, thickness:Float=min(0.21,width/4), centerY=height-radius
        guard centerY>0 else { return }
        for side:Float in [-1,1] {
            box(CGFloat(thickness),CGFloat(centerY),CGFloat(depth),archColor,SCNVector3(side*(radius-thickness/2),centerY/2,0),parent:parent)
        }
        var vertices=[SCNVector3](), indices=[Int32]()
        for segment in 0..<20 {
            let a=Float(segment)*Float.pi/20, b=Float(segment+1)*Float.pi/20
            let base=Int32(vertices.count)
            for z in [-depth/2,depth/2] {
                for (r,theta) in [(radius,a),(radius,b),(radius-thickness,b),(radius-thickness,a)] {
                    vertices.append(SCNVector3(cos(theta)*r,centerY+sin(theta)*r,z))
                }
            }
            let points=Array(vertices[Int(base)..<vertices.count])
            let minX=points.map(\.x).min()!,maxX=points.map(\.x).max()!,minY=points.map(\.y).min()!,maxY=points.map(\.y).max()!
            let solid=box(CGFloat(maxX-minX),CGFloat(maxY-minY),CGFloat(depth),archColor,SCNVector3((minX+maxX)/2,(minY+maxY)/2,0),parent:parent)
            solid.name="archSolid";solid.categoryBitMask=16;solid.castsShadow=false
            for quad:[Int32] in [[0,3,2,1],[4,5,6,7],[0,1,5,4],[3,7,6,2],[0,4,7,3],[1,2,6,5]] {
                indices += [quad[0],quad[1],quad[2],quad[0],quad[2],quad[3]].map { $0+base }
            }
        }
        let geometry=VisualStyle.faceted(vertices,indices:indices)
        let vault=node(geometry,archColor,SCNVector3Zero,parent:parent)
        vault.geometry?.firstMaterial?.isDoubleSided=true
        // Supplied normals and UVs let the vault share the stone lighting and finish.
    }
    private var portalWidth:Float=1.4
    func makePortal(at p:SCNVector3,index:Int,yaw:Float=0,tint:UIColor?=nil) {
        let root=SCNNode();root.position=p;root.eulerAngles.y=SceneScalar(yaw);root.name="tile_\(index)";sculpture.addChildNode(root)
        let gate=SCNNode();root.addChildNode(gate)
        let gold=UIColor(red:0.95,green:0.69,blue:0.34,alpha:1)
        arch(width:portalWidth,height:2.2,depth:0.16,at:SCNVector3Zero,container:gate,tint:tint ?? gold)
        portals.append(gate)
    }
    func makeGear(at p:SCNVector3,radius:CGFloat,container:SCNNode?=nil) {
        let root=SCNNode(); root.position=p; root.eulerAngles.x = .pi/2; (container ?? sculpture).addChildNode(root)
        let rotor=SCNNode();root.addChildNode(rotor)
        node(SCNTorus(ringRadius:radius,pipeRadius:0.09),copper,SCNVector3Zero,parent:rotor)
        node(SCNCylinder(radius:0.18,height:0.4),copper,SCNVector3Zero,parent:rotor)
        for i in 0..<12 {
            let a=Float(i)*Float.pi/6, r=Float(radius)
            let tooth=box(0.16,0.17,0.26,copper,SCNVector3(cos(a)*r,0,sin(a)*r),parent:rotor)
            tooth.eulerAngles.y = SceneScalar(-a)
            if i%3==0 {
                let spoke=box(CGFloat(r),0.10,0.12,copper,SCNVector3(cos(a)*r/2,0,sin(a)*r/2),parent:rotor)
                spoke.eulerAngles.y = SceneScalar(-a)
            }
        }
        gears.append(rotor)
    }
    func rebuild(_ world:World) {
        sculpture.childNodes.forEach { $0.removeFromParentNode() }
        waterVisuals=[];contactShadows=[];pads=[]; walkers=[]; portals=[]; gears=[]; structureNodes=[];tileNodes=[];moduleConnections=[:];buildPreview=nil;previewSource=nil;previewSources=[];builderGrid=nil;builderOutline=nil;builderRoute=nil;builderRoutePoints=world.tiles.map{SCNVector3($0.x,$0.y+0.16,$0.z)};obstacles=[];airObstacles=[];collisionBodies=[];resetMotion()
        var allVoices=world
        for i in allVoices.voices.indices {allVoices.voices[i].enabled=true}
        plan=allVoices.plan(); palette(world.palette);applyEnvironment(world)
        portalWidth=max(1.6,Float(world.walkwayWidth)+0.55)
        guard !world.tiles.isEmpty || !world.structures.isEmpty else {
            boundsMin=SCNVector3(-3,-1,-3);boundsMax=SCNVector3(3,4,3)
            selection=SCNNode();selection.isHidden=true
            return
        }
        let xs=world.tiles.map(\.x)+world.structures.map(\.x),zs=world.tiles.map(\.z)+world.structures.map(\.z)
        let minX=xs.min()!,maxX=xs.max()!
        let minZ=zs.min()!,maxZ=zs.max()!
        let maxY=(world.tiles.map(\.y)+world.structures.map(\.y)).max()!
        boundsMin=SCNVector3(minX-1.0,-1.1,minZ-1.0); boundsMax=SCNVector3(maxX+1.0,maxY+4.0,maxZ+1.0)
        let portalTiles=Set(world.tiles.indices.filter{world.requiresPortalLink(from:$0,to:($0+1)%world.tiles.count)}.flatMap{[$0,($0+1)%world.tiles.count]})
        for (i,tile) in world.tiles.enumerated() {
            let before=Set(sculpture.childNodes.map{ObjectIdentifier($0)})
            let next=world.tiles[(i+1)%world.tiles.count]
            box(0.94,0.24,0.94,stone,SCNVector3(tile.x,tile.y-0.12,tile.z)).name="tile_\(i)"
            let pad:SCNNode
            if tile.kind == .drum {
                pad=node(SCNCylinder(radius:0.31,height:0.15),color(for:tile),SCNVector3(tile.x,tile.y+0.075,tile.z))
                node(SCNTorus(ringRadius:0.31,pipeRadius:0.035),copper,SCNVector3(tile.x,tile.y+0.16,tile.z)).name="tile_\(i)"
            } else {
                pad=box(0.54,0.045,0.54,color(for:tile),SCNVector3(tile.x,tile.y+0.03,tile.z))
                if tile.kind == .note {
                    for key in 0..<3 {
                        let x=Float(key-1)*0.14
                        let ivory=UIColor(red:0.95,green:0.91,blue:0.82,alpha:1)
                        box(0.12,0.025,0.34,ivory,SCNVector3(tile.x+x,tile.y+0.065,tile.z)).name="pianoKey"
                    }
                    box(0.07,0.035,0.17,copper,SCNVector3(tile.x+0.07,tile.y+0.08,tile.z-0.08)).name="tile_\(i)"
                }
                if tile.kind == .chord {
                    for x:Float in [-0.15,0,0.15] { box(0.035,0.02,0.33,stone,SCNVector3(tile.x+x,tile.y+0.065,tile.z)).name="tile_\(i)" }
                } else if tile.kind == .transpose && !portalTiles.contains(i) {
                    let previous=world.tiles[(i+world.tiles.count-1)%world.tiles.count]
                    let dx=next.x-previous.x,dz=next.z-previous.z
                    let yaw=atan2(dx,dz)-tile.rotation * .pi/180
                    arch(width:portalWidth,height:2.2,depth:0.14,at:SCNVector3(tile.x,tile.y,tile.z),angle:yaw,tint:color(for:tile))
                }
            }
            if tile.kind == .rest {finish(pad,.stone,tint:stone)}
            if tile.kind == .wood {finish(pad,.wood,tint:copper)}
            if [.harp,.wind,.wood].contains(tile.kind) {
                // Instruments remain below the feet; their sounding elements move on arrivals.
                for j in 0..<5 {
                    let x=Float(j-2)*0.105
                    let element:SCNNode
                    if tile.kind == .wind {
                        element=node(SCNCylinder(radius:0.035,height:CGFloat(0.25+Float(j)*0.045)),water,SCNVector3(x,0.06,0),parent:pad)
                        element.eulerAngles.x = .pi/2
                    } else {
                        element=box(tile.kind == .harp ? 0.012 : 0.07,0.025,CGFloat(0.25+Float(j)*0.045),tile.kind == .harp ? copper : stone,SCNVector3(x,0.045,0),parent:pad)
                    }
                    finish(element,tile.kind == .wood ? .wood : .metal,tint:tile.kind == .wind ? water : copper)
                    element.name="resonator"
                }
                if tile.kind == .harp {
                    for z:Float in [-0.25,0.25] {box(0.58,0.06,0.045,copper,SCNVector3(0,0.035,z),parent:pad)}
                }
            }
            if tile.kind == .filter {
                for j in 0..<3 {
                    let blade=box(0.055,0.06,0.45-Double(j)*0.1,colors[4],SCNVector3(Float(j-1)*0.15,0.09,0),parent:pad)
                    blade.name="filterBlade"
                }
                node(SCNTorus(ringRadius:0.25,pipeRadius:0.02),copper,SCNVector3(0,0.06,0),parent:pad)
            }
            if tile.kind == .octave {
                for j in 0..<tile.arpOctaves {
                    let ring=node(SCNTorus(ringRadius:CGFloat(0.27-Float(j)*0.055),pipeRadius:0.018),colors[1],SCNVector3(0,Float(j)*0.025+0.05,0),parent:pad)
                    ring.name="octaveRing"
                }
            }
            pad.name="tile_\(i)"; pads.append(pad)
            do {
                let group=SCNNode();group.name="tile_\(i)";group.position=SCNVector3(tile.x,tile.y,tile.z)
                let visuals=sculpture.childNodes.filter{!before.contains(ObjectIdentifier($0))}
                sculpture.addChildNode(group)
                for visual in visuals {visual.position=SCNVector3(visual.position.x-SceneScalar(tile.x),visual.position.y-SceneScalar(tile.y),visual.position.z-SceneScalar(tile.z));group.addChildNode(visual)}
                group.eulerAngles.y=SceneScalar(tile.rotation * .pi/180);tileNodes.append(group)
            }
            if !world.requiresPortalLink(from:i,to:(i+1)%world.tiles.count) {
                let dx=next.x-tile.x,dy=next.y-tile.y,dz=next.z-tile.z
                let length=sqrt(dx*dx+dz*dz)
                // Short ramp sections keep their collision boxes close to the actual deck.
                let sections=max(1,Int(ceil(length/0.12)))
                for section in 0..<sections where length>0.001 {
                    let t=(Float(section)+0.5)/Float(sections)
                    let landing=min(0.75,0.47/max(0.001,Double(length)))
                    let u=dy>0 ? min(1,Double(t)/max(0.1,1-landing)) : max(0,(Double(t)-landing)/max(0.1,1-landing))
                    let center=SpacePoint(x:Double(tile.x+dx*t),y:Double(tile.y)+Double(dy)*u,z:Double(tile.z+dz*t))
                    let bridge=box(CGFloat(world.walkwayWidth),0.12,CGFloat(length/Float(sections)+0.015),stone,SCNVector3(Float(center.x),Float(center.y)-0.07,Float(center.z)))
                    bridge.name="walkSurface"
                    if let id=tile.moduleID,id==next.moduleID {moduleConnections[id,default:[]].append(bridge)}
                    bridge.eulerAngles.y=SceneScalar(atan2(dx,dz))
                }
            }
        }
        var portalIndices=Set<Int>()
        for i in world.tiles.indices where world.requiresPortalLink(from:i,to:(i+1)%world.tiles.count) {
            portalIndices.insert(i); portalIndices.insert((i+1)%world.tiles.count)
        }
        for index in portalIndices.sorted() {
            let t=world.tiles[index],next=(index+1)%world.tiles.count,prior=(index+world.tiles.count-1)%world.tiles.count
            let neighbor = !world.requiresPortalLink(from:index,to:next) ? next : prior
            let q=world.tiles[neighbor],yaw=atan2(q.x-t.x,q.z-t.z)
            makePortal(at:SCNVector3(t.x,t.y,t.z),index:index,yaw:yaw,tint:t.kind == .transpose ? color(for:t) : nil)
        }
        for (i,piece) in world.structures.enumerated() {renderStructure(piece,index:i)}
        if !world.tiles.isEmpty {
            let tile=world.percussionStage()
            let stage=SCNNode();stage.name="drumStageRoot";sculpture.addChildNode(stage)
            let home=world.percussionStageDistance != nil
            box(home ? 1.8 : 1.5,home ? 0.4 : 0.24,home ? 1.8 : 1.5,stone,SCNVector3(tile.x,tile.y-(home ? 0.2 : 0.12),tile.z),parent:stage).name="drumStage"
            if home {
            box(1.65,0.04,1.65,copper,SCNVector3(tile.x,tile.y-0.025,tile.z),parent:stage).name="drumStage"
            for x:Float in [-0.63,0.63] {for z:Float in [-0.63,0.63] {
                box(0.14,0.55,0.14,stone,SCNVector3(tile.x+x,tile.y-0.6,tile.z+z),parent:stage).name="walkSupport"
            }}
            }
        }
        // Capture only solid decorative shapes. Walk surfaces and open rings are excluded.
        sculpture.enumerateChildNodes { n,_ in
            var ancestor:SCNNode?=n
            while let current=ancestor {if current.isHidden {return};ancestor=current.parent}
            guard let geometry=n.geometry,
                  geometry is SCNBox || geometry is SCNCylinder || geometry is SCNSphere || geometry is SCNCone else {return}
            if n.categoryBitMask==64 {return}
            let bounds=n.boundingBox
            if bounds.max.y-bounds.min.y<0.18 && n.name != "walkSurface" && n.name != "archSolid" {return}
            var points=[SCNVector3]()
            for x in [bounds.min.x,bounds.max.x] {for y in [bounds.min.y,bounds.max.y] {for z in [bounds.min.z,bounds.max.z] {
                points.append(n.convertPosition(SCNVector3(x,y,z),to:self.sculpture))
            }}}
            // Flat instrument surfaces are walkable decoration even when their cylinders are rotated.
            if (points.map(\.y).max()! - points.map(\.y).min()!) < 0.18 && n.name != "walkSurface" && n.name != "archSolid" {return}
            self.obstacles.append(SpaceObstacle(
                min:SpacePoint(x:Double(points.map(\.x).min()!),y:Double(points.map(\.y).min()!),z:Double(points.map(\.z).min()!)),
                max:SpacePoint(x:Double(points.map(\.x).max()!),y:Double(points.map(\.y).max()!),z:Double(points.map(\.z).max()!)),walkSurface:n.name == "walkSupport" || n.name == "resonator" || n.name == "walkSurface" || n.name == "drumStage" || (n.name?.hasPrefix("tile_") ?? false)))
        }
        // Flight clears complete decorative envelopes, including open vaults and thin ring rims.
        // Ground navigation keeps the openings; flying creatures go above them rather than clip their edges.
        airObstacles=obstacles
        for root in structureNodes+portals where !root.isHidden {
            let b=root.boundingBox
            var points=[SCNVector3]()
            for x in [b.min.x,b.max.x] {for y in [b.min.y,b.max.y] {for z in [b.min.z,b.max.z] {points.append(root.convertPosition(SCNVector3(x,y,z),to:sculpture))}}}
            var envelope=SpaceObstacle(min:SpacePoint(x:Double(points.map(\.x).min()!),y:Double(points.map(\.y).min()!),z:Double(points.map(\.z).min()!)),max:SpacePoint(x:Double(points.map(\.x).max()!),y:Double(points.map(\.y).max()!),z:Double(points.map(\.z).max()!)))
            if let index=structureNodes.firstIndex(of:root),world.structures[index].moving {
                let b=world.structures[index].envelope
                envelope=SpaceObstacle(min:SpacePoint(x:b.minX,y:b.minY,z:b.minZ),max:SpacePoint(x:b.maxX,y:b.maxY,z:b.maxZ))
            }
            airObstacles.append(envelope)
            if let index=structureNodes.firstIndex(of:root),world.structures[index].moving {obstacles.append(envelope)}
        }
        // Each creature has its own face, cape, swinging arms and alternating feet.
        if !world.tiles.isEmpty {
        for i in world.voices.indices {
            let root=SCNNode(); sculpture.addChildNode(root)
            let role=world.voices[i].role, color=colors[role.index]
            root.scale=SCNVector3(0.8,0.8,0.8)
            let body=node(SCNCone(topRadius:0.10,bottomRadius:0.24,height:0.43),color,SCNVector3(0,0.36,0),parent:root)
            body.name="body";finish(body,.cloth,tint:color)
            let head=node(SCNSphere(radius:0.21),color,SCNVector3(0,0.70,0),parent:root)
            head.name="head";finish(head,.enamel,tint:color)
            let badge=node(SCNSphere(radius:0.04),.white,SCNVector3(0,0.40,0.17),parent:root)
            badge.geometry?.firstMaterial?.emission.contents=color
            let collar=node(SCNTorus(ringRadius:0.105,pipeRadius:0.025),copper,SCNVector3(0,0.54,0),parent:root)
            collar.geometry?.firstMaterial?.roughness.contents=0.4
            for x:Float in [-0.072,0.072] {
                node(SCNSphere(radius:0.032),.white,SCNVector3(x,0.02,0.168),parent:head).name="eye"
                node(SCNSphere(radius:0.016),.init(white:0.13,alpha:1),SCNVector3(x,0.02,0.195),parent:head).name="eye"
                let foot=node(SCNSphere(radius:0.075),copper,SCNVector3(x,0.08,0),parent:root); foot.name="foot"
                let arm=node(SCNCapsule(capRadius:0.045,height:0.22),color,SCNVector3(x*3,0.37,0),parent:root); arm.name="arm"
                if role == .percussion {node(SCNSphere(radius:0.065),copper,SCNVector3(0,-0.15,0.07),parent:arm)}
            }
            let halo=node(SCNTorus(ringRadius:role == .bass ? 0.20 : 0.22,pipeRadius:0.015),color,SCNVector3(0,0.025,0),parent:root)
            halo.geometry?.firstMaterial?.emission.contents=color
            halo.name="halo"
            if role == .melody {
                for side:Float in [-1,1] {
                    let ear=node(SCNCone(topRadius:0.01,bottomRadius:0.065,height:0.18),color,SCNVector3(side*0.15,0.88,0),parent:root)
                    ear.eulerAngles.z=SceneScalar(-side*0.35)
                }
            }
            if role == .arpeggio {node(SCNCone(topRadius:0,bottomRadius:0.22,height:0.23),color,SCNVector3(0,0.91,0),parent:root)}
            if role == .arpeggio {
                for j in 0..<3 {
                    let ring=node(SCNTorus(ringRadius:CGFloat(0.27+Float(j)*0.045),pipeRadius:0.014),color,SCNVector3(0,0.12+Float(j)*0.10,0),parent:root)
                    ring.name="arpOctave_\(j)";ring.isHidden=j>0
                }
                let lens=node(SCNSphere(radius:0.07),color,SCNVector3(0,0.42,0.19),parent:root)
                lens.name="filterLens"
            }
            if role == .bass {box(0.27,0.30,0.13,copper,SCNVector3(0,0.38,-0.19),parent:root)}
            if role == .pad {
                let canopy=node(SCNSphere(radius:0.38),color.withAlphaComponent(0.3),SCNVector3(0,0.58,0),parent:root)
                canopy.name="canopy"; canopy.scale=SCNVector3(1,1.3,1)
                for j in 0..<3 {
                    let a=Float(j)*2 * Float.pi/3
                    let tone=node(SCNSphere(radius:0.06),color,SCNVector3(sin(a)*0.32,0.68,cos(a)*0.32),parent:root)
                    tone.name="padTone";tone.geometry?.firstMaterial?.emission.contents=color
                }
            }
            if role == .drone {
                let beacon=node(SCNTorus(ringRadius:0.38,pipeRadius:0.035),color,SCNVector3(0,1.36,0),parent:root)
                beacon.name="beacon" // Horizontal halo stays completely above the head.
                let core=node(SCNSphere(radius:0.14),color,SCNVector3(0,0.38,0.24),parent:root)
                core.name="droneCore";core.geometry?.firstMaterial?.emission.contents=color
            }
            if role == .percussion {
                node(SCNCylinder(radius:0.25,height:0.23),copper,SCNVector3(0,0.24,0.35),parent:root)
                node(SCNCylinder(radius:0.25,height:0.02),.white,SCNVector3(0,0.37,0.35),parent:root)
            }
            if role == .bass { root.scale=SCNVector3(0.9,0.88,0.9) }
            root.name="walker_\(i)"; walkers.append(root);contactShadows.append(makeContactShadow())
        }
        }
        selection=node(SCNTorus(ringRadius:0.44,pipeRadius:0.035),.white,SCNVector3Zero)
        selection.geometry?.firstMaterial?.emission.contents=UIColor(white:0.8,alpha:1)
        selection.isHidden=true;selection.castsShadow=false
        update(world,beat:0,selected:nil)
        if let pad=world.voices.firstIndex(where:{$0.role == .pad && $0.enabled}),walkers.indices.contains(pad) {
            var ceiling=(airObstacles.map{$0.max.y}.max() ?? 0)+FlightSpace.clearance
            for i in walkers.indices where world.voices[i].role == .drone && world.voices[i].enabled {ceiling=max(ceiling,Double(walkers[i].position.y)+1.65)}
            boundsMax.y=max(boundsMax.y,SceneScalar(ceiling+1.15))
        }
        let actual=sculpture.boundingBox
        boundsMin=SCNVector3(min(boundsMin.x,actual.min.x-0.15),min(boundsMin.y,actual.min.y-0.15),min(boundsMin.z,actual.min.z-0.15))
        boundsMax=SCNVector3(max(boundsMax.x,actual.max.x+0.15),max(boundsMax.y,actual.max.y+0.15),max(boundsMax.z,actual.max.z+0.15))
    }
    func update(_ world:World,beat:Double,selected:Int?,playing:Bool=false,atmosphereTime:Double?=nil) {
        let visualTime=atmosphereTime ?? beat*60/world.tempo
        atmosphere?.update(time:visualTime);animateWater(time:visualTime)
        guard !world.tiles.isEmpty else {selection.isHidden=true;return}
        sculpture.childNode(withName:"drumStageRoot",recursively:false)?.isHidden = !world.voices.contains{$0.role == .percussion && $0.enabled}
        let delta=lastBeat.map{beat >= $0 ? beat-$0 : beat+world.loopBeats-$0} ?? 0
        let seconds=min(1.0/30,max(0,delta*60/world.tempo))
        cameraDelta=seconds
        let headings=walkers.map{Double($0.eulerAngles.y)}
        transferredVoices=[]
        var portalMoves=Set<Int>()
        var active=Set<Int>()
        var tilePulses=[Int:Float]()
        var bodies=[SpaceBody](), bodyIndices=[Int]()
        for (i,walker) in walkers.enumerated() {
            let voice=world.voices[i], role=voice.role
            walker.isHidden = !voice.enabled
            let motion=plan.motion(voice:i,beat:beat,fallback:world.tileIndex(at:0,voice:i))
            let index=motion.tile, next=motion.nextTile
            let a=world.tiles[index], b=world.tiles[next]
            let t=Float(motion.progress), sounding=playing && motion.energy>0 && motion.age<motion.duration && voice.gain>0
            let pulse=sounding ? Float(exp(-motion.age*(role == .pad || role == .drone ? 0.3 : 7))) : 0
            if role == .drone {
                let desired=SpacePoint(x:Double(a.x),y:Double(a.y)+1.75+sin(beat * .pi/2)*0.08,z:Double(a.z))
                let hover=FlightSpace.hover(desired,radius:0.45,obstacles:airObstacles)
                walker.position=SCNVector3(Float(hover.x),Float(hover.y),Float(hover.z));walker.opacity=1
            } else if role == .pad {
                var airspace=airObstacles
                for other in walkers.indices where other != i && world.voices[other].enabled && world.voices[other].role == .drone {
                    let p=walkers[other].position
                    airspace.append(SpaceObstacle(min:SpacePoint(x:Double(p.x)-0.45,y:Double(p.y)-0.12,z:Double(p.z)-0.45),max:SpacePoint(x:Double(p.x)+0.45,y:Double(p.y)+1.3,z:Double(p.z)+0.45)))
                }
                let initial=FlightSpace.hover(SpacePoint(x:Double(a.x),y:Double(a.y)+0.95,z:Double(a.z)),radius:0.5,obstacles:airspace)
                let current=cameraAnchors[i].map{SpacePoint(x:Double($0.x),y:Double($0.y),z:Double($0.z))} ?? initial
                let target=SpacePoint(x:Double(b.x),y:Double(b.y)+0.95,z:Double(b.z))
                let point=flight.advance(voice:i,current:current,target:target,radius:0.4,seconds:seconds,obstacles:airspace)
                walker.position=SCNVector3(Float(point.x),Float(point.y),Float(point.z));walker.opacity=1
            } else if role == .percussion {
                let stage=world.percussionStage()
                walker.position=SCNVector3(stage.x,stage.y,stage.z);walker.opacity=1
            } else if world.isPortal(from:index,to:next) {
                // Remain at the sounding pad, vanish, then arrive at the next onset.
                walker.position=SCNVector3(a.x,a.y+(role == .pad ? 0.95 : 0),a.z)
            } else {
                let hop:Float=role == .arpeggio ? sin(t * .pi)*0.28 : role == .pad ? 0.95 : abs(sin(t * .pi*2))*0.045
                // Silent steps still follow the actual walkway, never cut a chord across a curved bridge.
                let count=world.tiles.count, direction=world.reversed ? -1 : 1
                let steps=(direction*(next-index)+count)%count
                let along=Double(t)*Double(steps),segment=min(max(0,steps-1),Int(along))
                let local=steps==0 ? Float(0) : Float(along-Double(segment))
                let start=(index+direction*segment+count)%count
                let end=(start+direction+count)%count
                let u=world.tiles[start],v=steps==0 ? u : world.tiles[end]
                walker.position=SCNVector3(u.x+(v.x-u.x)*local,u.y+(v.y-u.y)*local+hop,u.z+(v.z-u.z)*local)
                walker.opacity=1
            }
            let heading=Double(atan2(b.x-a.x,b.z-a.z))
            walker.eulerAngles.y=SceneScalar(lastBeat == nil ? heading : headings[i])
            for (j,limb) in walker.childNodes.filter({$0.name=="foot" || $0.name=="arm"}).enumerated() {
                if role == .percussion { limb.eulerAngles.x=SceneScalar(pulse * (j%2==0 ? -1.4 : 1.4) * (motion.hit == .hat ? 0.4 : 1)) }

            }
            if let halo=walker.childNode(withName:"halo",recursively:false) {
                let scale=1+pulse*0.55; halo.scale=SCNVector3(scale,1,scale)
            }
            if let canopy=walker.childNode(withName:"canopy",recursively:false) {
                let scale:Float=sounding ? 1.15+pulse*0.15 : 0.6
                let blend=Float(1-exp(-seconds*5))
                canopy.scale=SCNVector3(Float(canopy.scale.x)+(scale-Float(canopy.scale.x))*blend,1.3,Float(canopy.scale.z)+(scale-Float(canopy.scale.z))*blend)
            }
            if let beacon=walker.childNode(withName:"beacon",recursively:false) { beacon.eulerAngles.y=SceneScalar(beat/world.loopBeats * .pi*4) }
            for tone in walker.childNodes where tone.name=="padTone" {
                tone.isHidden = !sounding
                let s=0.7+pulse*0.5;tone.scale=SCNVector3(s,s,s)
            }
            if let core=walker.childNode(withName:"droneCore",recursively:false) {
                let scale=1+0.12*sin(Float(beat) * .pi/2);core.scale=SCNVector3(scale,scale,scale)
            }
            if role == .arpeggio {
                for j in 0..<3 {
                    let ring=walker.childNode(withName:"arpOctave_\(j)",recursively:false)
                    ring?.isHidden=j>=motion.arpOctaves
                    let scale=1+pulse*0.15;ring?.scale=SCNVector3(scale,1,scale)
                }
                if let lens=walker.childNode(withName:"filterLens",recursively:false) {
                    let openness=Float(motion.filterCutoff.map{min(1,max(0,log($0/150)/log(80)))} ?? 1)
                    lens.scale=SCNVector3(0.5+openness,0.5+openness,0.5+openness)
                    lens.geometry?.firstMaterial?.emission.contents=colors[1].withAlphaComponent(CGFloat(0.25+openness*0.75))
                }
            }
            if sounding {active.insert(index);tilePulses[index]=max(tilePulses[index] ?? 0,pulse)}
            if !walker.isHidden {
                let floating=role == .pad || role == .drone
                let hop:Double = floating || role == .percussion || world.isPortal(from:index,to:next) ? 0 : Double(role == .arpeggio ? sin(t * .pi)*0.28 : abs(sin(t * .pi*2))*0.045)
                bodies.append(SpaceBody(point:SpacePoint(x:Double(walker.position.x),y:Double(walker.position.y)-hop,z:Double(walker.position.z)),radius:role == .bass ? 0.30 : role == .arpeggio ? 0.35 : role == .percussion ? 0.49 : role == .pad ? 0.40 : role == .drone ? 0.35 : 0.29,height:role == .drone ? 1.15 : role == .arpeggio ? 1.10 : 0.95,floating:floating))
                if !floating,let prior=lastTiles[i],prior != index,world.isPortal(from:prior,to:index) {pendingPortals.insert(i)}
                if pendingPortals.contains(i) {portalMoves.insert(bodyIndices.count)}
                lastTiles[i]=index
                bodyIndices.append(i)
            }
        }
        if previousVoices != bodyIndices {
            let positions=Dictionary(uniqueKeysWithValues:zip(previousVoices,previous))
            previous=previousVoices.isEmpty ? [] : bodyIndices.enumerated().map {positions[$0.element] ?? bodies[$0.offset].point}
            encounters.reset();navigation.reset()
            previousVoices=bodyIndices
        }
        let encounter=encounters.step(bodies,previous:previous,world:world,obstacles:obstacles,seconds:seconds,portals:portalMoves)
        let resolved=CharacterSpace.advance(bodies,previous:encounter.points,world:world,obstacles:obstacles,maxStep:12*seconds,portals:portalMoves,locked:encounter.locked,memory:navigation)
        lastBeat=beat
        let oldPositions=previous
        previous=resolved
        collisionBodies=bodies
        for i in resolved.indices {collisionBodies[i].point=resolved[i]}
        for i in resolved.indices {
            let walker=walkers[bodyIndices[i]],point=resolved[i]
            let displacement=point.distance(bodies[i].point)
            let voice=bodyIndices[i]
            if encounter.locked.contains(i) {walker.opacity=1}
            if pendingPortals.contains(voice) && !encounter.locked.contains(i) {
                walker.opacity=0
                if displacement<=1.001 && abs(point.y-bodies[i].point.y)<0.25 {
                    pendingPortals.remove(voice);transferredVoices.insert(voice)
                }
            }
            let old=oldPositions.indices.contains(i) ? oldPositions[i] : point
            let distance=point.distance(old),role=world.voices[voice].role
            let moving=distance>0.0001 && distance<0.5 && !encounter.locked.contains(i)
            if moving {gaitPhase[voice,default:0]+=distance*Double.pi*3}
            let phase=gaitPhase[voice,default:0]
            let amplitude=role == .arpeggio ? 0.13 : 0.035
            let lift=moving && (role == .melody || role == .arpeggio || role == .bass) ? abs(sin(phase))*amplitude : 0
            gaitLift[voice,default:0]+=(lift-gaitLift[voice,default:0])*(1-exp(-seconds*24))
            walker.position=SCNVector3(Float(point.x),Float(point.y+gaitLift[voice,default:0]),Float(point.z))
            cameraAnchors[voice]=SCNVector3(Float(point.x),Float(point.y),Float(point.z))
            if moving {
                let heading=atan2(point.x-old.x,point.z-old.z),oldHeading=headings[voice]
                let difference=atan2(sin(heading-oldHeading),cos(heading-oldHeading))
                walker.eulerAngles.y=SceneScalar(oldHeading+difference*(1-exp(-seconds*14)))
            }
            if role != .percussion {
                for (j,limb) in walker.childNodes.filter({$0.name=="foot" || $0.name=="arm"}).enumerated() {
                    let target=moving ? sin(phase+Double(j%2)*Double.pi)*0.08 : 0
                    limb.position.z += SceneScalar((target-Double(limb.position.z))*(1-exp(-seconds*20)))
                }
            }
            let gesture=plan.motion(voice:voice,beat:beat,fallback:0)
            let mechanism=world.tiles[gesture.tile].kind
            let pulse=exp(-gesture.age*60/world.tempo*9)
            for arm in walker.childNodes where arm.name=="arm" {
                let target:Double=mechanism == .wind ? -0.9*pulse : mechanism == .harp ? -0.55*pulse : mechanism == .wood ? 0.7*pulse : 0
                arm.eulerAngles.x += SceneScalar((target-Double(arm.eulerAngles.x))*(1-exp(-seconds*18)))
            }
            walker.eulerAngles.z=0
            if let heading=encounter.headings[i] {
                let old=headings[bodyIndices[i]],difference=atan2(sin(heading-old),cos(heading-old))
                walker.eulerAngles.y=SceneScalar(old+difference*(1-exp(-seconds*18)))
            }
            if encounter.locked.contains(i) {
                for limb in walker.childNodes where limb.name=="foot" || limb.name=="arm" {limb.position.z=0}
            }
        }
        for (voice,walker) in walkers.enumerated() {
            let role=world.voices[voice].role
            guard !walker.isHidden,role != .drone,role != .pad,role != .percussion else {portalTransitions.removeValue(forKey:voice);continue}
            let motion=plan.motion(voice:voice,beat:beat,fallback:world.tileIndex(at:0,voice:voice))
            let nextIn:Double?=motion.travelDuration>0 && world.isPortal(from:motion.tile,to:motion.nextTile) ? max(0,motion.travelDuration-motion.age)*60/world.tempo : nil
            var transition=portalTransitions[voice] ?? PortalTransition()
            transition.update(seconds:max(0,delta*60/world.tempo),nextIn:nextIn,waiting:pendingPortals.contains(voice),transferred:transferredVoices.contains(voice))
            portalTransitions[voice]=transition;walker.opacity=CGFloat(1-transition.alpha)
        }
        let arp=world.voices.firstIndex(where:{$0.role == .arpeggio && $0.enabled})
        let arpMotion=arp.map{plan.motion(voice:$0,beat:beat,fallback:0)}
        for (i,pad) in pads.enumerated() {
            let activation:Float=playing ? (arpMotion.map{$0.energy>0 && $0.tile==i && $0.age<0.3 ? Float(exp(-$0.age*8)) : 0} ?? 0) : 0
            for element in pad.childNodes {
                if element.name=="filterBlade" {element.eulerAngles.y=SceneScalar(Float(world.tiles[i].filterCutoff) * .pi/2+activation*0.15)}
                if element.name=="octaveRing" {element.scale=SCNVector3(1+activation*0.3,1,1+activation*0.3)}
            }
            for (j,element) in pad.childNodes.filter({$0.name=="resonator"}).enumerated() {
                let energy=Double(tilePulses[i] ?? 0)
                let kind=world.tiles[i].kind
                let amplitude=kind == .harp ? 0.022 : kind == .wood ? 0.013 : 0.008
                let vibration=energy*sin(beat * .pi*Double(20+j*3))
                element.eulerAngles.z=SceneScalar(vibration*amplitude)
                if kind == .harp {element.position.x=SceneScalar(Double(j-2)*0.105+vibration*0.006)}
                if kind == .wood {element.position.y=SceneScalar(0.045+vibration*0.003)}
                if kind == .wind {element.scale.x=SceneScalar(1+energy*0.025)}
                element.geometry?.firstMaterial?.emission.contents=active.contains(i) ? color(for:world.tiles[i]).withAlphaComponent(0.35) : UIColor.black
                element.geometry?.firstMaterial?.emission.intensity=CGFloat(energy*0.18)
            }
            let response=tilePulses[i] ?? 0
            if world.tiles[i].kind == .drum {pad.scale.y=SceneScalar(1-response*0.035)}
            if world.tiles[i].kind == .note {
                for key in tileNodes[i].childNodes where key.name=="pianoKey" {key.position.y=SceneScalar(0.065-response*0.008)}
            }
            pad.geometry?.firstMaterial?.emission.contents=active.contains(i) ? color(for:world.tiles[i]) : UIColor.black
            pad.geometry?.firstMaterial?.emission.intensity=world.tiles[i].kind == .rest ? 0 : CGFloat(response*0.22)
        }
        animateAppearance(world,plan:plan,beat:beat,playing:playing,seconds:seconds,time:visualTime)
        for (i,gear) in gears.enumerated() { gear.eulerAngles.y=SceneScalar(Float(beat/world.loopBeats) * .pi*2 * Float(max(1,(world.loopBeats/12).rounded())) * (i==0 ? 1 : -1)) }
        for portal in portals {portal.opacity=0.9+sin(beat * .pi)*0.08}
        selection.isHidden=selected == nil
        if let selected,world.tiles.indices.contains(selected) {
            let t=world.tiles[selected]; selection.position=SCNVector3(t.x,t.y+0.20,t.z)
        }
    }
    func portalShade(for voice:Int)->CGFloat {CGFloat(portalTransitions[voice]?.alpha ?? 0)}
    func frame(size:CGSize,zoom:Double,pan:CGPoint,follow:Bool,voice:Int=0,firstPerson:Bool=false,lookYaw:Double=0,frontView:Bool=false,overviewTilt:Double=0) {
        guard size.width>0,size.height>0 else { return }
        fitBackdrop(size)
        for walker in walkers {walker.enumerateChildNodes {node,_ in node.categoryBitMask=1}}
        camera.camera?.categoryBitMask=1|32|64
        if firstPerson,walkers.indices.contains(voice),!walkers[voice].isHidden {
            let walker=walkers[voice]
            // Exclude the selected avatar from the camera without hiding its collision body.
            walker.enumerateChildNodes {node,_ in node.categoryBitMask=2}
            camera.camera?.usesOrthographicProjection=false
            camera.camera?.projectionDirection = .horizontal
            camera.camera?.fieldOfView=92;camera.camera?.zNear=0.06
            let desiredYaw=Double(walker.eulerAngles.y)+lookYaw
            let key="first-\(voice)"
            let reset=cameraKey != key || smoothEye == nil || transferredVoices.contains(voice)
            let weight=cameraDelta>0 ? 1-exp(-cameraDelta*7) : 1
            smoothYaw=reset ? desiredYaw : smoothYaw+atan2(sin(desiredYaw-smoothYaw),cos(desiredYaw-smoothYaw))*weight
            let yaw=smoothYaw
            let p=cameraAnchors[voice] ?? walker.position
            let eye=sculpture.convertPosition(SCNVector3(p.x,p.y+0.6,p.z),to:nil)
            if reset {smoothEye=eye} else if let old=smoothEye {
                smoothEye=SCNVector3(old.x+(eye.x-old.x)*SceneScalar(weight),old.y+(eye.y-old.y)*SceneScalar(weight),old.z+(eye.z-old.z)*SceneScalar(weight))
            }
            cameraKey=key
            let ahead=sculpture.convertPosition(SCNVector3(Float(p.x)+Float(sin(yaw))*4,Float(p.y)+0.55,Float(p.z)+Float(cos(yaw))*4),to:nil)
            let position=smoothEye ?? eye
            camera.position=position
            camera.look(at:SCNVector3(position.x+ahead.x-eye.x,position.y+ahead.y-eye.y,position.z+ahead.z-eye.z))
            placeEnvironment(radius:12)
            return
        }
        cameraKey="overview";smoothEye=nil
        camera.camera?.projectionDirection = .vertical
        camera.camera?.usesOrthographicProjection=true;camera.camera?.zNear=0.1
        let boundsMin=builderBounds?.0 ?? self.boundsMin,boundsMax=builderBounds?.1 ?? self.boundsMax
        let middle=SCNVector3((boundsMin.x+boundsMax.x)/2,(boundsMin.y+boundsMax.y)/2,(boundsMin.z+boundsMax.z)/2)
        var target=sculpture.convertPosition(middle,to:nil)
        if follow,walkers.indices.contains(voice) {let p=cameraAnchors[voice] ?? walkers[voice].position;target=sculpture.convertPosition(SCNVector3(p.x,p.y+0.4,p.z),to:nil)}
        let extent=max(Float(boundsMax.x-boundsMin.x),Float(boundsMax.y-boundsMin.y),Float(boundsMax.z-boundsMin.z))
        let distance=max(1,extent/25)
        camera.camera?.zFar=Double(max(200,extent*10))
        // The panorama renders first without depth or scene fog; it remains at infinity.
        scene.fogStartDistance=0;scene.fogEndDistance=0
        let d=SceneScalar(distance),yaw=SceneScalar(orbitYaw)
        let elevation=SceneScalar(19+Float(overviewTilt)*10)
        let ox:SceneScalar=frontView ? 0 : 24*d
        let oz:SceneScalar=frontView ? 36*d : 27*d
        let oy:SceneScalar=frontView ? 8*d : elevation*d
        camera.position=SCNVector3(target.x+ox*cos(yaw)+oz*sin(yaw),target.y+oy,target.z+oz*cos(yaw)-ox*sin(yaw))
        camera.look(at:target,up:SCNVector3(0,1,0),localFront:SCNVector3(0,0,-1))
        let aspect=Float(size.width/size.height)
        var width:Float=1,height:Float=1
        for x in [boundsMin.x,boundsMax.x] { for y in [boundsMin.y,boundsMax.y] { for z in [boundsMin.z,boundsMax.z] {
            let point=camera.convertPosition(sculpture.convertPosition(SCNVector3(x,y,z),to:nil),from:nil)
            width=max(width,abs(Float(point.x))); height=max(height,abs(Float(point.y)))
        } } }
        // Fit projected world bounds to the viewport, rather than a fixed, excessively distant camera.
        let half=follow ? max(2.8,2.6/aspect) : max(height/0.76,width/aspect/0.91)
        let halfH=half/Float(zoom)
        viewHalfHeight=halfH
        // Let SceneKit generate its projection and matching culling frustum.
        // Panning moves the camera in its own screen plane rather than overriding projectionTransform.
        camera.camera?.orthographicScale=Double(halfH)
        camera.localTranslate(by:SCNVector3(-Float(pan.x)*halfH*aspect,(Float(pan.y)-0.045+(builderBounds == nil ? 0 : -0.28))*halfH,0))
        placeEnvironment(radius:Double(max(12,halfH*sqrt(1+aspect*aspect)*1.2)))
    }
}
