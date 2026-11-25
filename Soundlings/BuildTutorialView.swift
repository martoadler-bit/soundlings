import SwiftUI
import SceneKit

struct BuildTutorialView:View {
    @StateObject private var tutorial:BuildTutorialController
    @State private var autoplay=false
    @State private var exact=false
    let close:()->Void
    init(world:World,close:@escaping()->Void) {
        _tutorial=StateObject(wrappedValue:BuildTutorialController(world));self.close=close
    }
    var body:some View {
        VStack(spacing:0) {
            HStack {
                VStack(alignment:.leading,spacing:3) {
                    Text("HOW IT'S BUILT").font(.caption.weight(.semibold)).tracking(1.5)
                    Text(tutorial.plan.world.name).font(.headline).lineLimit(1)
                }
                Spacer()
                Button("Done",action:close).frame(minHeight:44)
            }.padding(.horizontal,18).padding(.vertical,8)
            GeometryReader {proxy in
                if proxy.size.width>proxy.size.height {
                    HStack(spacing:0) {preview;card.frame(width:max(300,proxy.size.width*0.4))}
                } else {
                    VStack(spacing:0) {preview;card.frame(maxHeight:min(350,proxy.size.height*0.49))}
                }
            }
        }
        .foregroundStyle(.white).tint(.yellow).background(Color(red:0.07,green:0.10,blue:0.15))
        .task(id:autoplay) {
            guard autoplay else {return}
            while !Task.isCancelled && !tutorial.last {
                do {try await Task.sleep(for:.seconds(1.8))} catch {return}
                guard !Task.isCancelled else {return}
                tutorial.advance()
            }
            autoplay=false
        }
        .onDisappear {autoplay=false}
        .onChange(of:tutorial.stepIndex) {_,_ in exact=false}
    }
    var friendlyInstruction:String {
        switch tutorial.step.chapter {
        case .overview:return "Watch the pieces come together. The gold outline shows what to add next."
        case .settings:return "Start with the mood you like. The world keeps its sounds in tune for you."
        case .path:return "Add this step to the path. Use Extend path, or tap beside the last piece to turn."
        case .instruments:return "Give this step a sound. Choose Change sound on the selected piece."
        case .scenery:return "Add this decoration beside the path. Leave room for your friends to pass."
        case .characters:return "Add this friend from the Friends tab. Each one brings a different sound."
        case .finished:return "Press Play and listen. Try changing a piece, then listen again."
        }
    }
    var preview:some View {
        ZStack(alignment:.topTrailing) {
            TutorialViewport(tutorial:tutorial).accessibilityLabel("Construction preview. Gold outlines mark the current piece.")
            Button {tutorial.focused.toggle()} label: {
                Label(tutorial.focused ? "Whole world" : "Zoom to piece",systemImage:"viewfinder")
                    .font(.caption).padding(12).background(.ultraThinMaterial,in:Capsule())
            }.disabled(tutorial.targetNode==nil).padding(12)
        }.frame(maxWidth:.infinity,maxHeight:.infinity)
    }
    var card:some View {
        VStack(alignment:.leading,spacing:10) {
            HStack {
                Menu {
                    ForEach(tutorial.plan.chapters,id:\.self) {chapter in
                        Button {autoplay=false;tutorial.jump(chapter)} label:{Label(chapter.title,systemImage:chapter.symbol)}
                    }
                } label: {Label(tutorial.step.chapter.title,systemImage:tutorial.step.chapter.symbol).font(.caption.weight(.semibold))}
                Spacer()
                Text("\(tutorial.stepIndex+1) / \(tutorial.plan.steps.count)").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            ProgressView(value:Double(tutorial.stepIndex),total:Double(max(1,tutorial.plan.steps.count-1)))
            ScrollView {
                VStack(alignment:.leading,spacing:10) {
                    Text(tutorial.plan.title(tutorial.step)).font(.title3.weight(.semibold)).accessibilityAddTraits(.isHeader)
                    Text(friendlyInstruction).font(.subheadline).fixedSize(horizontal:false,vertical:true)
                    DisclosureGroup("Advanced details",isExpanded:$exact) {
                        ForEach(Array(tutorial.plan.details(tutorial.step).enumerated()),id:\.offset) {_,detail in
                            HStack(alignment:.top) {
                                Text(detail.0).foregroundStyle(.secondary)
                                Spacer(minLength:12)
                                Text(detail.1).multilineTextAlignment(.trailing).textSelection(.enabled)
                            }.font(.caption).padding(.vertical,3)
                        }
                    }.font(.caption)
                }.frame(maxWidth:.infinity,alignment:.leading)
            }
            HStack {
                Button {autoplay=false;tutorial.advance(-1)} label:{Label("Back",systemImage:"chevron.left").frame(minHeight:44)}.disabled(tutorial.stepIndex==0)
                Spacer()
                Button {if tutorial.last {tutorial.setStep(0)};autoplay.toggle()} label: {
                    Label(autoplay ? "Pause" : "Auto",systemImage:autoplay ? "pause.fill" : "play.fill").frame(minHeight:44)
                }.accessibilityLabel(autoplay ? "Pause tutorial" : "Play tutorial automatically")
                Spacer()
                Button {
                    autoplay=false
                    if tutorial.last {tutorial.setStep(0)} else {tutorial.advance()}
                } label:{Label(tutorial.last ? "Replay" : "Next",systemImage:tutorial.last ? "arrow.counterclockwise" : "chevron.right").frame(minHeight:44)}
                .buttonStyle(.borderedProminent).tint(.yellow).foregroundStyle(.black)
            }.font(.subheadline)
        }
        .padding(16).frame(maxWidth:.infinity,maxHeight:.infinity,alignment:.topLeading)
        .background(.regularMaterial)
        .accessibilityIdentifier("build-tutorial-controls")
    }
}
private struct TutorialViewport:UIViewRepresentable {
    @ObservedObject var tutorial:BuildTutorialController
    func makeUIView(context:Context)->WorldViewport {
        let view=WorldViewport(frame:.zero);view.scene=tutorial.garden.scene;view.pointOfView=tutorial.garden.camera
        view.antialiasingMode = .multisampling4X;view.isPlaying=true;view.rendersContinuously=true;view.preferredFramesPerSecond=30
        view.onLayout = { [weak view,weak tutorial] in
            guard let view,let tutorial else {return};tutorial.frame(view.bounds.size)
        }
        return view
    }
    func updateUIView(_ view:WorldViewport,context:Context) {
        SCNTransaction.begin();SCNTransaction.animationDuration=0.25
        tutorial.frame(view.bounds.size)
        SCNTransaction.commit()
    }
}
