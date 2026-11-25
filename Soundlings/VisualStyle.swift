import SceneKit
import CoreGraphics

// Shared, deterministic surface maps. Geometry and collision records stay independent of finish.
enum SurfaceFinish:String,CaseIterable {case stone,metal,wood,enamel,cloth,foliage,water,waterfall}
final class VisualStyle {
    struct Maps {let albedo:CGImage;let normal:CGImage;let roughness:CGImage}
    static let maps:[SurfaceFinish:Maps]=Dictionary(uniqueKeysWithValues:SurfaceFinish.allCases.map{($0,makeMaps($0))})
    static let shadow:CGImage=bitmap(size:64) {x,y in
        let r=hypot((Double(x)+0.5)/32-1,(Double(y)+0.5)/32-1)
        let alpha=pow(max(0,1-r),2)*0.62
        return (0.07,0.06,0.09,alpha)
    }
    static let foam:CGImage=bitmap(size:128) {x,y in
        let u=Double(x)/128,v=Double(y)/128
        let threads=pow(0.5+0.5*sin(u*Double.pi*12+sin(v*Double.pi*4)),6)
        let edge=sin(v*Double.pi)*sin(u*Double.pi)
        return (0.90,0.97,0.96,threads*max(0,edge)*0.65)
    }
    static func components(_ color:UIColor)->(CGFloat,CGFloat,CGFloat,CGFloat) {
        #if canImport(UIKit)
        var r:CGFloat=0,g:CGFloat=0,b:CGFloat=0,a:CGFloat=0
        color.getRed(&r,green:&g,blue:&b,alpha:&a);return(r,g,b,a)
        #else
        let c=color.usingColorSpace(.deviceRGB) ?? color
        return(c.redComponent,c.greenComponent,c.blueComponent,c.alphaComponent)
        #endif
    }
    static func matches(_ a:UIColor,_ b:UIColor)->Bool {
        let x=components(a),y=components(b)
        return abs(x.0-y.0)+abs(x.1-y.1)+abs(x.2-y.2)<0.005
    }
    func material(_ finish:SurfaceFinish,tint:UIColor)->SCNMaterial {
        let m=SCNMaterial(),maps=Self.maps[finish]!
        m.name="finish-"+finish.rawValue;m.lightingModel = .physicallyBased;m.emission.intensity=0.35
        m.diffuse.contents=tint;m.multiply.contents=maps.albedo
        m.normal.contents=maps.normal;m.normal.intensity=finish == .stone ? 0.22 : finish == .water ? 0.45 : 0.16
        m.roughness.contents=maps.roughness
        m.metalness.contents=finish == .metal ? 0.78 : finish == .water ? 0.08 : 0
        for property in [m.multiply,m.normal,m.roughness] {property.wrapS = .repeat;property.wrapT = .repeat;property.mipFilter = .linear}
        if finish == .water || finish == .waterfall {
            m.transparency=finish == .water ? 0.80 : 0.68;m.transparencyMode = .singleLayer
            m.isDoubleSided=true;m.writesToDepthBuffer=false
        }
        return m
    }
    static func bitmap(size:Int,pixel:(Int,Int)->(Double,Double,Double,Double))->CGImage {
        var bytes=[UInt8](repeating:0,count:size*size*4)
        for y in 0..<size {for x in 0..<size {
            let p=pixel(x,y),a=max(0,min(1,p.3)),i=(y*size+x)*4
            for (c,value) in [p.0,p.1,p.2].enumerated() {bytes[i+c]=UInt8((max(0,min(1,value))*a*255).rounded())}
            bytes[i+3]=UInt8((a*255).rounded())
        }}
        let data=Data(bytes) as CFData
        return CGImage(width:size,height:size,bitsPerComponent:8,bitsPerPixel:32,bytesPerRow:size*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGBitmapInfo(rawValue:CGImageAlphaInfo.premultipliedLast.rawValue),provider:CGDataProvider(data:data)!,decode:nil,shouldInterpolate:true,intent:.defaultIntent)!
    }
    private static func makeMaps(_ kind:SurfaceFinish)->Maps {
        let n=128
        func height(_ x:Int,_ y:Int)->Double {
            let u=Double((x+n)%n)/Double(n)*2*Double.pi,v=Double((y+n)%n)/Double(n)*2*Double.pi
            let fine=sin(u*23+sin(v*7))*sin(v*19+cos(u*11))
            switch kind {
            case .stone:return 0.5+0.12*sin(u*3+sin(v*2))*sin(v*4)+0.08*fine
            case .metal:return 0.5+0.09*sin(v*49+sin(u)*0.2)+0.02*fine
            case .wood:return 0.5+0.20*sin(u*13+sin(v*2)*0.7)+0.03*fine
            case .cloth:return 0.5+0.10*sin(u*32)*sin(v*32)
            case .water,.waterfall:return 0.5+0.20*sin(u*4+sin(v*3))+0.12*cos(v*6+sin(u*2))
            case .foliage:return 0.5+0.07*fine
            case .enamel:return 0.5+0.025*fine
            }
        }
        let rough:Double
        switch kind {case .stone:rough=0.79;case .metal:rough=0.30;case .wood:rough=0.57;case .cloth:rough=0.88;case .foliage:rough=0.82;case .enamel:rough=0.43;case .water:rough=0.16;case .waterfall:rough=0.28}
        let albedo=bitmap(size:n) {x,y in
            let h=height(x,y),contrast=kind == .wood ? 0.22 : 0.10
            let value=0.95+(h-0.5)*contrast
            return(value,value,value,1)
        }
        let normal=bitmap(size:n) {x,y in
            let dx=(height(x+1,y)-height(x-1,y))*1.3,dy=(height(x,y+1)-height(x,y-1))*1.3
            let length=sqrt(dx*dx+dy*dy+1)
            return(0.5-dx/length*0.5,0.5-dy/length*0.5,0.5+0.5/length,1)
        }
        let roughness=bitmap(size:n) {x,y in let value=rough+(height(x,y)-0.5)*0.12;return(value,value,value,1)}
        return Maps(albedo:albedo,normal:normal,roughness:roughness)
    }
    // Explicit flat normals and UVs give custom vaults the same lighting as blocks.
    static func faceted(_ points:[SCNVector3],indices:[Int32])->SCNGeometry {
        var vertices=[SCNVector3](),normals=[SCNVector3](),uv=[CGPoint]()
        for i in stride(from:0,to:indices.count,by:3) {
            let triangle=indices[i..<i+3].map{points[Int($0)]},a=triangle[0],b=triangle[1],c=triangle[2]
            let ux=Double(b.x-a.x),uy=Double(b.y-a.y),uz=Double(b.z-a.z)
            let vx=Double(c.x-a.x),vy=Double(c.y-a.y),vz=Double(c.z-a.z)
            let nx=uy*vz-uz*vy,ny=uz*vx-ux*vz,nz=ux*vy-uy*vx,length=max(0.000001,sqrt(nx*nx+ny*ny+nz*nz))
            for p in triangle {
                vertices.append(p);normals.append(SCNVector3(nx/length,ny/length,nz/length))
                uv.append(abs(nz)>=abs(nx) && abs(nz)>=abs(ny) ? CGPoint(x:Double(p.x),y:Double(p.y)) : abs(nx)>abs(ny) ? CGPoint(x:Double(p.z),y:Double(p.y)) : CGPoint(x:Double(p.x),y:Double(p.z)))
            }
        }
        return SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:(0..<vertices.count).map{Int32($0)},primitiveType:.triangles)])
    }
}

