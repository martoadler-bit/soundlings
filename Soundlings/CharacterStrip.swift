import SwiftUI

struct CharacterStrip:View {
    @ObservedObject var game:Game
    @AppStorage("soundlings.charactersExpanded") private var expanded=true
    var body:some View {
        VStack(spacing:expanded ? 6 : 0) {
            Button {withAnimation(.snappy(duration:0.18)) {expanded.toggle()}} label: {
                HStack {
                    Label("Characters",systemImage:"person.3.fill")
                    Spacer()
                    Text("\(game.availableVoices.count) on").foregroundStyle(.secondary)
                    Image(systemName:"chevron.down").rotationEffect(.degrees(expanded ? 0 : -90)).font(.caption2)
                }.font(.caption).frame(minHeight:44).contentShape(Rectangle())
            }.buttonStyle(.plain)
            if expanded {cards}
        }
        .accessibilityIdentifier("character-panel")
    }
    var cards:some View {
        HStack(spacing:4) {
            ForEach(game.world.voices.indices,id:\.self) {index in
                let voice=game.world.voices[index]
                let color=Color(uiColor:game.garden.colors[voice.role.index])
                VStack(spacing:0) {
                    Button {game.viewCharacter(index)} label: {
                        VStack(spacing:2) {
                            ZStack(alignment:.topTrailing) {
                                CharacterPortrait(role:voice.role,color:color).frame(width:40,height:48)
                                Image(systemName:game.follow && game.cameraVoice == index ? "video.fill" : "video")
                                    .font(.system(size:10)).foregroundStyle(color)
                            }
                            Text(voice.role.creature).font(.system(size:10,weight:.semibold))
                        }.frame(maxWidth:.infinity,minHeight:68)
                    }
                    .disabled(!voice.enabled)
                    .accessibilityLabel("View \(voice.role.creature)")
                    .accessibilityHint(game.firstPerson ? "Switch first person camera" : "Follow character")
                    .accessibilityIdentifier("character-camera-\(voice.role.rawValue)")
                    Button {game.setVoiceEnabled(index,!voice.enabled)} label: {
                        Image(systemName:voice.enabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .font(.system(size:13)).frame(maxWidth:.infinity,minHeight:44)
                            .foregroundStyle(voice.enabled ? color : .secondary)
                    }
                    .disabled(game.rendering || game.exporting)
                    .accessibilityLabel("\(voice.role.creature) sound")
                    .accessibilityValue(voice.enabled ? "On" : "Off")
                    .accessibilityIdentifier("character-toggle-\(voice.role.rawValue)")
                }
                .buttonStyle(.plain)
                .background(color.opacity(voice.enabled ? 0.12 : 0.025),in:RoundedRectangle(cornerRadius:12))
                .overlay(RoundedRectangle(cornerRadius:12).stroke(color.opacity(game.follow && game.cameraVoice == index ? 1 : 0.3),lineWidth:1))

            }
        }.frame(maxWidth:420)
    }
}

// Small vector portraits share the creatures' colors and identifying costume details.
// They stay sharp at every display scale and need no image downloads or GPU snapshots.
struct CharacterPortrait:View {
    let role:VoiceRole
    let color:Color
    var body:some View {
        Canvas {context,size in
            let sx=size.width/40,sy=size.height/48
            func rect(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat)->CGRect {CGRect(x:x*sx,y:y*sy,width:w*sx,height:h*sy)}
            func oval(_ x:CGFloat,_ y:CGFloat,_ w:CGFloat,_ h:CGFloat,_ fill:Color) {context.fill(Path(ellipseIn:rect(x,y,w,h)),with:.color(fill))}
            func polygon(_ points:[CGPoint],_ fill:Color) {
                var path=Path();path.move(to:CGPoint(x:points[0].x*sx,y:points[0].y*sy))
                for p in points.dropFirst() {path.addLine(to:CGPoint(x:p.x*sx,y:p.y*sy))};path.closeSubpath()
                context.fill(path,with:.color(fill))
            }
            let gold=Color(red:0.72,green:0.52,blue:0.29)
            oval(6,42,28,4,.black.opacity(0.2))
            if role == .drone {
                context.stroke(Path(ellipseIn:rect(6,1,28,10)),with:.color(color.opacity(0.8)),lineWidth:1.6)
            }
            if role == .pad {oval(3,12,34,30,color.opacity(0.2))}
            if role == .bass {context.fill(Path(roundedRect:rect(25,26,10,14),cornerRadius:2),with:.color(gold))}
            oval(11,38,8,7,gold);oval(22,38,8,7,gold)
            polygon([CGPoint(x:14,y:23),CGPoint(x:26,y:23),CGPoint(x:31,y:40),CGPoint(x:9,y:40)],color)
            oval(7,27,7,13,color.opacity(0.85));oval(27,27,7,13,color.opacity(0.85))
            if role == .melody {
                polygon([CGPoint(x:9,y:14),CGPoint(x:10,y:3),CGPoint(x:17,y:11)],color)
                polygon([CGPoint(x:23,y:11),CGPoint(x:30,y:3),CGPoint(x:31,y:14)],color)
            }
            context.fill(Path(ellipseIn:rect(8,8,24,23)),with:.linearGradient(Gradient(colors:[color.opacity(0.75),color]),startPoint:CGPoint(x:9*sx,y:8*sy),endPoint:CGPoint(x:29*sx,y:29*sy)))
            if role == .arpeggio {polygon([CGPoint(x:7,y:12),CGPoint(x:22,y:0),CGPoint(x:33,y:12)],color)}
            oval(13,17,5,6,Color(red:0.98,green:0.96,blue:0.88));oval(23,17,5,6,Color(red:0.98,green:0.96,blue:0.88))
            oval(15,19,2.5,3,.black.opacity(0.85));oval(25,19,2.5,3,.black.opacity(0.85))
            if role == .percussion {
                context.fill(Path(roundedRect:rect(13,33,18,10),cornerRadius:2),with:.color(gold))
                oval(13,31,18,6,Color(red:0.97,green:0.9,blue:0.76))
                context.stroke(Path(CGRect(x:7*sx,y:29*sy,width:2*sx,height:8*sy)),with:.color(gold),lineWidth:1)
                oval(5,27,5,5,gold)
            }
            oval(18,28,4,3,.white.opacity(0.85))
        }
        .accessibilityHidden(true)
    }
}
