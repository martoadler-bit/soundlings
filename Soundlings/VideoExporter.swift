import SwiftUI

import AVFoundation
import SceneKit
import UIKit
import Metal
import CoreText

struct VideoCamera {
    var follow:Bool
    var firstPerson:Bool
    var voice:Int
    var yaw:Double
    var rotation:Float
    var zoom:Double
    var pan:CGPoint
    var frontView=false
}
struct SharedMovie:Identifiable {let id=UUID();let url:URL}
struct MovieShare: UIViewControllerRepresentable {
    let url:URL
    func makeUIViewController(context:Context)->UIActivityViewController {UIActivityViewController(activityItems:[url],applicationActivities:nil)}
    func updateUIViewController(_ controller:UIActivityViewController,context:Context) {}
}
enum MovieError:LocalizedError {
    case unavailable, encoding(String)
    var errorDescription:String? {
        switch self {
        case .unavailable:return "Video rendering is unavailable on this device."
        case .encoding(let reason):return reason
        }
    }
}
// A separate scene renders at fixed timestamps. Audio uses exactly the same beat/sample clock.
// No screen recording permission, UI capture, microphone or real-time timing is involved.
// Only cancellation crosses executors; AVFoundation supports cancelling an in-flight export.
private final class ExportCancellation: @unchecked Sendable {
    let session:AVAssetExportSession
    init(_ session:AVAssetExportSession) {self.session=session}
    func cancel() {session.cancelExport()}
}
enum VideoExporter {
    private static func drawOceanCredit(in context:CGContext,width:Int) {
        context.saveGState()
        context.setFillColor(UIColor.black.withAlphaComponent(0.5).cgColor)
        context.fill(CGRect(x:0,y:0,width:width,height:66))
        let font=CTFontCreateWithName("Helvetica" as CFString,18,nil)
        let lines=["Ocean video: 2FILMZ Studios · CC BY 3.0 · adapted", "creativecommons.org/licenses/by/3.0 · source: vimeo.com/215703486"]
        for (index,text) in lines.enumerated() {
            let string=NSAttributedString(string:text,attributes:[NSAttributedString.Key(kCTFontAttributeName as String):font,NSAttributedString.Key(kCTForegroundColorAttributeName as String):UIColor.white.cgColor])
            context.textMatrix = .identity;context.textPosition=CGPoint(x:22,y:41-index*24)
            CTLineDraw(CTLineCreateWithAttributedString(string),context)
        }
        context.restoreGState()
    }
    static func render(world:World,camera:VideoCamera,duration choice:MovieDuration = .loop,edit:MovieEditPlan?=nil,progress:@escaping @Sendable (Double)->Void) async throws -> URL {
        guard let device=MTLCreateSystemDefaultDevice() else {throw MovieError.unavailable}
        let folder=FileManager.default.temporaryDirectory.appendingPathComponent("Soundlings-"+UUID().uuidString)
        try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
        let silent=folder.appendingPathComponent("frames.mov"), wav=folder.appendingPathComponent("loop.wav")
        let output=folder.appendingPathComponent("Soundlings-"+world.seedCode+".mp4")
        var succeeded=false
        defer {
            if succeeded {try? FileManager.default.removeItem(at:silent);try? FileManager.default.removeItem(at:wav)}
            else {try? FileManager.default.removeItem(at:folder)}
        }
        let audio=LoopRenderer.render(world)
        try Task.checkCancellation()
        try LoopRenderer.wav(audio).write(to:wav)
        let editPlan=edit ?? MovieEditPlan(world:world,duration:choice)
        let sampleCount=Int((editPlan.beats*60/world.tempo*LoopRenderer.rate).rounded())
        let duration=Double(sampleCount)/LoopRenderer.rate
        let fps=30, width=1080, height=1920
        let frameCount=Int(ceil(duration*Double(fps)))
        let writer=try AVAssetWriter(outputURL:silent,fileType:.mov)
        let input=AVAssetWriterInput(mediaType:.video,outputSettings:[AVVideoCodecKey:AVVideoCodecType.h264,AVVideoWidthKey:width,AVVideoHeightKey:height,AVVideoCompressionPropertiesKey:[AVVideoAverageBitRateKey:8_000_000]])
        input.expectsMediaDataInRealTime=false
        let adaptor=AVAssetWriterInputPixelBufferAdaptor(assetWriterInput:input,sourcePixelBufferAttributes:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32ARGB,kCVPixelBufferWidthKey as String:width,kCVPixelBufferHeightKey as String:height,kCVPixelBufferCGImageCompatibilityKey as String:true,kCVPixelBufferCGBitmapContextCompatibilityKey as String:true])
        guard writer.canAdd(input) else {throw MovieError.unavailable}
        writer.add(input)
        guard writer.startWriting() else {throw writer.error ?? MovieError.unavailable}
        writer.startSession(atSourceTime:.zero)
        defer {if writer.status == .writing {writer.cancelWriting()}}
        let garden=GardenScene(world)
        try await garden.atmosphere?.oceanMovie?.prepareForExport()
        garden.orbitYaw=Double(camera.rotation)
        let renderer=SCNRenderer(device:device,options:nil)
        renderer.scene=garden.scene;renderer.pointOfView=garden.camera
        let size=CGSize(width:width,height:height)
        for frame in 0..<frameCount {
            try Task.checkCancellation()
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing else {throw writer.error ?? MovieError.unavailable}
                try await Task.sleep(nanoseconds:5_000_000)
                try Task.checkCancellation()
            }
            // Advance at 60 Hz, matching the live collision solver while encoding at 30 fps.
            SCNTransaction.begin();SCNTransaction.disableActions=true
            var activeCamera=camera
            var overviewTilt=0.0
            var splitVoice:Int?
            var renderSize=size
            for subframe in 0..<2 {
                let time=max(0,(Double(frame)*2+Double(subframe)-1)/60)
                garden.update(world,beat:time*world.tempo/60,selected:nil,playing:true)
                if let failure=garden.atmosphere?.oceanMovie?.failure {throw MovieError.encoding(failure)}
                if let edit {
                    let beat=time*world.tempo/60,shot=edit.shot(at:beat)
                    let t=min(1,max(0,(beat-shot.start)/(shot.end-shot.start)))
                    let ease=t*t*(3-2*t)
                    splitVoice=shot.kind == .split ? shot.voice : nil
                    renderSize=splitVoice == nil ? size : CGSize(width:width,height:height/2)
                    activeCamera=VideoCamera(follow:shot.kind == .follow || shot.kind == .firstPerson,firstPerson:shot.kind == .firstPerson,voice:shot.voice,yaw:0,rotation:0,zoom:shot.kind == .overview ? 0.95+ease*0.18 : 1,pan:.zero)
                    if shot.kind == .overview || shot.kind == .split {
                        let direction=Int(shot.start/8)%2==0 ? 1.0 : -1.0
                        activeCamera.rotation=Float(direction*(-0.22+ease*0.44))
                        overviewTilt = -0.25+ease*0.5
                    }
                }
                garden.orbitYaw=Double(activeCamera.rotation)
                garden.frame(size:renderSize,zoom:activeCamera.zoom,pan:activeCamera.pan,follow:activeCamera.follow,voice:activeCamera.voice,firstPerson:activeCamera.firstPerson,lookYaw:activeCamera.yaw,frontView:activeCamera.frontView,overviewTilt:overviewTilt)
            }
            SCNTransaction.commit()
            try autoreleasepool {
                let image=renderer.snapshot(atTime:Double(frame)/Double(fps),with:renderSize,antialiasingMode:.multisampling4X)
                guard let cg=image.cgImage,let pool=adaptor.pixelBufferPool else {throw MovieError.unavailable}
                var optional:CVPixelBuffer?
                guard CVPixelBufferPoolCreatePixelBuffer(nil,pool,&optional)==kCVReturnSuccess,let pixel=optional else {throw MovieError.unavailable}
                CVPixelBufferLockBaseAddress(pixel,[])
                defer {CVPixelBufferUnlockBaseAddress(pixel,[])}
                guard let context=CGContext(data:CVPixelBufferGetBaseAddress(pixel),width:width,height:height,bitsPerComponent:8,bytesPerRow:CVPixelBufferGetBytesPerRow(pixel),space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.noneSkipFirst.rawValue) else {throw MovieError.unavailable}
                if let voice=splitVoice {
                    // Two cameras share the same simulated instant and the same music sample.
                    let half=CGFloat(height)/2
                    context.draw(cg,in:CGRect(x:0,y:half,width:CGFloat(width),height:half))
                    SCNTransaction.begin();SCNTransaction.disableActions=true
                    garden.frame(size:renderSize,zoom:1,pan:.zero,follow:true,voice:voice)
                    SCNTransaction.commit()
                    let close=renderer.snapshot(atTime:Double(frame)/Double(fps),with:renderSize,antialiasingMode:.multisampling4X)
                    guard let detail=close.cgImage else {throw MovieError.unavailable}
                    context.draw(detail,in:CGRect(x:0,y:0,width:CGFloat(width),height:half))
                    context.setFillColor(UIColor.black.cgColor);context.fill(CGRect(x:0,y:half-2,width:CGFloat(width),height:4))
                } else {context.draw(cg,in:CGRect(origin:.zero,size:size))}
                if activeCamera.firstPerson,garden.walkers.indices.contains(activeCamera.voice) {
                    context.setFillColor(UIColor.black.withAlphaComponent(garden.portalShade(for:activeCamera.voice)).cgColor)
                    context.fill(CGRect(origin:.zero,size:size))
                }
                if garden.atmosphere?.oceanMovie != nil {drawOceanCredit(in:context,width:width)}
                guard adaptor.append(pixel,withPresentationTime:CMTime(value:Int64(frame),timescale:Int32(fps))) else {throw writer.error ?? MovieError.unavailable}
            }
            if frame%10==0 {progress(Double(frame)/Double(frameCount)*0.9)}
        }
        writer.endSession(atSourceTime:CMTime(value:Int64(frameCount),timescale:Int32(fps)))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {throw writer.error ?? MovieError.unavailable}
        try Task.checkCancellation()
        let composition=AVMutableComposition()
        let videoAsset=AVURLAsset(url:silent),audioAsset=AVURLAsset(url:wav)
        let end=CMTime(value:Int64(sampleCount),timescale:Int32(LoopRenderer.rate))
        let range=CMTimeRange(start:.zero,duration:end)
        guard let videoSource=try await videoAsset.loadTracks(withMediaType:.video).first,
              let audioSource=try await audioAsset.loadTracks(withMediaType:.audio).first,
              let videoTrack=composition.addMutableTrack(withMediaType:.video,preferredTrackID:kCMPersistentTrackID_Invalid),
              let audioTrack=composition.addMutableTrack(withMediaType:.audio,preferredTrackID:kCMPersistentTrackID_Invalid) else {throw MovieError.unavailable}
        try videoTrack.insertTimeRange(range,of:videoSource,at:.zero)
        let sourceDuration=CMTime(value:Int64(audio.left.count),timescale:Int32(LoopRenderer.rate))
        var cursor=CMTime.zero
        while CMTimeCompare(cursor,end)<0 {
            try Task.checkCancellation()
            let length=CMTimeMinimum(sourceDuration,CMTimeSubtract(end,cursor))
            try audioTrack.insertTimeRange(CMTimeRange(start:.zero,duration:length),of:audioSource,at:cursor)
            cursor=CMTimeAdd(cursor,length)
        }
        guard let export=AVAssetExportSession(asset:composition,presetName:AVAssetExportPresetHighestQuality) else {throw MovieError.unavailable}
        export.outputURL=output;export.outputFileType = .mp4;export.shouldOptimizeForNetworkUse=true
        let cancellation=ExportCancellation(export)
        await withTaskCancellationHandler(operation:{await export.export()},onCancel:{cancellation.cancel()})
        try Task.checkCancellation()
        guard export.status == .completed else {throw export.error ?? MovieError.encoding("Could not finish the movie.")}
        progress(1);succeeded=true
        return output
    }
}