struct WaterVisual {var material:SCNMaterial;var foam:SCNNode?;var waterfall:Bool;var phase:Double}
extension GardenScene {
    func finish(_ node:SCNNode,_ kind:SurfaceFinish,tint:UIColor) {
        node.geometry?.firstMaterial=style.material(kind,tint:tint)
        node.castsShadow=kind != .water && kind != .waterfall && VisualStyle.components(tint).3>=0.8
    }
    func addWater(_ node:SCNNode,waterfall:Bool=false,foam:SCNNode?=nil) {
        finish(node,waterfall ? .waterfall : .water,tint:water)
        waterVisuals.append(WaterVisual(material:node.geometry!.firstMaterial!,foam:foam,waterfall:waterfall,phase:Double(waterVisuals.count)*0.37))
    }
    func waterFoam(width:CGFloat,depth:CGFloat,at point:SCNVector3,parent:SCNNode)->SCNNode {
        let plane=SCNPlane(width:width,height:depth),m=SCNMaterial()
        m.lightingModel = .constant;m.diffuse.contents=VisualStyle.foam;m.isDoubleSided=true;m.writesToDepthBuffer=false
        plane.firstMaterial=m
        let n=SCNNode(geometry:plane);n.name="waterFoam";n.position=point;n.eulerAngles.x = -.pi/2
        n.categoryBitMask=64;n.castsShadow=false;parent.addChildNode(n);return n
    }
    func animateWater(time:Double) {
        for item in waterVisuals {
            var flow=SCNMatrix4Identity
            flow.m41=SceneScalar(sin(time*0.13+item.phase)*0.055)
            flow.m42=SceneScalar((time*(item.waterfall ? 0.22 : 0.018)).truncatingRemainder(dividingBy:1))
            item.material.normal.contentsTransform=flow
            if item.waterfall {item.material.multiply.contentsTransform=flow}
            item.foam?.opacity=CGFloat(0.28+0.12*sin(time*1.8+item.phase))
        }
    }
    func makeContactShadow()->SCNNode {
        let plane=SCNPlane(width:0.68,height:0.68),m=SCNMaterial()
        m.diffuse.contents=VisualStyle.shadow;m.lightingModel = .constant;m.isDoubleSided=true;m.writesToDepthBuffer=false
        plane.firstMaterial=m
        let shadow=SCNNode(geometry:plane);shadow.name="contactShadow";shadow.categoryBitMask=64
        shadow.eulerAngles.x = -.pi/2;shadow.castsShadow=false;sculpture.addChildNode(shadow);return shadow
    }
    func animateAppearance(_ world:World,plan:MusicalPlan,beat:Double,playing:Bool,seconds:Double,time:Double) {
        let weight=seconds>0 ? 1-exp(-seconds*12) : 1
        for (i,walker) in walkers.enumerated() {
            let motion=plan.motion(voice:i,beat:beat,fallback:0),pulse=playing && world.voices[i].enabled ? exp(-motion.age*60/world.tempo*9)*motion.energy : 0
            if let body=walker.childNode(withName:"body",recursively:false) {
                let anticipation=max(0,1-abs(motion.progress-0.85)/0.15)*0.035
                let target=1+sin(time*1.6+Double(i))*0.009-pulse*0.025-anticipation
                body.scale.y += SceneScalar((target-Double(body.scale.y))*weight)
            }
            if let head=walker.childNode(withName:"head",recursively:false) {
                head.eulerAngles.x=SceneScalar(sin(time*1.4+Double(i))*0.012-pulse*0.035)
                let a=world.tiles[motion.tile],b=world.tiles[motion.nextTile]
                let desired=atan2(Double(b.x-a.x),Double(b.z-a.z))-Double(walker.eulerAngles.y)
                let look=max(-0.12,min(0.12,atan2(sin(desired),cos(desired))))
                head.eulerAngles.y += SceneScalar((look-Double(head.eulerAngles.y))*weight)
                if let body=walker.childNode(withName:"body",recursively:false) {
                    body.eulerAngles.z += SceneScalar((-look*0.28-Double(body.eulerAngles.z))*weight)
                }
                let blinkPhase=(time+Double(i)*0.73).truncatingRemainder(dividingBy:4.9)
                let eyelid=1-0.9*max(0,1-abs(blinkPhase-4.65)/0.10)
                for eye in head.childNodes where eye.name=="eye" {eye.scale.y=SceneScalar(eyelid)}
            }
            guard contactShadows.indices.contains(i) else {continue}
            let shadow=contactShadows[i],role=world.voices[i].role,p=walker.position
            let floor:Double?
            if role == .percussion {floor=Double(world.percussionStage().y)}
            else {floor=CharacterSpace.shadowFloor(SpacePoint(x:Double(p.x),y:Double(p.y),z:Double(p.z)),world:world)}
            shadow.isHidden=walker.isHidden || floor==nil
            if let floor {
                let gap=max(0,Double(p.y)-floor)
                shadow.position=SCNVector3(Double(p.x),floor+0.001,Double(p.z))
                shadow.opacity=CGFloat(0.46/(1+gap*1.5))*walker.opacity
                let spread=1+min(1,gap)*0.25;shadow.scale=SCNVector3(spread,spread,spread)
            }
        }
    }
}
