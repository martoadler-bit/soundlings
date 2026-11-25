import SceneKit
import CoreGraphics
import ImageIO
import SpriteKit
import simd
import Accelerate

extension GardenScene {
    // A camera-centered panorama stays outside editable bounds and collision geometry.
    func applyEnvironment(_ world:World) {
        let key=world.environment.rawValue+world.seedCode
        if backdropKey != key {
            backdropKey=key
            backdropOriginal=Self.bundledBackdrop("Panorama-"+world.environment.rawValue) ?? Self.backdrop(world.environment,seed:world.seed)
            backdropViewport = .zero
            if let image=backdropOriginal {
                atmosphere?.dome.removeFromParentNode()
                atmosphere=AtmosphereLayer(image:image,environment:world.environment,seed:world.seed)
                scene.background.contents=UIColor.black
                if let dome=atmosphere?.dome {scene.rootNode.addChildNode(dome)}
            }
        }
        if let panorama=Self.bundledBackdrop("Panorama-"+world.environment.rawValue),panorama.width==panorama.height*2 {
            scene.lightingEnvironment.contents=panorama
            scene.lightingEnvironment.intensity=world.environment == .space ? 0.35 : 0.55
        }
        let underwater=world.environment == .underwater,space=world.environment == .space
        let fog=world.environment == .mist || underwater
        environmentFog=fog
        scene.fogStartDistance=0
        scene.fogEndDistance=0
        scene.fogDensityExponent=1.4
        scene.fogColor=underwater ? UIColor(red:0.04,green:0.25,blue:0.34,alpha:1) : UIColor(red:0.58,green:0.65,blue:0.72,alpha:1)
        let ambient=scene.rootNode.childNode(withName:"ambientLight",recursively:false)?.light
        let sun=scene.rootNode.childNode(withName:"sunLight",recursively:false)?.light
        ambient?.intensity=space ? 220 : underwater ? 330 : 280
        ambient?.color=underwater ? UIColor(red:0.45,green:0.88,blue:0.91,alpha:1) : UIColor(red:0.76,green:0.82,blue:0.96,alpha:1)
        sun?.intensity=space ? 720 : 980
        sun?.color=space ? UIColor(red:0.73,green:0.80,blue:1,alpha:1) : underwater ? UIColor(red:0.65,green:1,blue:0.93,alpha:1) : UIColor(red:1,green:0.87,blue:0.71,alpha:1)
    }
    func placeEnvironment(radius:Double) {
        guard let dome=atmosphere?.dome else {return}
        dome.position=camera.position
        // An orthographic overview otherwise samples the heavily compressed nadir.
        // Preserve azimuth, but limit background pitch to a gentle horizon angle.
        if atmosphere?.oceanMovie != nil {
            dome.simdOrientation=simd_quatf(angle:-2.4,axis:SIMD3<Float>(0,1,0))
            dome.scale=SCNVector3(radius,radius,radius)
            camera.camera?.zFar=max(camera.camera?.zFar ?? 200,radius*2)
            atmosphere?.projectOcean(camera:camera,viewport:backdropViewport,radius:radius)
            return
        }
        let forward=camera.convertVector(SCNVector3(0,0,-1),to:nil)
        let pitch=asin(max(-1,min(1,Double(forward.y))))
        let limit=Double.pi/18
        let correction=camera.camera?.usesOrthographicProjection == true ? pitch-max(-limit,min(limit,pitch)) : 0
        let right=camera.convertVector(SCNVector3(1,0,0),to:nil)
        let axis=simd_normalize(SIMD3<Float>(Float(right.x),Float(right.y),Float(right.z)))
        dome.simdOrientation=simd_quatf(angle:Float(correction),axis:axis)
        dome.scale=SCNVector3(radius,radius,radius)
        camera.camera?.zFar=max(camera.camera?.zFar ?? 200,radius*2)
        atmosphere?.projectOverview(camera:camera,viewport:backdropViewport,radius:radius)
    }
    func fitBackdrop(_ size:CGSize) {
        guard size != backdropViewport else {return}
        backdropViewport=size
        atmosphere?.resize(size)
    }
    private final class PreparedPanorama:NSObject {
        let image:CGImage
        init(_ image:CGImage) {self.image=image}
    }
    private static let panoramaCache:NSCache<NSString,PreparedPanorama> = {
        let cache=NSCache<NSString,PreparedPanorama>()
        cache.countLimit=2;cache.totalCostLimit=72*1024*1024
        return cache
    }()
    static func bundledBackdrop(_ name:String)->CGImage? {
        guard name.hasPrefix("Panorama-") else {return rawBundledBackdrop(name)}
        if let cached=panoramaCache.object(forKey:name as NSString) {return cached.image}
        guard let source=rawBundledBackdrop(name) else {return nil}
        var image=reconstructPanorama(source) ?? source
        if name == "Panorama-sunset" {image=closePanoramaWrap(image) ?? image}
        panoramaCache.setObject(PreparedPanorama(image),forKey:name as NSString,cost:image.bytesPerRow*image.height)
        return image
    }
    // Lanczos reconstruction before GPU magnification avoids enlarged bilinear
    // texel blocks. This improves interpolation, not the source artwork's detail.
    static func reconstructPanorama(_ image:CGImage,maxWidth:Int=4096)->CGImage? {
        guard image.width<maxWidth else {return image}
        let width=maxWidth,height=max(1,Int((Double(image.height)*Double(width)/Double(image.width)).rounded()))
        let colorSpace=CGColorSpace(name:CGColorSpace.sRGB)!
        let format=CGImageAlphaInfo.premultipliedLast.rawValue
        guard let source=CGContext(data:nil,width:image.width,height:image.height,bitsPerComponent:8,bytesPerRow:image.width*4,space:colorSpace,bitmapInfo:format),
              let output=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:colorSpace,bitmapInfo:format),
              let sourceData=source.data,let outputData=output.data else {return nil}
        source.draw(image,in:CGRect(x:0,y:0,width:image.width,height:image.height))
        var input=vImage_Buffer(data:sourceData,height:vImagePixelCount(image.height),width:vImagePixelCount(image.width),rowBytes:source.bytesPerRow)
        var result=vImage_Buffer(data:outputData,height:vImagePixelCount(height),width:vImagePixelCount(width),rowBytes:output.bytesPerRow)
        guard vImageScale_ARGB8888(&input,&result,nil,vImage_Flags(kvImageHighQualityResampling)) == kvImageNoError else {return nil}
        return output.makeImage()
    }
    // Prepare a periodic GPU texture once. Feather only the outer 6% on each
    // side; the sun, horizon and central composition are left untouched.
    static func closePanoramaWrap(_ image:CGImage)->CGImage? {
        let width=image.width,height=image.height,stride=width*4
        guard width>2,let context=CGContext(data:nil,width:width,height:height,bitsPerComponent:8,bytesPerRow:stride,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue),let data=context.data else {return nil}
        context.draw(image,in:CGRect(x:0,y:0,width:width,height:height))
        let pixels=data.assumingMemoryBound(to:UInt8.self),band=max(2,Int(Double(width)*0.06))
        for y in 0..<height {for x in 0..<band {
            let t=Double(x)/Double(band-1),blend=0.5*(1-t*t*(3-2*t))
            let left=y*stride+x*4,right=y*stride+(width-1-x)*4
            for channel in 0..<4 {
                let a=Double(pixels[left+channel]),b=Double(pixels[right+channel])
                pixels[left+channel]=UInt8((a+(b-a)*blend).rounded())
                pixels[right+channel]=UInt8((b+(a-b)*blend).rounded())
            }
        }}
        return context.makeImage()
    }
    private static func rawBundledBackdrop(_ name:String)->CGImage? {
        #if canImport(UIKit)
        return UIImage(named:name)?.cgImage
        #else
        let file=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("Assets.xcassets/"+name+".imageset/backdrop.png")
        guard FileManager.default.fileExists(atPath:file.path),let source=CGImageSourceCreateWithURL(file as CFURL,nil) else {return nil}
        return CGImageSourceCreateImageAtIndex(source,0,nil)
        #endif
    }
    static func photographicBackdrop(_ environment:WorldEnvironment)->CGImage? {bundledBackdrop("Backdrop-"+environment.rawValue)}
    static func backdrop(_ environment:WorldEnvironment,seed:UInt64)->CGImage? {
        if let photograph=photographicBackdrop(environment) {return photograph}
        let space=CGColorSpaceCreateDeviceRGB()
        guard let c=CGContext(data:nil,width:2048,height:2048,bitsPerComponent:8,bytesPerRow:0,space:space,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {return nil}
        c.scaleBy(x:2,y:2)
        var random=WorldRandom(state:seed ^ 0xA7B39D21)
        func color(_ values:[CGFloat])->CGColor {CGColor(colorSpace:space,components:values)!}
        func gradient(_ values:[[CGFloat]],_ locations:[CGFloat])->CGGradient {
            CGGradient(colorsSpace:space,colors:values.map{color($0)} as CFArray,locations:locations)!
        }
        func glow(_ x:Double,_ y:Double,_ rx:Double,_ ry:Double,_ rgb:[CGFloat],_ alpha:CGFloat) {
            c.saveGState();c.translateBy(x:x,y:y);c.scaleBy(x:rx,y:ry)
            let g=gradient([[rgb[0],rgb[1],rgb[2],alpha],[rgb[0],rgb[1],rgb[2],0]],[0,1])
            c.drawRadialGradient(g,startCenter:.zero,startRadius:0,endCenter:.zero,endRadius:1,options:[])
            c.restoreGState()
        }
        func dot(_ x:Double,_ y:Double,_ radius:Double,_ rgba:[CGFloat]) {
            c.setFillColor(color(rgba));c.fillEllipse(in:CGRect(x:x-radius,y:y-radius,width:radius*2,height:radius*2))
        }
        let tones:[[CGFloat]]
        switch environment {
        case .space:tones=[[0.012,0.022,0.07,1],[0.055,0.075,0.17,1],[0.12,0.075,0.19,1]]
        case .underwater:tones=[[0.13,0.49,0.56,1],[0.035,0.25,0.36,1],[0.012,0.07,0.16,1]]
        case .sky:tones=[[0.29,0.46,0.62,1],[0.65,0.72,0.77,1],[0.91,0.78,0.69,1]]
        case .mist:tones=[[0.31,0.42,0.49,1],[0.58,0.67,0.69,1],[0.77,0.78,0.71,1]]
        case .sunset:tones=[[0.19,0.18,0.34,1],[0.59,0.37,0.47,1],[0.96,0.70,0.48,1]]
        }
        c.drawLinearGradient(gradient(tones,[0,0.55,1]),start:CGPoint(x:0,y:1024),end:.zero,options:[])
        let phase=random.range(0,6.28)
        if environment == .space {
            // Soft, irregular emission clouds; the centre stays quiet for the world.
            for i in 0..<70 {
                let t=Double(i)/69,x=40+t*1050,y=180+t*480+sin(t*8+phase)*95
                glow(x,y,random.range(85,210),random.range(40,100),i%3==0 ? [0.30,0.52,0.67] : [0.47,0.25,0.57],0.035)
            }
            for _ in 0..<620 {
                let x=random.unit()*1024,y=random.unit()*1024,r=random.range(0.28,0.95)
                dot(x,y,r,[0.8,0.88,1,CGFloat(random.range(0.12,0.72))])
            }
            for _ in 0..<12 {
                let x=random.unit()*1024,y=random.unit()*1024
                glow(x,y,9,9,[0.6,0.80,1],0.22);dot(x,y,1,[0.95,0.98,1,0.9])
                c.setStrokeColor(color([0.7,0.85,1,0.3]));c.setLineWidth(0.4)
                c.move(to:CGPoint(x:x-4,y:y));c.addLine(to:CGPoint(x:x+4,y:y));c.move(to:CGPoint(x:x,y:y-4));c.addLine(to:CGPoint(x:x,y:y+4));c.strokePath()
            }
            let x=790.0,y=790.0,r=98.0
            glow(x,y,r*1.6,r*1.6,[0.49,0.56,0.82],0.18)
            c.saveGState();c.addEllipse(in:CGRect(x:x-r,y:y-r,width:r*2,height:r*2));c.clip()
            c.drawRadialGradient(gradient([[0.63,0.69,0.76,1],[0.23,0.29,0.43,1],[0.035,0.055,0.13,1]],[0,0.6,1]),startCenter:CGPoint(x:x-60,y:y+55),startRadius:0,endCenter:CGPoint(x:x-60,y:y+55),endRadius:230,options:.drawsAfterEndLocation)
            for _ in 0..<45 {glow(x+random.range(-95,95),y+random.range(-95,95),random.range(8,30),random.range(4,15),[0.30,0.37,0.45],0.07)}
            glow(x+70,y-30,130,150,[0.012,0.022,0.07],0.95);c.restoreGState()
        } else if environment == .underwater {
            glow(260,1120,700,420,[0.48,0.95,0.86],0.65)
            // Feathered shafts rather than flat polygons.
            for beam in 0..<5 {
                let source=Double(beam)*220-100
                for layer in 0..<18 {
                    let width=Double(18-layer)*5
                    c.setFillColor(color([0.62,0.95,0.87,0.003]))
                    c.beginPath();c.move(to:CGPoint(x:source-width,y:1100));c.addLine(to:CGPoint(x:source+width,y:1100));c.addLine(to:CGPoint(x:source-260+width*2,y:0));c.addLine(to:CGPoint(x:source-260-width*2,y:0));c.closePath();c.fillPath()
                }
            }
            for layer in 0..<4 {
                let base=90-Double(layer)*26
                c.setFillColor(color([0.035,0.13+CGFloat(layer)*0.015,0.20,0.28]))
                c.beginPath();c.move(to:.zero)
                for x in stride(from:0.0,through:1024,by:8) {c.addLine(to:CGPoint(x:x,y:base+sin(x/170+Double(layer)+phase)*35+cos(x/95)*13))}
                c.addLine(to:CGPoint(x:1024,y:0));c.closePath();c.fillPath()
            }
            for side in [0.0,1024.0] {
                for _ in 0..<20 {
                    let x=side+random.range(-85,85),height=random.range(70,250),bend=random.range(-65,65)
                    c.setStrokeColor(color([0.07,0.27,0.28,0.32]));c.setLineWidth(random.range(1.2,3.5))
                    c.move(to:CGPoint(x:x,y:0));c.addCurve(to:CGPoint(x:x+bend,y:height),control1:CGPoint(x:x-30,y:height*0.3),control2:CGPoint(x:x+bend+20,y:height*0.7));c.strokePath()
                }
            }
            for _ in 0..<100 {
                let x=random.unit()*1024,y=random.unit()*1024,r=random.range(0.4,1.7)
                glow(x,y,r*3,r*3,[0.55,0.90,0.92],0.10);dot(x,y,r,[0.69,0.95,0.95,0.20])
            }
            for _ in 0..<16 {
                let x=random.unit()*1024,y=random.unit()*1024,r=random.range(2,5)
                c.setStrokeColor(color([0.70,0.95,0.95,0.13]));c.setLineWidth(0.5);c.strokeEllipse(in:CGRect(x:x,y:y,width:r*2,height:r*2))
                dot(x+r*0.6,y+r*1.5,r*0.18,[0.9,1,1,0.45])
            }
        } else {
            let sunset=environment == .sunset,mist=environment == .mist
            let sunX=760.0,sunY=sunset ? 380.0 : 810.0
            glow(sunX,sunY,350,260,sunset ? [1,0.72,0.45] : [1,0.91,0.76],sunset ? 0.38 : 0.23)
            if !mist {dot(sunX,sunY,sunset ? 42 : 24,[1,0.90,0.71,0.75]);glow(sunX,sunY,80,80,[1,0.88,0.64],0.25)}
            for layer in 0..<5 {
                let depth=Double(layer),base=80+depth*43
                let tint:[CGFloat]=sunset ? [0.30,0.27,0.39,CGFloat(0.10+depth*0.035)] : [0.28,0.43,0.49,CGFloat(0.08+depth*0.025)]
                c.setFillColor(color(tint));c.beginPath();c.move(to:.zero)
                for x in stride(from:0.0,through:1024,by:8) {
                    let peak=sin(x/(120+depth*20)+phase+depth)*40+cos(x/65+depth)*18
                    c.addLine(to:CGPoint(x:x,y:base+peak))
                }
                c.addLine(to:CGPoint(x:1024,y:0));c.closePath();c.fillPath()
                glow(500,base+55,900,65,[0.88,0.87,0.79],mist ? 0.20 : 0.08)
            }
            for _ in 0..<24 {
                let x=random.range(-150,1150),y=random.range(390,1010)
                glow(x,y,random.range(100,270),random.range(12,35),[1,0.94,0.86],mist ? 0.075 : 0.11)
            }
        }
        // A restrained vignette and fine grain keep the gradient from looking synthetic.
        for edge in [-260.0,1284.0] {glow(edge,400,520,950,[0.015,0.025,0.055],0.25)}
        for _ in 0..<18000 {
            dot(random.unit()*1024,random.unit()*1024,0.28,[1,1,1,0.018])
        }
        return c.makeImage()
    }
}

