import SwiftUI
import SceneKit
import UniformTypeIdentifiers

struct AudioDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.wav,.json] }
    var data: Data
    init(data:Data) { self.data=data }
    init(configuration:ReadConfiguration) throws { data=configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration:WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents:data) }
}
enum Panel:String,Identifiable { case editor,mixer,help; var id:String { rawValue } }
@MainActor final class Game: ObservableObject {
    let atmosphereStart=Date.timeIntervalSinceReferenceDate
    @Published var world=World.load()
    @Published var fullScreen=false
    @Published var buildTutorial:BuildTutorialSession?
    private var resumeAfterTutorial=false
    @Published var playing=false
    @Published var preparing=false
    @Published var rendering=false
    @Published var selected=0
    @Published var building=false
    @Published var selectedStructure:Int?
    @Published var buildItem:BuildItem = .tile(.note)
    @Published var buildTool:BuildTool = .select
    @Published var buildHeight:Float=1
    @Published var simpleBuilding=true
    @Published var snapToGrid=true
    var dragStart:World?
    var dragCandidate:World?

    @Published var panel:Panel?
    @Published var zoom=1.04
    @Published var pan=CGPoint.zero
    @Published var follow=false
    @Published var firstPerson=false
    @Published var frontView=false
    @Published var followedVoice=0
    @Published var lookYaw:Double=0
    @Published var message="Pinch to explore. Play to wake the gardens."
    @Published var history=[World]()
    @Published var future=[World]()
    @Published var exportDocument:AudioDocument?
    @Published var exportType:UTType = .wav
    @Published var exportName="Soundlings-Loop"
    @Published var showImporter=false
    @Published var showExporter=false
    @Published var exporting=false
    @Published var movie:SharedMovie?
    @Published var videoProgress:Double?
    private var movieURL:URL?
    private var videoTask:Task<Void,Never>?
    func cancelVideo() {videoTask?.cancel()}
    @Published var showVideoOptions=false
    @Published var movieDuration:MovieDuration = .medium
    @Published var automaticMovie=true
    @Published var movieSplitScreen=true
    func exportVideo() {guard !exporting,!world.tiles.isEmpty else {return};showVideoOptions=true}
    func renderVideo() {
        guard !exporting,!world.tiles.isEmpty else {return}
        pause();exporting=true;videoProgress=0;message="Rendering movie…"
        let snapshot=world
        let edit=automaticMovie ? MovieEditPlan(world:snapshot,duration:movieDuration,splitScreen:movieSplitScreen) : nil
        let duration=movieDuration
        let camera=VideoCamera(follow:follow,firstPerson:firstPerson,voice:cameraVoice,yaw:lookYaw,rotation:Float(garden.orbitYaw),zoom:zoom,pan:pan,frontView:frontView)
        videoTask=Task {
            do {
                let worker=Task.detached(priority:.userInitiated) {
                    try await VideoExporter.render(world:snapshot,camera:camera,duration:duration,edit:edit) { progress in
                        Task {@MainActor in if self.videoProgress != nil {self.videoProgress=progress}}
                    }
                }
                let url=try await withTaskCancellationHandler(operation:{try await worker.value},onCancel:{worker.cancel()})
                movieURL=url;movie=SharedMovie(url:url);message="Movie ready to share with stereo audio."
            } catch is CancellationError {message="Video export cancelled."}
            catch {message="Video export: \(error.localizedDescription)"}
            videoProgress=nil;exporting=false;videoTask=nil
        }
    }
    func removeMovie() {
        if let movieURL {try? FileManager.default.removeItem(at:movieURL.deletingLastPathComponent())}
        movieURL=nil
        movie=nil
    }
    let audio=MusicEngine()
    lazy var garden=GardenScene(world)
    private var generation=UUID()
    var editing:Bool { building || panel == .editor }
    func playPause() {
        guard !world.tiles.isEmpty else {panel = .editor;message="Add your first platform to begin.";return}
        if playing { pause(); return }
        if preparing { stop(); return }
        if rendering { message="Finishing the previous render. Try Play in a moment."; return }
        if audio.prepared { audio.play(); playing=true; return }
        preparing=true; rendering=true
        message="Waking the gardens…"
        let token=UUID(); generation=token; let snapshot=world
        Task {
            let rendered=await Task.detached(priority:.userInitiated) { LoopRenderer.stems(snapshot) }.value
            rendering=false
            guard generation==token else { return }
            do {
                try audio.prepare(rendered,enabled:world.voices.map(\.enabled)); audio.play(); playing=true; preparing=false
                message="\(world.voices.filter(\.enabled).count) voices · \(world.tiles.count) steps · One living world."
            } catch { preparing=false; message="Audio unavailable: \(error.localizedDescription)" }
        }
    }
    func pause() {
        if preparing { stop(); return }
        audio.pause(); playing=false
    }
    func stop() { generation=UUID(); audio.stop(); playing=false; preparing=false; garden.resetMotion() }
    func checkpoint() {
        history.append(world); if history.count>24 { history.removeFirst() }; future=[]
    }
    func mutate(_ action:(inout World)->Void) {
        if dragStart != nil {endBuildDrag(cancelled:true)}
        var candidate=world;action(&candidate)
        guard candidate.mechanismsClear else {message="Leave room for each rotating mechanism to turn fully.";return}
        checkpoint(); stop(); world=candidate
        selected=max(0,min(selected,world.tiles.count-1)); sanitizeBuilderSelection();garden.rebuild(world)
        message="World changed. Play to hear it."
    }
    func updateTile(_ action:(inout Tile)->Void) { guard world.tiles.indices.contains(selected) else {return};mutate { action(&$0.tiles[selected]) } }
    func undo() {
        if dragStart != nil {endBuildDrag(cancelled:true)}
        guard let previous=history.popLast() else { return }
        let refit=building && ((world.tiles.isEmpty && world.structures.isEmpty) || abs(world.tiles.count-previous.tiles.count)>8 || abs(world.structures.count-previous.structures.count)>8)
        stop(); future.append(world); world=previous; selected=max(0,min(selected,world.tiles.count-1)); sanitizeBuilderSelection();garden.rebuild(world)
        if refit {home()}
    }
    func redo() {
        if dragStart != nil {endBuildDrag(cancelled:true)}
        guard let next=future.popLast() else { return }
        let refit=building && ((world.tiles.isEmpty && world.structures.isEmpty) || abs(world.tiles.count-next.tiles.count)>8 || abs(world.structures.count-next.structures.count)>8)
        stop(); history.append(world); world=next; selected=max(0,min(selected,world.tiles.count-1)); sanitizeBuilderSelection();garden.rebuild(world)
        if refit {home()}
    }
    func insert(dx:Float,dy:Float,dz:Float) {
        var candidate=world
        guard candidate.insert(after:selected,dx:dx,dy:dy,dz:dz) else { message="That space is occupied or outside the building limits."; return }
        mutate { $0=candidate }; selected += world.reversed ? 0 : 1
    }
    func remove() {
        guard !world.tiles.isEmpty else {return}
        mutate { $0.tiles.remove(at:selected) }
    }
    func save() {
        do { try world.save(); message="World saved on this device." }
        catch { message="Could not save: \(error.localizedDescription)" }
    }
    func load() { mutate { $0 = .load() }; home(); message="Saved world loaded. Undo returns to your previous world." }
    func preset(_ source:World) { var world=source;world.repairMechanisms();if building {finishBuilding()};selectedStructure=nil;mutate { $0=world }; home() }
    func openBuildTutorial() {
        guard !rendering,!exporting,buildTutorial==nil,(!world.tiles.isEmpty || !world.structures.isEmpty) else {return}
        resumeAfterTutorial=playing
        pause();panel=nil
        buildTutorial=BuildTutorialSession(world:world)
    }
    func finishBuildTutorial(resume:Bool=true) {
        buildTutorial=nil
        let restart=resumeAfterTutorial && resume && audio.prepared
        resumeAfterTutorial=false
        if restart {audio.play();playing=true}
    }
    func randomize() {
        guard !rendering && !exporting else { return }
        let resume=playing
        preset(.generate(seed:UInt64.random(in:0...UInt64.max)))
        message="New world · \(world.keyName) · Seed \(world.seedCode). Undo keeps your previous world."
        if resume { playPause() }
    }
    func exportWorld() {
        do {
            exportDocument=AudioDocument(data:try world.encoded())
            exportType = .json; exportName="Soundlings-World-"+world.seedCode; showExporter=true
        } catch { message="Could not export world: \(error.localizedDescription)" }
    }
    func importWorld(_ url:URL) {
        let access=url.startAccessingSecurityScopedResource()
        defer { if access { url.stopAccessingSecurityScopedResource() } }
        do {
            let size=try url.resourceValues(forKeys:[.fileSizeKey]).fileSize ?? 0
            guard size<=1_000_000 else { message="World file is too large.";return }
            let data=try Data(contentsOf:url)
            guard data.count<=1_000_000 else { message="World file is too large.";return }
            let imported=try JSONDecoder().decode(World.self,from:data)
            guard imported.valid else { message="This world has unsupported or invalid settings.";return }
            preset(imported);message="Imported \(imported.name). Play to explore."
        } catch { message="Could not open world: \(error.localizedDescription)" }
    }
    func newEmptyWorld() {preset(.blank);simpleBuilding=true;buildItem = .tile(.note);beginBuilding();buildTool = .select;message="Drag a module into the world, or tap one to start."}
    func addFirstPlatform() {
        guard world.tiles.isEmpty else {return}
        mutate {$0.tiles=[Tile(x:0,y:1,z:0,note:60)]};selected=0;home()
    }
    func setVoiceEnabled(_ index:Int,_ enabled:Bool) {
        guard world.voices.indices.contains(index),world.voices[index].enabled != enabled,!rendering,!exporting else {return}
        checkpoint()
        world.voices[index].enabled=enabled
        audio.setVoiceEnabled(index,enabled)
        if !availableVoices.contains(followedVoice) {followedVoice=availableVoices.first ?? 0;lookYaw=0}
        if availableVoices.isEmpty {follow=false;firstPerson=false}
        let name=world.voices[index].role.creature
        message="\(name) \(enabled ? "on" : "off")."
    }
    func viewCharacter(_ index:Int) {
        guard availableVoices.contains(index),!building else {return}
        followedVoice=index;follow=true;lookYaw=0
    }
    var availableVoices:[Int] {world.voices.indices.filter{world.voices[$0].enabled}}
    var cameraVoice:Int {availableVoices.contains(followedVoice) ? followedVoice : (availableVoices.first ?? 0)}
    func switchCharacter(_ direction:Int) {
        let voices=availableVoices
        guard !voices.isEmpty else {return}
        let current=voices.firstIndex(of:cameraVoice) ?? 0
        followedVoice=voices[(current+direction+voices.count)%voices.count];lookYaw=0
    }
    func setEnvironment(_ value:WorldEnvironment) {
        guard world.environment != value,!exporting else {return}
        checkpoint();world.environment=value;garden.applyEnvironment(world)
        message="\(value.title) backdrop."
    }
    func toggleFrontView() {
        frontView.toggle();follow=false;firstPerson=false;lookYaw=0
        garden.orbitYaw=0;garden.sculpture.removeAllActions();garden.sculpture.eulerAngles=SCNVector3Zero
        zoom=1.04;pan = .zero
        message=frontView ? "Front view · aligned, with a shallow viewing angle." : "Isometric view."
    }
    func home() { follow=false;firstPerson=false;lookYaw=0; zoom=1.04; pan = .zero; garden.orbitYaw=0;garden.sculpture.eulerAngles.y=0;if building {garden.lockBuilderCamera(true)} }
    func rotate() {garden.orbitYaw += .pi/2;pan=pan}
    func exportAudio() {
        guard !exporting else { return }
        exporting=true; message="Rendering stereo WAV…"
        let snapshot=world
        Task {
            let data=await Task.detached(priority:.userInitiated) { LoopRenderer.wav(LoopRenderer.render(snapshot)) }.value
            exportType = .wav; exportName="Soundlings-Loop-"+snapshot.seedCode
            exportDocument=AudioDocument(data:data); exporting=false; showExporter=true
            message="One complete loop is ready to export."
        }
    }
}
