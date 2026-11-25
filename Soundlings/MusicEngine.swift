import AVFoundation
import os

// All stems share one sample cursor. UI changes only targets; the render thread
// ramps gains over 8 ms without rescheduling audio or resetting the transport.
final class MusicEngine {
    private struct Controls {var running=false;var enabled=[Bool]();var sample=0}
    private let controls=OSAllocatedUnfairLock(initialState:Controls())
    let engine=AVAudioEngine()
    private var source:AVAudioSourceNode?
    private let rate=48_000.0
    private var frames=1
    private var beatFrames=1.0
    private(set) var prepared=false

    func prepare(_ stems:[RenderedLoop],enabled:[Bool]) throws {
        stop()
        let session=AVAudioSession.sharedInstance()
        try session.setCategory(.playback,mode:.default)
        try session.setPreferredIOBufferDuration(0.005)
        try session.setActive(true)
        if let source {engine.disconnectNodeOutput(source);engine.detach(source)}
        frames=stems[0].left.count;beatFrames=stems[0].beatFrames
        controls.withLock {$0=Controls(enabled:enabled)}
        let controls=self.controls,frames=self.frames
        var cursor=0
        var renderedSamples=0
        var gains=enabled.map {Float($0 ? 1 : 0)}
        let node=AVAudioSourceNode(format:AVAudioFormat(standardFormatWithSampleRate:rate,channels:2)!) { _,_,count,list in
            let state=controls.withLock {($0.running,$0.enabled)}
            let buffers=UnsafeMutableAudioBufferListPointer(list)
            let left=buffers[0].mData!.assumingMemoryBound(to:Float.self)
            let right=buffers[1].mData!.assumingMemoryBound(to:Float.self)
            for i in 0..<Int(count) {
                var l:Float=0,r:Float=0
                if state.0 {
                    for v in stems.indices {
                        let target:Float=state.1[v] ? 1 : 0
                        gains[v]+=max(-1/384,min(1/384,target-gains[v]))
                        l+=stems[v].left[cursor]*gains[v];r+=stems[v].right[cursor]*gains[v]
                    }
                    cursor=(cursor+1)%frames
                    renderedSamples+=1
                }
                left[i]=tanh(l);right[i]=tanh(r)
            }
            let renderedCursor=renderedSamples
            controls.withLock {$0.sample=renderedCursor}
            return noErr
        }
        source=node;engine.attach(node)
        engine.connect(node,to:engine.mainMixerNode,format:AVAudioFormat(standardFormatWithSampleRate:rate,channels:2)!)
        if !engine.isRunning {try engine.start()}
        prepared=true
    }
    func setVoiceEnabled(_ index:Int,_ enabled:Bool) {
        controls.withLock {if $0.enabled.indices.contains(index) {$0.enabled[index]=enabled}}
    }
    func play() {controls.withLock {$0.running=true}}
    func pause() {controls.withLock {$0.running=false}}
    func stop() {controls.withLock {$0.running=false;$0.sample=0};prepared=false}
    var beat:Double {
        let sample=controls.withLock {$0.sample}
        let latency=AVAudioSession.sharedInstance().outputLatency*rate
        return max(0,Double(sample)-latency).truncatingRemainder(dividingBy:Double(frames))/beatFrames
    }
}