// A few manually animated image layers: no physics, actions, world geometry, or audio-thread work.
// Explicit time keeps offline exports deterministic, including both split-screen views.
final class AtmosphereLayer {
    let canvas=SKScene(size:CGSize(width:2048,height:1024))
    let dome=SCNNode(geometry:SCNSphere(radius:1))
    let motionDome=SCNNode(geometry:SCNSphere(radius:1))
    let photo:SKSpriteNode
    let content=SKNode()
    let environment:WorldEnvironment
    let seed:UInt64
    var clouds=[SKSpriteNode]()
    let meteor=SKShapeNode()
    private(set) var oceanMovie:OceanMovie?
    private var oceanSphere:SCNGeometry?
    private var oceanKey=[Float]()
    private var lastTime=0.0
    private var cameraHeading:Float=0,cameraPitch:Float=0
    private var overviewActive=true
    private var panoramaMaterial:SCNMaterial?
    private var sphereTime:Double?
    private var sphereVertices:SCNGeometrySource?
    private var sphereElements=[SCNGeometryElement]()
    private var sphereUV=[CGPoint]()
    var sunRays=[SKSpriteNode](),glitter=[SKShapeNode](),caustics=[SKShapeNode]()
    let overviewImage:CGImage
    private var overviewMaterial:SCNMaterial?
    private var overviewKey=[Float]()
    private var sphericalGeometry:SCNGeometry?
    private var sphericalMotionGeometry:SCNGeometry?