struct VideoOptionsView:View {
    @ObservedObject var game:Game
    var body:some View {
        NavigationStack {
            Form {
                Section("Duration") {
                    ChipPicker("Length",selection:$game.movieDuration,options:MovieDuration.allCases) {$0.title}
                    let plan=MovieEditPlan(world:game.world,duration:game.movieDuration)
                    Text("\(Int((plan.beats*60/game.world.tempo).rounded())) seconds · finishes with the music.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Camera") {
                    Toggle("Automatic music edit",isOn:$game.automaticMovie)
                    if game.automaticMovie {Toggle("Split-screen moments",isOn:$game.movieSplitScreen)}
                    Text(game.automaticMovie ? "Wide shots, character views and walking first person. Smooth movement and camera changes with the music." : "Use your current camera for the whole video.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    Button("Create video",systemImage:"video.fill") {game.showVideoOptions=false;game.renderVideo()}
                        .disabled(game.exporting || game.world.tiles.isEmpty)
                    Text("1080 × 1920 vertical video with stereo audio, ready to share. Works with built and randomized worlds.").font(.caption).foregroundStyle(.secondary)
                }
            }.navigationTitle("Share your world").navigationBarTitleDisplayMode(.inline)
                .toolbar {ToolbarItem(placement:.cancellationAction) {Button("Cancel") {game.showVideoOptions=false}}}
        }.presentationDetents([.medium,.large])
    }
}
