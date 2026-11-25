import Foundation

struct RenderedLoop {
    let left: [Float]
    let right: [Float]
    let beatFrames: Double
    let events: [MusicalEvent]
}
enum LoopRenderer {
    static let rate=48_000.0
    static func stems(_ world:World) -> [RenderedLoop] {
        var audible=world
        for i in audible.voices.indices {audible.voices[i].enabled=true}
        let events=audible.events()
        return audible.voices.indices.map { renderVoice(audible,events:events,voiceIndex:$0) }
    }
    static func render(_ world:World) -> RenderedLoop {
        let parts=stems(world)
        var left=[Float](repeating:0,count:parts[0].left.count),right=left
        for v in parts.indices where world.voices[v].enabled {
            for i in left.indices {left[i]+=parts[v].left[i];right[i]+=parts[v].right[i]}
        }
        for i in left.indices {left[i]=tanh(left[i]);right[i]=tanh(right[i])}
        return RenderedLoop(left:left,right:right,beatFrames:parts[0].beatFrames,events:world.events())
    }
    private static func renderVoice(_ world:World,events:[MusicalEvent],voiceIndex:Int) -> RenderedLoop {
        precondition(world.valid)
        let beatFrames=rate*60/world.tempo
        let frames=Int((world.loopBeats*beatFrames).rounded())
        var left=[Float](repeating:0,count:frames), right=left
        for (eventIndex,event) in events.enumerated() where event.voice == voiceIndex {
            let start=Int((event.beat*beatFrames).rounded())
            let voice=world.voices[event.voice], hold=event.duration*60/world.tempo
            let mechanism=world.tiles[event.tile].kind
            let timbre:Timbre = event.hit == .note ? (mechanism == .harp ? .string : mechanism == .wind ? .flute : mechanism == .wood ? .marimba : voice.timbre) : voice.timbre
            let sustained=voice.role == .pad || voice.role == .drone
            let release=sustained ? 1.2 : 0.12
            let duration=event.hit == .drone ? Double(frames)/rate : hold+release
            let notes=event.notes.isEmpty ? [60] : event.notes
            let pan=(voice.pan+1)/2
            var random=WorldRandom(state:world.seed &+ UInt64(eventIndex)*31)
            for note in notes {
                var frequency=440*pow(2,Double(note-69)/12)
                // Whole cycles make the pedal seamless at the loop boundary.
                if event.hit == .drone { frequency=(frequency*duration).rounded()/duration }
                // Noise-excited delay line: a vibrating, lossy string (Karplus–Strong).
                var string=(0..<max(2,Int(rate/frequency-0.5))).map{_ in random.unit()*2-1}
                var cursor=0,filter1=0.0,filter2=0.0
                let filterAlpha=event.filterCutoff.map{1-exp(-2 * Double.pi * $0/rate)}
                for sample in 0..<Int(duration*rate) {
                    let t=Double(sample)/rate, phase=2 * Double.pi * frequency * t
                    let attack=min(1,t/(sustained ? 0.35 : 0.004))
                    let envelope=event.hit == .drone ? 1 : attack*(t<hold ? 1 : max(0,1-(t-hold)/release))
                    let tone=voice.tone, wood=voice.timbre == .woodKit, wave:Double
                    switch event.hit {
                    case .kick: wave=sin(2 * .pi * ((wood ? 85 : 48)*t+3*(1-exp(-t*40))))*exp(-t*(wood ? 32 : 18))
                    case .snare: wave=((random.unit()*2-1)*(0.3+tone*0.5)+sin(phase*(wood ? 1.7 : 1))*0.3)*exp(-t*(wood ? 45 : 25))
                    case .hat: wave=(random.unit()*2-1)*exp(-t*(voice.timbre == .woodKit ? 85 : 50))*(0.2+tone*0.6)
                    case .rim: wave=(sin(phase*4.13)+sin(phase*7.3))*exp(-t*65)*0.4
                    default:
                        switch timbre {
                        case .string:
                            wave=string[cursor]*1.8
                            let next=(cursor+1)%string.count
                            string[cursor]=(string[cursor]+string[next])*0.5*(0.992+tone*0.007)
                            cursor=next
                        case .flute:
                            wave=(sin(phase+0.018*sin(t*31))+0.12*tone*sin(phase*2)+(random.unit()*2-1)*0.035)*min(1,t/0.055)
                        case .clarinet:
                            wave=(sin(phase)+0.42*tone*sin(phase*3)+0.2*sin(phase*5)+0.08*sin(phase*7))*min(1,t/0.04)
                        case .bell: wave=(sin(phase)+0.4*tone*sin(phase*2.756))*exp(-t*3)
                        case .marimba: wave=(sin(phase)+0.3*sin(phase*4))*exp(-t*9)
                        case .reed: wave=(sin(phase)+tone*0.4*sin(phase*3)+0.15*sin(phase*5))*exp(-t*1.8)
                        case .pluck: wave=(sin(phase)+tone*0.5*sin(phase*2)+0.2*sin(phase*3))*exp(-t*10)
                        case .glass: wave=(sin(phase)+0.35*sin(phase*3.99))*exp(-t*4)
                        case .roundBass: wave=(sin(phase)+0.2*tone*sin(phase*2))*exp(-t*1.5)
                        case .acidBass: wave=(sin(phase)+tone*0.5*sin(phase*2)+tone*0.3*sin(phase*3))*exp(-t*3)
                        case .subDrone: wave=sin(phase)+0.18*tone*sin(phase*2)
                        case .bowedDrone: wave=(sin(phase)+0.3*sin(phase*2)+tone*0.2*sin(phase*3))*(0.8+0.2*cos(2 * .pi*t/duration))
                        case .warmPad: wave=(sin(phase)+tone*0.3*sin(phase*2)+0.15*sin(phase*1.003))*0.7
                        case .choir: wave=(sin(phase)+0.25*sin(phase*3)+tone*0.18*sin(phase*5))*(0.8+0.2*sin(t*3))*0.7
                        default: wave=sin(phase)*exp(-t*25)
                        }
                    }
                    let signal:Double
                    if let alpha=filterAlpha {
                        filter1+=alpha*(wave-filter1);filter2+=alpha*(filter1-filter2);signal=filter2
                    } else {signal=wave}
                    let value=Float(signal*envelope*voice.gain*event.velocity*0.19/sqrt(Double(notes.count)))
                    let index=(start+sample)%frames
                    left[index]+=value*Float(sqrt(1-pan))
                    right[index]+=value*Float(sqrt(pan))
                }
            }
        }
        let dryLeft=left, dryRight=right
        for i in left.indices {
            let delay=Int(beatFrames*0.75), source=(i-delay%frames+frames)%frames
            left[i]=left[i]+dryRight[source]*Float(world.echo)
            right[i]=right[i]+dryLeft[source]*Float(world.echo)
        }
        return RenderedLoop(left:left,right:right,beatFrames:beatFrames,events:events)
    }
    static func wav(_ loop:RenderedLoop) -> Data {
        var pcm=Data(capacity:loop.left.count*4)
        func append<T:FixedWidthInteger>(_ value:T,to data:inout Data) {
            var value=value.littleEndian
            withUnsafeBytes(of:&value) { data.append(contentsOf:$0) }
        }
        for i in loop.left.indices {
            append(Int16(max(-1,min(1,loop.left[i]))*32767),to:&pcm)
            append(Int16(max(-1,min(1,loop.right[i]))*32767),to:&pcm)
        }
        var data=Data("RIFF".utf8); append(UInt32(36+pcm.count),to:&data)
        data.append(Data("WAVEfmt ".utf8)); append(UInt32(16),to:&data)
        append(UInt16(1),to:&data); append(UInt16(2),to:&data)
        append(UInt32(rate),to:&data); append(UInt32(rate*4),to:&data)
        append(UInt16(4),to:&data); append(UInt16(16),to:&data)
        data.append(Data("data".utf8)); append(UInt32(pcm.count),to:&data); data.append(pcm)
        return data
    }
}
