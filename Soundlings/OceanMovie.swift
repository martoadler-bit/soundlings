import Foundation
import AVFoundation
import CoreGraphics
import ImageIO
import VideoToolbox

// The bundled pilot has exactly 330 silent frames. Explicit frame indices keep
// offline exports independent of AVPlayer's wall clock, including split screen.
enum OceanLoop {
    static let fps=30.0,frames=330
    static var duration:Double {Double(frames)/fps}
    static func frame(at seconds:Double)->Int {
        guard seconds.isFinite else {return 0}
        let time=max(0,seconds).truncatingRemainder(dividingBy:duration)
        return min(frames-1,Int(floor(time*fps+0.000001)))
    }
}
final class OceanMovie {
    let player=AVQueuePlayer()
    private let asset:AVURLAsset
    private var looper:AVPlayerLooper?
    private var track:AVAssetTrack?
    private var reader:AVAssetReader?
    private var output:AVAssetReaderTrackOutput?
    private var decodedFrame = -1
    private var decodedImage:CGImage?
    private(set) var failure:String?
    private(set) var offline=false
    let poster:CGImage?
    init(url:URL,poster:CGImage?) {
        asset=AVURLAsset(url:url);self.poster=poster
        player.isMuted=true;player.volume=0
        let item=AVPlayerItem(asset:asset)
        looper=AVPlayerLooper(player:player,templateItem:item)
        player.play()
    }
    deinit {player.pause();looper?.disableLooping();reader?.cancelReading()}
    static func resource(_ name:String,extension ext:String)->URL? {
        #if canImport(UIKit)
        return Bundle.main.url(forResource:name,withExtension:ext,subdirectory:"EnvironmentVideos") ?? Bundle.main.url(forResource:name,withExtension:ext)
        #else
        let file=URL(fileURLWithPath:#filePath).deletingLastPathComponent().appendingPathComponent("EnvironmentVideos/"+name+"."+ext)
        return FileManager.default.fileExists(atPath:file.path) ? file : nil
        #endif
    }
    static func bundled()->OceanMovie? {
        guard let url=resource("Ocean360",extension:"mp4") else {return nil}
        var poster:CGImage?
        if let file=resource("Ocean360-poster",extension:"png"),let source=CGImageSourceCreateWithURL(file as CFURL,nil) {poster=CGImageSourceCreateImageAtIndex(source,0,nil)}
        return OceanMovie(url:url,poster:poster)
    }
    func prepareForExport() async throws {
        player.pause();looper?.disableLooping();looper=nil;player.removeAllItems()
        offline=true;failure=nil
        let tracks=try await asset.loadTracks(withMediaType:.video)
        guard let video=tracks.first else {throw MovieDecodeError.invalid}
        let size=try await video.load(.naturalSize)
        let duration=try await asset.load(.duration)
        guard abs(size.width/size.height-2)<0.001,abs(duration.seconds-OceanLoop.duration)<1.0/OceanLoop.fps else {throw MovieDecodeError.invalid}
        track=video
        try resetReader()
    }
    private func resetReader() throws {
        guard let track else {throw MovieDecodeError.invalid}
        reader?.cancelReading()
        let newReader=try AVAssetReader(asset:asset)
        let newOutput=AVAssetReaderTrackOutput(track:track,outputSettings:[kCVPixelBufferPixelFormatTypeKey as String:kCVPixelFormatType_32BGRA])
        newOutput.alwaysCopiesSampleData=false
        guard newReader.canAdd(newOutput) else {throw MovieDecodeError.invalid}
        newReader.add(newOutput)
        guard newReader.startReading() else {throw newReader.error ?? MovieDecodeError.invalid}
        reader=newReader;output=newOutput;decodedFrame = -1;decodedImage=nil
    }
    func content(at seconds:Double)->Any? {
        guard offline else {
            if player.currentItem?.status == .readyToPlay {return player}
            return poster
        }
        let target=OceanLoop.frame(at:seconds)
        do {
            if target<decodedFrame {try resetReader()}
            while decodedFrame<target {
                guard let sample=output?.copyNextSampleBuffer(),let buffer=CMSampleBufferGetImageBuffer(sample) else {throw reader?.error ?? MovieDecodeError.invalid}
                decodedFrame+=1
                if decodedFrame==target {
                    var image:CGImage?
                    guard VTCreateCGImageFromCVPixelBuffer(buffer,options:nil,imageOut:&image)==noErr,let image else {throw MovieDecodeError.invalid}
                    decodedImage=image
                }
            }
            return decodedImage
        } catch {failure=error.localizedDescription;return nil}
    }
}
enum MovieDecodeError:LocalizedError {
    case invalid
    var errorDescription:String? {"The ocean panorama video could not be decoded."}
}