    // A separate pinhole projection for distant scenery. Orthographic world zoom
    // must never magnify a small patch of the panorama or deform it at sphere edges.
    static func panoramaUV(_ direction:SIMD3<Float>,around longitude:Float)->CGPoint {
        let ray=simd_normalize(direction)
        var u=atan2(-ray.x,-ray.z)/(2 * Float.pi)
        u += (longitude-u).rounded() // unwrap across the longitude seam before interpolation
        return CGPoint(x:Double(u),y:Double(0.5-asin(max(-1,min(1,ray.y)))/Float.pi))
    }
    // Use almost the complete photographic plate, preserving proportions.
    // Longitude follows camera azimuth continuously; the prepared texture wraps.
    static func overviewCrop(aspect:Float,imageAspect:Float,heading:Float,pitch:Float)->CGRect {
        let width=min(1,aspect/imageAspect)/1.08
        let height=min(1,imageAspect/aspect)/1.08
        // Inside the sky, image U grows to screen-right while camera longitude
        // grows toward world-left. Their signs must be opposite; otherwise the
        // photograph slides against the world and the atmospheric layer.
        let cx=0.5-heading/(2*Float.pi)
        let cy=0.5+(1-height)*0.4*sin(pitch)
        return CGRect(x:Double(cx-width/2),y:Double(cy-height/2),width:Double(width),height:Double(height))
    }
    func projectOverview(camera:SCNNode,viewport:CGSize,radius:Double) {
        let direction=camera.convertVector(SCNVector3(0,0,-1),to:nil)
        cameraHeading=atan2(-Float(direction.x),-Float(direction.z))
        cameraPitch=asin(max(-1,min(1,Float(direction.y))))
        overviewActive=camera.camera?.usesOrthographicProjection == true
        updateEnvironmentalLight()
        guard overviewActive else {
            if let original=sphericalGeometry,let motion=sphericalMotionGeometry {
                dome.geometry=original;motionDome.geometry=motion
                sphericalGeometry=nil;sphericalMotionGeometry=nil;overviewKey=[]
            }
            animateSphere()
            return
        }
        guard viewport.width>0,viewport.height>0,radius>0 else {return}
        let aspect=Float(viewport.width/viewport.height)
        let halfHeight=Float(camera.camera?.orthographicScale ?? 1)
        func local(_ v:SCNVector3)->SIMD3<Float> {
            let w=dome.convertVector(camera.convertVector(v,to:nil),from:nil)
            return simd_normalize(SIMD3<Float>(Float(w.x),Float(w.y),Float(w.z)))
        }
        let right=local(SCNVector3(1,0,0)),up=local(SCNVector3(0,1,0)),forward=local(SCNVector3(0,0,-1))
        let key=[right.x,right.y,right.z,up.x,up.y,up.z,forward.x,forward.y,forward.z,aspect,halfHeight,Float(radius),environment == .space ? 0 : Float(lastTime)]
        guard key != overviewKey else {return};overviewKey=key
        if sphericalGeometry == nil {sphericalGeometry=dome.geometry;sphericalMotionGeometry=motionDome.geometry}
        let longitude=atan2(-forward.x,-forward.z)/(2 * Float.pi)
        let heading=longitude*2*Float.pi
        let crop=Self.overviewCrop(aspect:aspect,imageAspect:Float(overviewImage.width)/Float(overviewImage.height),heading:heading,pitch:asin(max(-1,min(1,forward.y))))
        let columns=48,rows=32
        var vertices=[SCNVector3](),uv=[CGPoint](),motionUV=[CGPoint](),indices=[Int32]()
        vertices.reserveCapacity((columns+1)*(rows+1));uv.reserveCapacity((columns+1)*(rows+1))
        for row in 0...rows {for column in 0...columns {
            let x=Float(column)/Float(columns)*2-1,y=Float(row)/Float(rows)*2-1
            let p=right*(x*halfHeight*aspect/Float(radius))+up*(y*halfHeight/Float(radius))+forward*0.8
            vertices.append(SCNVector3(p.x,p.y,p.z))
            let coordinate=CGPoint(x:crop.minX+Double(x+1)*0.5*crop.width,y:crop.minY+Double(1-y)*0.5*crop.height)
            uv.append(Self.flowUV(coordinate,environment:environment,time:lastTime,panoramic:false))
            // Atmospheric motion remains camera-relative, with its own panoramic
            // coordinates instead of stretching the static photograph into a globe.
            motionUV.append(environment == .space ? Self.panoramaUV(forward+right*x+up*(y/aspect),around:longitude) : coordinate)
        }}
        for row in 0..<rows {for column in 0..<columns {
            let a=Int32(row*(columns+1)+column),b=a+1,c=a+Int32(columns+1),d=c+1
            indices += [a,b,c,b,d,c]
        }}
        let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        geometry.materials=overviewMaterial.map{[$0]} ?? []
        let overlay=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(textureCoordinates:motionUV)],elements:geometry.elements)
        overlay.materials=sphericalMotionGeometry?.materials ?? []
        dome.geometry=geometry;motionDome.geometry=overlay
    }
    init(image:CGImage,environment:WorldEnvironment,seed:UInt64) {
        self.environment=environment;self.seed=seed
        let plateImage=GardenScene.photographicBackdrop(environment) ?? image
        overviewImage=GardenScene.closePanoramaWrap(plateImage) ?? plateImage
        photo=SKSpriteNode(texture:SKTexture(cgImage:image))
        canvas.scaleMode = .aspectFill;canvas.isPaused=true;canvas.isUserInteractionEnabled=false
        // SceneKit samples SpriteKit backgrounds with the opposite vertical origin.
        // Compensate once for the complete composition, including clouds and meteors.
        content.yScale = -1;content.position.y=canvas.size.height
        // Keep the photographic source on the GPU directly. Only atmospheric overlays
        // pass through SpriteKit's intermediate render texture.
        canvas.backgroundColor = .clear;canvas.addChild(content);content.addChild(photo);photo.isHidden=true
        let material=SCNMaterial();material.lightingModel = .constant;material.isDoubleSided=true
        material.diffuse.contents=image;material.diffuse.wrapS = .repeat;material.diffuse.wrapT = .clamp
        material.diffuse.minificationFilter = .linear;material.diffuse.magnificationFilter = .linear
        material.diffuse.mipFilter = .linear;material.diffuse.maxAnisotropy=8
        material.readsFromDepthBuffer=false;material.writesToDepthBuffer=false
        let plate=material.copy() as! SCNMaterial
        plate.diffuse.contents=overviewImage;plate.diffuse.wrapS = .repeat;plate.diffuse.wrapT = .clamp
        overviewMaterial=plate
        panoramaMaterial=material
        dome.geometry?.firstMaterial=material
        (dome.geometry as? SCNSphere)?.segmentCount=192
        let overlay=SCNMaterial();overlay.lightingModel = .constant;overlay.isDoubleSided=true
        overlay.diffuse.contents=canvas;overlay.diffuse.wrapS = .repeat;overlay.diffuse.wrapT = .clamp
        overlay.transparencyMode = .singleLayer;overlay.blendMode = .alpha
        overlay.readsFromDepthBuffer=false;overlay.writesToDepthBuffer=false
        overlay.diffuse.minificationFilter = .linear;overlay.diffuse.magnificationFilter = .linear
        overlay.diffuse.mipFilter = .linear;overlay.diffuse.maxAnisotropy=8
        motionDome.geometry?.firstMaterial=overlay
        (motionDome.geometry as? SCNSphere)?.segmentCount=192
        motionDome.name="environmentMotion";motionDome.categoryBitMask=32;motionDome.castsShadow=false;motionDome.renderingOrder = -999
        dome.addChildNode(motionDome)
        dome.name="environmentPanorama";dome.categoryBitMask=32;dome.castsShadow=false;dome.renderingOrder = -1000
        if [.sky,.mist,.sunset].contains(environment),let cloud=GardenScene.bundledBackdrop("Backdrop-clouds") {
            let texture=SKTexture(cgImage:cloud);texture.filteringMode = .linear;texture.usesMipmaps=true
            for _ in 0..<3 {let sprite=SKSpriteNode(texture:texture);sprite.zPosition=1;clouds.append(sprite);content.addChild(sprite)}
        }
        meteor.strokeColor=UIColor(red:0.78,green:0.88,blue:1,alpha:1);meteor.lineWidth=1.1;meteor.glowWidth=2.5;meteor.zPosition=2;meteor.alpha=0
        if environment == .space {content.addChild(meteor)}
        #if canImport(UIKit)
        if environment == .sunset {oceanMovie=OceanMovie.bundled()}
        #endif
        prepareEnvironmentalLight()
        resize(CGSize(width:1024,height:1024))
    }
    // Real spherical movie coordinates: no photographic sliding, UV flow or
    // pitch counter-rotation. Both camera modes sample the same world bearings.
    func projectOcean(camera:SCNNode,viewport:CGSize,radius:Double) {
        guard let material=panoramaMaterial,viewport.width>0,viewport.height>0 else {return}
        if oceanSphere == nil {
            let sphere=SCNSphere(radius:1);sphere.segmentCount=192;sphere.materials=[material];oceanSphere=sphere
        }
        guard camera.camera?.usesOrthographicProjection == true else {
            dome.geometry=oceanSphere;oceanKey=[];return
        }
        let aspect=Float(viewport.width/viewport.height),height=Float(camera.camera?.orthographicScale ?? 1)
        func vector(_ value:SCNVector3)->SIMD3<Float> {
            let v=dome.convertVector(camera.convertVector(value,to:nil),from:nil)
            return simd_normalize(SIMD3<Float>(Float(v.x),Float(v.y),Float(v.z)))
        }
        let right=vector(SCNVector3(1,0,0)),up=vector(SCNVector3(0,1,0)),forward=vector(SCNVector3(0,0,-1))
        let key=[right.x,right.y,right.z,up.x,up.y,up.z,forward.x,forward.y,forward.z,aspect,height,Float(radius)]
        guard key != oceanKey else {return};oceanKey=key
        let longitude=atan2(-forward.x,-forward.z)/(2 * Float.pi)
        let tanX=tan(Float.pi*46/180),tanY=tanX/aspect
        let columns=64,rows=48
        var vertices=[SCNVector3](),uv=[CGPoint](),indices=[Int32]()
        for row in 0...rows {for column in 0...columns {
            let x=Float(column)/Float(columns)*2-1,y=Float(row)/Float(rows)*2-1
            let p=right*(x*height*aspect/Float(radius))+up*(y*height/Float(radius))+forward*0.8
            vertices.append(SCNVector3(p.x,p.y,p.z))
            uv.append(Self.panoramaUV(forward+right*x*tanX+up*y*tanY,around:longitude))
        }}
        for row in 0..<rows {for column in 0..<columns {
            let a=Int32(row*(columns+1)+column),b=a+1,c=a+Int32(columns+1),d=c+1
            indices += [a,b,c,b,d,c]
        }}
        let geometry=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        geometry.name="worldAnchoredOceanVideo";geometry.materials=[material];dome.geometry=geometry
    }
    private static func smooth(_ a:Double,_ b:Double,_ value:Double)->Double {
        let t=max(0,min(1,(value-a)/(b-a)));return t*t*(3-2*t)
    }
    // Small, spatially masked texture flow; rocks and horizons stay stable.
    // Integer longitude frequencies and pinned edges preserve horizontal seams.
    static func flowUV(_ uv:CGPoint,environment:WorldEnvironment,time:Double,panoramic:Bool)->CGPoint {
        guard time.isFinite else {return uv}
        let u=Double(uv.x),v=Double(uv.y),x=u-floor(u),t=max(0,time)
        let edge=pow(sin(x * .pi),2),vertical=pow(sin(v * .pi),2)
        var dx=0.0,dy=0.0
        switch environment {
        case .underwater:
            let surface=1-smooth(0.12,0.34,v)
            let current=sin(t*0.75+v*5)
            let plants=(1-smooth(0.12,0.29,x)+smooth(0.73,0.9,x))*smooth(0.2,0.45,v)*pow(1-v,1.5)
            dx=0.0035*surface*sin(2 * .pi*(x*9+v*4)-t*1.35)+0.028*plants*current
            dy=0.002*surface*cos(2 * .pi*x*7-t*1.1)
        case .sunset:
            let horizon=panoramic ? 0.5 : 0.63
            let water=smooth(horizon+0.015,horizon+0.09,v)
            let depth=max(0,(v-horizon)/(1-horizon))
            dx=water*(0.001+depth*0.003)*sin(2 * .pi*(x*14+v*5)-t*1.5)
            dy=water*(0.0006+depth*0.0016)*sin(2 * .pi*(x*7-v*9)+t*1.05)
            let sky=1-smooth(horizon-0.15,horizon,v)
            dx += sky*0.006*sin(t*0.035+v*2)
        case .sky,.mist:
            let sky=1-smooth(panoramic ? 0.38 : 0.22,panoramic ? 0.5 : 0.31,v)
            dx=sky*0.008*sin(t*0.04+v*2)
        case .space:break
        }
        return CGPoint(x:u+dx*edge*vertical,y:max(0,min(1,v+dy*edge*vertical)))
    }
    private func animateSphere() {
        guard environment != .space,let material=panoramaMaterial else {return}
        if sphereTime==lastTime && dome.geometry?.name=="animatedPanoramaSphere" {return}
        sphereTime=lastTime
        if sphereVertices == nil {
            let columns=96,rows=48
            var vertices=[SCNVector3](),indices=[Int32]()
            for row in 0...rows {for column in 0...columns {
                let u=Double(column)/Double(columns),v=Double(row)/Double(rows)
                vertices.append(SCNVector3(-sin(u*2 * .pi)*sin(v * .pi),cos(v * .pi),-cos(u*2 * .pi)*sin(v * .pi)))
                sphereUV.append(CGPoint(x:u,y:v))
            }}
            for row in 0..<rows {for column in 0..<columns {
                let a=Int32(row*(columns+1)+column),b=a+1,c=a+Int32(columns+1),d=c+1
                indices += [a,b,c,b,d,c]
            }}
            sphereVertices=SCNGeometrySource(vertices:vertices)
            sphereElements=[SCNGeometryElement(indices:indices,primitiveType:.triangles)]
        }
        let uv=sphereUV.map{Self.flowUV($0,environment:environment,time:lastTime,panoramic:true)}
        let geometry=SCNGeometry(sources:[sphereVertices!,SCNGeometrySource(textureCoordinates:uv)],elements:sphereElements)
        geometry.name="animatedPanoramaSphere";geometry.materials=[material]
        dome.geometry=geometry
    }
    private static let rayTexture:CGImage? = {
        guard let c=CGContext(data:nil,width:128,height:512,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue) else {return nil}
        // Feather across the beam and fade its far end, avoiding hard polygons.
        for y in 0..<512 {
            let depth=Double(y)/511,half=10+depth*48
            for x in 0..<128 {
                let distance=abs(Double(x)-64)/half
                guard distance<1 else {continue}
                let alpha=pow(1-distance*distance,2)*sin(depth * .pi)*0.24
                c.setFillColor(CGColor(red:0.60,green:0.94,blue:0.92,alpha:alpha));c.fill(CGRect(x:x,y:y,width:1,height:1))
            }
        }
        return c.makeImage()
    }()
    private func prepareEnvironmentalLight() {
        if environment == .underwater,let image=Self.rayTexture {
            let texture=SKTexture(cgImage:image);texture.filteringMode = .linear
            for i in 0..<6 {
                let ray=SKSpriteNode(texture:texture);ray.anchorPoint=CGPoint(x:0.5,y:1);ray.zPosition=3
                ray.size=CGSize(width:210+i*20,height:950);content.addChild(ray);sunRays.append(ray)
            }
            for _ in 0..<12 {
                let line=SKShapeNode();line.strokeColor=UIColor(red:0.65,green:1,blue:0.91,alpha:1);line.lineWidth=1;line.glowWidth=2;line.zPosition=2
                content.addChild(line);caustics.append(line)
            }
        }
        if environment == .sunset {
            for _ in 0..<40 {
                let line=SKShapeNode();line.fillColor=UIColor(red:1,green:0.85,blue:0.49,alpha:1);line.strokeColor = .clear;line.glowWidth=1.5;line.zPosition=3
                content.addChild(line);glitter.append(line)
            }
        }
    }
    static func solarSpecular(u:Double,v:Double,time:Double,heading:Double,pitch:Double,panoramic:Bool)->Double {
        let sunU=panoramic ? 0.52 : 0.89
        let azimuth=(0.5-sunU)*2 * Double.pi,altitude=0.08
        let light=SIMD3<Double>(-sin(azimuth)*cos(altitude),sin(altitude),-cos(azimuth)*cos(altitude))
        let elevation=max(0.015,min(Double.pi/2-0.01,abs(pitch)))
        let view=SIMD3<Double>(sin(heading)*cos(elevation),sin(elevation),cos(heading)*cos(elevation))
        let half=simd_normalize(light+view)
        // Wave slopes use the same traveling phases as the water's texture flow.
        let nx = -0.10*cos(2 * Double.pi*(u*14+v*5)-time*1.5)
        let nz = -0.06*cos(2 * Double.pi*(u*7-v*9)+time*1.05)
        let normal=simd_normalize(SIMD3<Double>(nx,1,nz))
        let fresnel=0.02+0.98*pow(1-max(0,simd_dot(normal,view)),5)
        return min(1,pow(max(0,simd_dot(normal,half)),40)*fresnel*8)
    }
    private func updateEnvironmentalLight() {
        let t=lastTime,phase=Double(seed%997)/997,w=Double(canvas.size.width),h=Double(canvas.size.height)
        for (i,ray) in sunRays.enumerated() {
            let p=Double(i)*1.73+phase
            // Surface ripples drive both beam direction and transmitted intensity.
            ray.position=CGPoint(x:w*(0.24+Double(i)*0.1)+sin(t*0.65+p)*18,y:h*1.03)
            ray.zRotation=CGFloat(-0.18+Double(i)*0.065+sin(t*0.75+p)*0.045)
            ray.alpha=CGFloat(0.30+0.14*sin(t*1.1+p))
        }
        for (i,line) in caustics.enumerated() {
            let p=Double(i)*2.17+phase,x=(Double(i%4)+0.5)*w/4,y=30+Double(i/4)*h*0.055
            let path=CGMutablePath();path.move(to:CGPoint(x:x-80,y:y))
            path.addCurve(to:CGPoint(x:x+80,y:y),control1:CGPoint(x:x-30,y:y+16*sin(t*0.8+p)),control2:CGPoint(x:x+30,y:y+15*cos(t*0.7+p)))
            line.path=path;line.alpha=CGFloat(0.045+0.025*sin(t*0.9+p))
        }
        let horizon=overviewActive ? 0.63 : 0.5
        // Analytic wave normals, sun/view half-vector and Schlick Fresnel modulate
        // a fragmented highlight streak over the photographic water.
        let pitch=Double(cameraPitch),heading=Double(cameraHeading)
        let sunU=overviewActive ? 0.89 : 0.52
        for (i,line) in glitter.enumerated() {
            let depth=(Double(i)+0.5)/Double(glitter.count),p=Double(i)*2.399+phase
            let v=horizon+0.02+depth*(0.97-horizon)
            let u=sunU+sin(heading+2.45)*0.025*depth+sin(t*1.5+p)*0.006*depth
            let width=(6+depth*48)*(0.65+0.35*sin(t*1.2+p))
            line.path=CGPath(ellipseIn:CGRect(x:-width/2,y:-0.6-depth,width:width,height:1.2+depth*2),transform:nil)
            line.position=CGPoint(x:u*w,y:(1-v)*h)
            let specular=Self.solarSpecular(u:u,v:v,time:t,heading:heading,pitch:pitch,panoramic:!overviewActive)
            line.alpha=CGFloat((0.015+specular*0.28)*(0.5+0.5*sin(t*1.6+p)))
        }
    }
    func resize(_ viewport:CGSize) {
        guard viewport.width>0,viewport.height>0 else {return}
        // Longitude/latitude coordinates never depend on portrait, landscape or split screen.
        canvas.size=CGSize(width:2048,height:1024)
        content.position.y=canvas.size.height
        guard let texture=photo.texture else {return}
        let native=texture.size(),scale=max(canvas.size.width/native.width,canvas.size.height/native.height)
        photo.size=CGSize(width:native.width*scale,height:native.height*scale)
        photo.position=CGPoint(x:canvas.size.width/2,y:512)
        update(time:lastTime)
    }
    func update(time:Double) {
        guard time.isFinite else {return};lastTime=max(0,time)
        if let movie=oceanMovie {
            motionDome.isHidden=true
            if let contents=movie.content(at:lastTime) {
                panoramaMaterial?.diffuse.contents=contents
                dome.geometry?.firstMaterial?.diffuse.contents=contents
            }
            return
        }
        updateEnvironmentalLight()
        if !overviewActive {animateSphere()}
        let width=canvas.size.width,phase=Double(seed%997)/997
        for (i,cloud) in clouds.enumerated() {
            let period=240.0+Double(i)*60
            let progress=(lastTime/period+Double(i)/3+phase).truncatingRemainder(dividingBy:1)
            let cloudWidth=CGFloat(760+i*60),span=width+cloudWidth
            cloud.size=CGSize(width:cloudWidth,height:330)
            let altitude:CGFloat = i==2 && environment != .sunset ? 420 : CGFloat(740+i*55)
            cloud.position=CGPoint(x:-cloudWidth/2+span*progress,y:altitude)
            cloud.alpha=CGFloat(sin(progress*Double.pi)*sin(progress*Double.pi))*(environment == .mist ? 0.22 : 0.17)
        }
        if environment == .space {
            // One short meteor every 14–23 seconds, away from the central sculpture.
            let interval=14+Double(seed%10),cycle=floor(lastTime/interval)
            let age=lastTime-cycle*interval
            let delay=3+Double((seed &+ UInt64(cycle))%6)
            let t=(age-delay)/0.85
            if t>=0 && t<=1 {
                let x=width*(0.3+0.4*Double((seed &+ UInt64(cycle))%11)/10)+CGFloat(t)*width*0.27
                let y=930-CGFloat(t)*180
                let path=CGMutablePath();path.move(to:CGPoint(x:x-65,y:y+32));path.addLine(to:CGPoint(x:x,y:y));meteor.path=path
                meteor.alpha=CGFloat(sin(t*Double.pi))*0.8
            } else {meteor.alpha=0}
        }
    }
}
