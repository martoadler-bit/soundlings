import SceneKit

extension GardenScene {
    func renderStructure(_ p:Structure,index:Int) {
        let root=SCNNode();root.name="structure_\(index)";root.position=SCNVector3(p.x,p.y+p.anchorHeight,p.z)
        root.eulerAngles.y=SceneScalar(p.rotation * .pi/180);root.isHidden = !p.enabled
        sculpture.addChildNode(root);structureNodes.append(root)
        let w=CGFloat(p.width),h=CGFloat(p.height),d=CGFloat(p.depth)
        switch p.kind {
        case .arch:
            arch(width:p.width,height:p.height,depth:p.depth,at:SCNVector3Zero,container:root)
            box(CGFloat(p.width*1.12),0.12,CGFloat(max(p.width*1.12,p.depth)),stone,SCNVector3(0,p.height-0.11,0),parent:root)
        case .basin:
            box(w,h,d,stone,SCNVector3Zero,parent:root)
            let surface=box(max(0.02,w-0.45),0.07,max(0.02,d-0.45),water,SCNVector3(0,p.height/2+0.04,0),parent:root)
            let foam=waterFoam(width:max(0.02,w-0.5),depth:max(0.02,d-0.5),at:SCNVector3(0,p.height/2+0.078,0),parent:root)
            addWater(surface,foam:foam)
        case .island:node(SCNCone(topRadius:w/2,bottomRadius:min(0.18,w*0.06),height:h),stone,SCNVector3Zero,parent:root).name="walkSupport";root.scale.z=SceneScalar(p.depth/p.width)
        case .column:node(SCNCylinder(radius:w/2,height:h),copper,SCNVector3Zero,parent:root).name="walkSupport";root.scale.z=SceneScalar(p.depth/p.width)
        case .gear:
            makeGear(at:SCNVector3Zero,radius:0.68,container:root)
            root.scale=SCNVector3(p.width/1.36,p.height/1.36,p.depth/0.4)
        case .waterfall:
            let sheet=box(w,h,d,water.withAlphaComponent(0.65),SCNVector3Zero,parent:root)
            let foam=waterFoam(width:w*0.9,depth:max(0.02,d*0.9),at:SCNVector3(0,-p.height/2+0.008,0),parent:root)
            addWater(sheet,waterfall:true,foam:foam)
        case .tree:
            let trunk=node(SCNCylinder(radius:0.07,height:0.35),copper,SCNVector3(0,-0.78,0),parent:root);finish(trunk,.wood,tint:copper)
            let leafColor=UIColor(red:0.18,green:0.39,blue:0.32,alpha:1)
            let leaves=node(SCNCone(topRadius:0,bottomRadius:0.27,height:1.45),leafColor,SCNVector3Zero,parent:root);finish(leaves,.foliage,tint:leafColor)
            root.scale=SCNVector3(p.width/0.54,p.height/1.45,p.depth/0.54)
        case .pavilion:
            box(1.7,0.25,1.7,stone,SCNVector3Zero,parent:root)
            for z:Float in [-0.65,0.65] {arch(width:1.35,height:1.4,depth:0.18,at:SCNVector3(0,0.13,z),container:root)}
            box(1.65,0.15,1.6,stone,SCNVector3(0,1.57,0),parent:root)
            node(SCNSphere(radius:0.61),copper,SCNVector3(0,1.55,0),parent:root)
            node(SCNCone(topRadius:0,bottomRadius:0.1,height:0.48),copper,SCNVector3(0,2.25,0),parent:root)
            node(SCNSphere(radius:0.12),.systemYellow,SCNVector3(0,0.8,0),parent:root)
            root.scale=SCNVector3(p.width/1.7,p.height/2.5,p.depth/1.7)
        case .orbit:
            let orb=node(SCNSphere(radius:CGFloat(p.detail)),water,SCNVector3Zero,parent:root)
            orb.geometry?.firstMaterial?.emission.contents=water
            for i in 0..<3 {
                let rotor=SCNNode();root.addChildNode(rotor)
                let ring=node(SCNTorus(ringRadius:CGFloat(1+Float(i)*0.35),pipeRadius:0.035),copper,SCNVector3Zero,parent:rotor)
                ring.eulerAngles.x=SceneScalar(Float(i)*0.7);gears.append(rotor)
            }
            root.scale=SCNVector3(p.width/3.4,p.height/3.4,p.depth/3.4)
        }
    }
    func beginBuildPreview(tile:Int?,structure:Int?,anchorHeight:Float=0) {
        endBuildPreview();previewAnchorHeight=anchorHeight
        let source:SCNNode?
        if let tile,tileNodes.indices.contains(tile) {source=tileNodes[tile]}
        else if let structure,structureNodes.indices.contains(structure) {source=structureNodes[structure]}
        else {source=nil}
        guard let source else {return}
        SCNTransaction.begin();SCNTransaction.disableActions=true
        let preview=source.clone();preview.opacity=0.8;preview.categoryBitMask=4
        preview.enumerateChildNodes {node,_ in node.categoryBitMask=4}
        sculpture.addChildNode(preview);buildPreview=preview;previewSource=source;source.opacity=0.18
        SCNTransaction.commit()
    }
    func beginModulePreview(_ world:World,id:UUID,anchor:(Float,Float,Float)) {
        endBuildPreview();previewAnchorHeight=0
        let root=SCNNode();root.position=SCNVector3(anchor.0,anchor.1,anchor.2);root.opacity=0.8
        let pieces=world.tiles.indices.filter{world.tiles[$0].moduleID==id}.map{tileNodes[$0]} + world.structures.indices.filter{world.structures[$0].moduleID==id}.map{structureNodes[$0]}
        let connections=moduleConnections[id] ?? []
        let sources=pieces+connections
        for source in sources {
            let copy=source.clone();copy.position=SCNVector3(Float(source.position.x)-anchor.0,Float(source.position.y)-anchor.1,Float(source.position.z)-anchor.2)
            copy.categoryBitMask=4;copy.enumerateChildNodes {node,_ in node.categoryBitMask=4}
            root.addChildNode(copy);source.opacity=0.18
        }
        sculpture.addChildNode(root);buildPreview=root;previewSources=sources
    }
    func moveBuildPreview(x:Float,y:Float,z:Float) {
        SCNTransaction.begin();SCNTransaction.disableActions=true
        buildPreview?.position=SCNVector3(x,y+previewAnchorHeight,z)
        SCNTransaction.commit()
    }
    func endBuildPreview() {
        previewSources.forEach{$0.opacity=1};previewSources=[]
        previewSource?.opacity=1;buildPreview?.removeFromParentNode();previewSource=nil;buildPreview=nil
    }
    func lockBuilderCamera(_ locked:Bool) {builderBounds=locked ? (boundsMin,boundsMax) : nil}
    func showBuilderGuide(enabled:Bool,height:Float,structure:Int?) {
        guard enabled else {builderGrid?.isHidden=true;builderOutline?.isHidden=true;builderRoute?.isHidden=true;return}
        if builderRoute==nil && builderRoutePoints.count>1 {
            var indices=[Int32]()
            for i in builderRoutePoints.indices {indices += [Int32(i),Int32((i+1)%builderRoutePoints.count)]}
            let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:builderRoutePoints)],elements:[SCNGeometryElement(indices:indices,primitiveType:.line)])
            let route=node(geometry,water,SCNVector3Zero);route.categoryBitMask=4
            route.geometry?.firstMaterial?.lightingModel = .constant
            route.geometry?.firstMaterial?.emission.contents=water
            builderRoute=route
        }
        builderRoute?.isHidden=false
        camera.camera?.categoryBitMask=13|32|64
        for walker in walkers {walker.enumerateChildNodes {node,_ in node.categoryBitMask=8}}
        if builderGrid==nil {
            var vertices=[SCNVector3](),indices=[Int32]()
            for i in -20...20 {
                let n=Float(i),base=Int32(vertices.count)
                vertices += [SCNVector3(n,0,-20),SCNVector3(n,0,20),SCNVector3(-20,0,n),SCNVector3(20,0,n)]
                indices += [base,base+1,base+2,base+3]
            }
            let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices)],elements:[SCNGeometryElement(indices:indices,primitiveType:.line)])
            let grid=node(geometry,.init(white:1,alpha:0.13),SCNVector3(0,height+0.012,0))
            grid.geometry?.firstMaterial?.lightingModel = .constant;grid.geometry?.firstMaterial?.writesToDepthBuffer=false
            grid.categoryBitMask=4;grid.renderingOrder=1;builderGrid=grid
        }
        builderGrid?.isHidden=false;builderGrid?.position.y=SceneScalar(height+0.012)
        builderOutline?.removeFromParentNode();builderOutline=nil
        if let structure,structureNodes.indices.contains(structure) {
            let source=structureNodes[structure],b=source.boundingBox
            let outline=box(CGFloat(max(0.1,b.max.x-b.min.x)),CGFloat(max(0.1,b.max.y-b.min.y)),CGFloat(max(0.1,b.max.z-b.min.z)),.white,SCNVector3Zero)
            let center=SCNVector3((b.min.x+b.max.x)/2,(b.min.y+b.max.y)/2,(b.min.z+b.max.z)/2)
            outline.position=source.convertPosition(center,to:sculpture);outline.eulerAngles=source.eulerAngles;outline.scale=source.scale
            outline.geometry?.firstMaterial?.fillMode = .lines;outline.geometry?.firstMaterial?.lightingModel = .constant
            outline.categoryBitMask=4;builderOutline=outline
        }
    }
}
