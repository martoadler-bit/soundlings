import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

@main struct SoundlingsApp:App {
    var body:some Scene { WindowGroup { ContentView() } }
}
struct ContentView:View {
    @StateObject private var game=Game()
    @Environment(\.scenePhase) private var scenePhase
    private let ivory=Color(red:0.97,green:0.91,blue:0.83)
    var body:some View {
        ZStack {
            GeometryReader { viewport in
                TimelineView(.animation(minimumInterval:game.playing ? 1/60.0 : 1/30.0)) {context in
                    GardenView(game:game,beat:game.audio.beat,atmosphereTime:context.date.timeIntervalSinceReferenceDate-game.atmosphereStart)
                        .frame(width:viewport.size.width,height:viewport.size.height)
                }
            }
            .ignoresSafeArea()
            if game.world.tiles.isEmpty && game.panel==nil && !game.building {
                VStack(spacing:14) {
                    Image(systemName:"square.stack.3d.up").font(.largeTitle)
                    Text("Your world starts here").font(.title3)
                    Button("Add First Platform",action:game.addFirstPlatform).buttonStyle(.borderedProminent)
                }.padding(24).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:24))
            }
            if !game.fullScreen {
            VStack(spacing:0) {
                if game.building {BuilderHeader(game:game)} else {header}
                Spacer(minLength:0)
                HStack(alignment:.bottom) {
                    VStack(spacing:8) {
                        cameraButton("plus.magnifyingglass","Zoom in") { game.zoom=min(3.2,game.zoom*1.2) }
                        cameraButton("minus.magnifyingglass","Zoom out") { game.zoom=max(0.65,game.zoom/1.2) }
                        cameraButton("viewfinder","Fit world",action:game.home)
                        cameraButton(game.frontView ? "cube" : "rectangle.portrait",game.frontView ? "Use isometric view" : "Use aligned front view",action:game.toggleFrontView)
                        Menu {
                            ForEach(WorldEnvironment.allCases,id:\.self) {environment in
                                Button {game.setEnvironment(environment)} label: {
                                    Label(environment == .sunset ? "Sea · 360° video" : environment.title,systemImage:game.world.environment == environment ? "checkmark" : environment.symbol)
                                }
                            }
                        } label: {
                            Image(systemName:game.world.environment.symbol).font(.system(size:18))
                                .frame(width:44,height:44).background(.ultraThinMaterial,in:Circle())
                        }.accessibilityLabel("Change backdrop").accessibilityValue(game.world.environment.title)
                        if !game.building {
                        cameraButton(game.follow ? "figure.walk.circle.fill" : "figure.walk.circle","Follow character") { game.follow.toggle();game.firstPerson=false;game.pan = .zero }.disabled(game.availableVoices.isEmpty || game.world.tiles.isEmpty)
                        if game.follow && !game.world.tiles.isEmpty {
                            HStack(spacing:0) {
                                Button {game.switchCharacter(-1)} label: {Image(systemName:"chevron.left").frame(width:44,height:44)}.accessibilityLabel("Previous character")
                                Text(game.world.voices[game.cameraVoice].role.creature).font(.caption).frame(minWidth:44)
                                Button {game.switchCharacter(1)} label: {Image(systemName:"chevron.right").frame(width:44,height:44)}.accessibilityLabel("Next character")
                            }.background(.ultraThinMaterial,in:Capsule())
                            Button {game.firstPerson.toggle();game.lookYaw=0} label: {
                                Label(game.firstPerson ? "Follow view" : "First person",systemImage:game.firstPerson ? "figure.walk" : "eye.fill").font(.caption).padding(12).background(.ultraThinMaterial,in:Capsule())
                            }
                        }
                        }
                    }
                    Spacer()
                    if !game.building {
                    Button { game.fullScreen=true; if !game.playing && !game.preparing {game.playPause()} } label: {
                        Image(systemName:"arrow.up.left.and.arrow.down.right")
                            .frame(width:44,height:44).background(.ultraThinMaterial,in:Circle())
                    }.accessibilityLabel("Full screen. Tap the world to return").disabled(game.world.tiles.isEmpty || game.exporting)
                    }
                }.padding(.horizontal,16).padding(.bottom,12)
                if game.building {BuilderTray(game:game)} else {transport}
            }
            }
        }
        .statusBarHidden(game.fullScreen)
        .persistentSystemOverlays(game.fullScreen ? .hidden : .automatic)
        .foregroundStyle(ivory).tint(ivory).preferredColorScheme(.dark)
        .fullScreenCover(item:$game.buildTutorial,onDismiss:{game.finishBuildTutorial(resume:scenePhase == .active)}) {session in
            BuildTutorialView(world:session.world) {game.buildTutorial=nil}
        }
        .sheet(item:$game.panel) { panel in
            NavigationStack {
                Group {
                    switch panel {
                    case .editor: EditorPanel(game:game)
                    case .mixer: MixerPanel(game:game)
                    case .help: HelpPanel()
                    }
                }
                .navigationTitle(panel == .editor ? "World Builder" : panel == .mixer ? "Music & Voices" : "Welcome to Soundlings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement:.confirmationAction) { Button("Done") { game.panel=nil } } }
            }
            .presentationDetents([.height(360),.large])
            .presentationDragIndicator(.visible)
            .presentationBackgroundInteraction(.enabled(upThrough:.height(360)))
        }
        .sheet(isPresented:$game.showVideoOptions) {VideoOptionsView(game:game)}
        .sheet(item:$game.movie,onDismiss:game.removeMovie) {movie in MovieShare(url:movie.url)}
        .overlay {
            if let progress=game.videoProgress {
                VStack(spacing:16) {
                    Text("Exporting Video").font(.headline)
                    ProgressView(value:progress).frame(width:220)
                    Text("\(Int(progress*100))% · 1080 × 1920").font(.caption)
                    Button("Cancel",action:game.cancelVideo)
                }.padding(28).background(.regularMaterial,in:RoundedRectangle(cornerRadius:24))
            }
        }
        .fileExporter(isPresented:$game.showExporter,document:game.exportDocument,contentType:game.exportType,defaultFilename:game.exportName) { result in
            switch result {
            case .success: game.message="Export saved. Share it from Files."
            case .failure(let error): game.message="Export: \(error.localizedDescription)"
            }
        }
        .fileImporter(isPresented:$game.showImporter,allowedContentTypes:[.json]) { result in
            switch result {
            case .success(let url): game.importWorld(url)
            case .failure(let error): game.message="Import: \(error.localizedDescription)"
            }
        }
        .onChange(of:scenePhase) { _,phase in if phase != .active { game.pause() } }
        .onReceive(NotificationCenter.default.publisher(for:AVAudioSession.interruptionNotification)) { _ in
            game.stop(); game.message="Audio interrupted. Tap Play to restart."
        }
        .onReceive(NotificationCenter.default.publisher(for:AVAudioSession.routeChangeNotification)) { notification in
            guard let raw=notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
                  let reason=AVAudioSession.RouteChangeReason(rawValue:raw),
                  reason == .oldDeviceUnavailable || reason == .newDeviceAvailable || reason == .routeConfigurationChange else { return }
            game.stop(); game.message="Audio output changed. Tap Play to restart."
        }
    }
    var header:some View {
        HStack(alignment:.top,spacing:12) {
            VStack(alignment:.leading,spacing:4) {
                Text("SOUNDLINGS").font(.system(size:23,weight:.light,design:.rounded)).tracking(4)
                Text(game.world.name.uppercased()).font(.system(size:10,weight:.medium)).tracking(1.5)
                Text("\(game.world.keyName) · \(game.world.architecture.title)").font(.caption2).foregroundStyle(.secondary)
            }
            Spacer(minLength:0)
            VStack(spacing:2) {
                Button(action:game.randomize) {VStack(spacing:2) {Image(systemName:"dice.fill").font(.title3);Text("Random").font(.caption2)}.frame(width:48,height:44)}
                    .disabled(game.rendering || game.exporting).accessibilityLabel("Random world")
                Button(action:game.openBuildTutorial) {VStack(spacing:2) {Image(systemName:"square.stack.3d.up").font(.title3);Text("Learn").font(.caption2)}.frame(width:48,height:44)}
                    .disabled(game.rendering || game.exporting || (game.world.tiles.isEmpty && game.world.structures.isEmpty))
                    .accessibilityLabel("Show how this world is built")
                    .accessibilityIdentifier("learn-world-build")
            }
            Menu {
                Button("New Empty World",systemImage:"plus.square",action:game.newEmptyWorld)
                Divider()
                Button("The Hanging Gardens") { game.preset(.garden) }
                Button("The Moon Courtyard") { game.preset(.moon) }
                Divider()
                Button("Save World",systemImage:"square.and.arrow.down",action:game.save)
                Button("Load Saved World",systemImage:"folder",action:game.load)
                Button("Export Video with Audio",systemImage:"video",action:game.exportVideo).disabled(game.exporting || game.world.tiles.isEmpty)
                Button("Export Stereo WAV",systemImage:"waveform",action:game.exportAudio).disabled(game.exporting)
                Button("Export World",systemImage:"square.and.arrow.up",action:game.exportWorld).disabled(game.exporting)
                Button("Import World",systemImage:"square.and.arrow.down") { game.showImporter=true }
                Divider()
                Button("How This World Is Built",systemImage:"square.stack.3d.up",action:game.openBuildTutorial).disabled(game.rendering || game.exporting || (game.world.tiles.isEmpty && game.world.structures.isEmpty))
                Button("How to Play",systemImage:"questionmark.circle") { game.panel = .help }
            } label: { Image(systemName:"ellipsis.circle").font(.title2).frame(width:44,height:44) }
            .accessibilityLabel("Worlds, save and export")
        }.padding(.horizontal,18).padding(.top,10).padding(.bottom,24)
        .background(LinearGradient(colors:[.black.opacity(0.45),.clear],startPoint:.top,endPoint:.bottom))
    }
    func cameraButton(_ image:String,_ label:String,action:@escaping()->Void) -> some View {
        Button(action:action) { Image(systemName:image).font(.system(size:18)).frame(width:44,height:44).background(.ultraThinMaterial,in:Circle()) }
            .accessibilityLabel(label)
    }
    var transport:some View {
        VStack(spacing:10) {
            CharacterStrip(game:game)
            HStack(spacing:12) {
                Button(action:game.playPause) {
                    Label(game.preparing ? "Cancel" : game.playing ? "Pause" : "Play",systemImage:game.preparing ? "hourglass" : game.playing ? "pause.fill" : "play.fill")
                        .frame(minWidth:68)
                }.buttonStyle(.borderedProminent).tint(Color(red:0.28,green:0.57,blue:0.60))
                Button(action:game.stop) { Image(systemName:"stop.fill").frame(width:36,height:40) }.accessibilityLabel("Stop and rewind")
                Spacer(minLength:0)
                Button(action:game.beginBuilding) { Label("Build",systemImage:"square.stack.3d.up") }
                Button { game.panel = .mixer } label: { Image(systemName:"slider.horizontal.3").frame(width:40,height:40) }.accessibilityLabel("Music and voices")
            }
            HStack {
                TimelineView(.animation(minimumInterval:1/15.0,paused:!game.playing)) { _ in
                    Text("BAR \(Int(game.audio.beat)/4%game.world.loopBars+1) / \(game.world.loopBars)").monospacedDigit()
                }
                Spacer()
                Text("\(Int(game.world.tempo)) BPM · \(game.world.voices.filter(\.enabled).count) VOICES")
            }.font(.system(size:10,weight:.medium)).tracking(1)
            Text(game.message).font(.caption2).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading)
                .accessibilityIdentifier("status")
        }
        .padding(16).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:24))
        .padding(.horizontal,12).padding(.bottom,8)
    }
}
struct TileEditorPanel:View {
    @ObservedObject var game:Game
    var tile:Tile { game.world.tiles.indices.contains(game.selected) ? game.world.tiles[game.selected] : Tile(x:0,y:1,z:0,note:60) }
    var body:some View {
        Form {
            if game.world.tiles.isEmpty {
                Section("Start from nothing") {
                    Text("Place the first platform, then extend the route in any direction. Azure will play your melody; add the other voices in Music & Voices.")
                    Button("Add First Platform",systemImage:"plus.square.fill",action:game.addFirstPlatform)
                }
            } else {
            Section {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:6) {
                        ForEach(game.world.tiles.indices,id:\.self) { i in
                            Button("\(i+1)") { game.selected=i }
                                .font(.caption.monospacedDigit()).frame(width:38,height:38)
                                .background(game.selected==i ? Color.teal : Color.white.opacity(0.07),in:RoundedRectangle(cornerRadius:8))
                                .accessibilityLabel("Select pad \(i+1)")
                        }
                    }
                }
                Picker("Mechanism",selection:Binding(get:{tile.kind},set:{kind in game.updateTile { $0.kind=kind } })) {
                    ForEach(PadKind.allCases,id:\.self) { kind in Text(kind.title).tag(kind) }
                }
                Stepper("Pitch \(noteName(tile.note)) · MIDI \(tile.note)",value:Binding(get:{tile.note},set:{pitch in game.updateTile { $0.note=pitch } }),in:48...84)
                if tile.kind == .chord && !game.world.stayInScale {
                    Picker("Chord",selection:Binding(get:{tile.quality},set:{quality in game.updateTile { $0.quality=quality } })) {
                        ForEach(ChordQuality.allCases,id:\.self) { quality in Text(quality.rawValue.capitalized).tag(quality) }
                    }
                }
                if tile.kind == .chord && game.world.stayInScale {
                    Picker("Voicing",selection:Binding(get:{tile.quality == .sus2 ? ChordQuality.sus2 : .major},set:{value in game.updateTile{$0.quality=value}})) {
                        Text("Diatonic triad").tag(ChordQuality.major)
                        Text("Suspended").tag(ChordQuality.sus2)
                    }
                    Text("Major or minor follows the world’s scale or mode automatically.").font(.caption).foregroundStyle(.secondary)
                }
                if tile.kind == .transpose {
                    if game.world.stayInScale {
                        let steps=game.world.scale.nearestDegree(to:tile.shift),count=game.world.scale.intervals.count
                        Stepper("Scale steps · \(steps>=0 ? "+" : "")\(steps)",value:Binding(get:{steps},set:{value in let semitones=game.world.scale.degree(value);game.updateTile{$0.shift=semitones}}),in:-count...count)
                        Text("Moves through the world’s scale, preserving its mode in every voice.").font(.caption).foregroundStyle(.secondary)
                    } else {
                        Stepper("Transpose to \(tile.shift>=0 ? "+" : "")\(tile.shift) semitones",value:Binding(get:{tile.shift},set:{shift in game.updateTile { $0.shift=shift } }),in:-12...12)
                    }
                }
                if tile.kind == .filter {
                    Text("Coral uses the shared harmony; this gate changes its sound, not its individual pitch.").font(.caption).foregroundStyle(.secondary)
                    Stepper("Filter · \(Int(150*pow(80,tile.filterCutoff))) Hz",value:Binding(get:{tile.filterCutoff},set:{value in game.updateTile{$0.filterCutoff=value}}),in:0...1,step:0.05)
                    Text("Coral opens or closes a low-pass filter here. The setting lasts until the next Filter Gate.").font(.caption).foregroundStyle(.secondary)
                    DisclosureGroup("Precise filter setting") {PreciseMusicField(title:"Cutoff (0–1)",value:Binding(get:{tile.filterCutoff},set:{value in game.updateTile{$0.filterCutoff=value}}),range:0...1)}
                }
                if tile.kind == .octave {
                    Stepper("Arpeggio · \(tile.arpOctaves) octaves",value:Binding(get:{tile.arpOctaves},set:{value in game.updateTile{$0.arpOctaves=value}}),in:1...3)
                    Text("Coral expands its chord pattern here. One glowing ring per octave makes the range visible.").font(.caption).foregroundStyle(.secondary)
                }
                Toggle("Pad enabled",isOn:Binding(get:{tile.enabled},set:{enabled in game.updateTile { $0.enabled=enabled } }))
            } header: { Text("Pad \(game.selected+1) · \(tile.kind.title)") }
            Section("Position & direction") {
                BuildPositionEditor(game:game)
                Button("Rotate 90°",systemImage:"rotate.right",action:game.rotateBuildSelection)
                Button("Duplicate",systemImage:"plus.square.on.square",action:game.duplicateBuildSelection)
            }
            Section("Extend the route") {
                Text("A new pad is inserted after the selected one. Long gaps automatically become portal connections.").font(.caption).foregroundStyle(.secondary)
                LazyVGrid(columns:Array(repeating:GridItem(.flexible()),count:3),spacing:12) {
                    buildButton("West",dx:-1,dy:0,dz:0)
                    buildButton("North",dx:0,dy:0,dz:-1)
                    buildButton("Up",dx:0,dy:1,dz:0)
                    buildButton("East",dx:1,dy:0,dz:0)
                    buildButton("South",dx:0,dy:0,dz:1)
                    buildButton("Down",dx:0,dy:-1,dz:0)
                }.buttonStyle(.bordered)
                Button("Delete Pad",role:.destructive,action:game.remove).disabled(game.world.tiles.isEmpty)
            }
            }
            Section {
                HStack {
                    Button("Undo",systemImage:"arrow.uturn.backward",action:game.undo).disabled(game.history.isEmpty)
                    Spacer()
                    Button("Redo",systemImage:"arrow.uturn.forward",action:game.redo).disabled(game.future.isEmpty)
                }
                Button("Save World",systemImage:"square.and.arrow.down",action:game.save)
                Text(game.message).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    func buildButton(_ name:String,dx:Float,dy:Float,dz:Float) -> some View {
        Button(name) { game.insert(dx:dx,dy:dy,dz:dz) }.frame(maxWidth:.infinity)
    }
    func noteName(_ note:Int) -> String { ["C","C♯","D","E♭","E","F","F♯","G","A♭","A","B♭","B"][note%12]+"\(note/12-1)" }
}
struct MixerPanel:View {
    @ObservedObject var game:Game
    @State private var variationCode=""
    func worldBinding<T>(_ key:WritableKeyPath<World,T>)->Binding<T> {
        Binding(get:{game.world[keyPath:key]},set:{value in game.mutate{$0[keyPath:key]=value}})
    }
    var body:some View {
        Form {
            Section("World personality") {
                TextField("World name",text:Binding(get:{game.world.name},set:{value in if !value.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && value.count<=100 {game.mutate{$0.name=value}}}))
                Picker("Backdrop",selection:Binding(get:{game.world.environment},set:{game.setEnvironment($0)})) {
                    ForEach(WorldEnvironment.allCases,id:\.self) {Text($0 == .sunset ? "Sea · 360° video" : $0.title).tag($0)}
                }
                Picker("World style",selection:worldBinding(\.architecture)) {ForEach(Architecture.allCases,id:\.self) {Text($0.title).tag($0)}}
                DisclosureGroup("Musical variation code") {
                    TextField("Variation code",text:$variationCode).textInputAutocapitalization(.characters).autocorrectionDisabled()
                    Button("Apply Code") {
                        if let seed=UInt64(variationCode.trimmingCharacters(in:.whitespacesAndNewlines),radix:36) {game.mutate{$0.seed=seed}}
                        else {game.message="Use a variation code with letters and numbers."}
                    }
                    Text("Copy this code with the musical settings to reproduce the same rhythmic variations. Export World keeps everything together.").font(.caption).foregroundStyle(.secondary)
                }.onAppear {variationCode=game.world.seedCode}
                .onChange(of:game.world.seed) {_,_ in variationCode=game.world.seedCode}
                Button("Random World",systemImage:"dice.fill",action:game.randomize).disabled(game.rendering || game.exporting)
                Picker("Key",selection:worldBinding(\.root)) {
                    ForEach(0..<12) { n in Text(["C","C♯","D","E♭","E","F","F♯","G","A♭","A","B♭","B"][n]).tag(n) }
                }
                Picker("Scale",selection:worldBinding(\.scale)) {
                    ForEach(MusicalScale.allCases,id:\.self) { Text($0.rawValue.capitalized).tag($0) }
                }
                Toggle("Stay in scale / mode",isOn:worldBinding(\.stayInScale))
                Picker("Palette",selection:worldBinding(\.palette)) {
                    ForEach(WorldPalette.allCases,id:\.self) { Text($0.title).tag($0) }
                }
                Picker("Loop",selection:worldBinding(\.loopBars)) { ForEach([4,8,12],id:\.self) { Text("\($0) bars").tag($0) } }
                Picker("Chord changes",selection:worldBinding(\.chordBeats)) { Text("Every bar").tag(4);Text("Every two bars").tag(8) }
                ForEach(0..<4) { index in
                    Picker("Chord \(index+1)",selection:Binding(get:{game.world.progression[index]},set:{value in game.mutate{$0.progression[index]=value}})) {
                        ForEach(0..<7) { Text(["I","II","III","IV","V","VI","VII"][$0]).tag($0) }
                    }
                }
                Stepper("Tempo · \(Int(game.world.tempo)) BPM",value:worldBinding(\.tempo),in:60...160,step:1)
                Stepper("Swing · \(Int(game.world.swing*100))%",value:worldBinding(\.swing),in:0...0.4,step:0.05)
                Stepper("Echo · \(Int(game.world.echo*100))%",value:worldBinding(\.echo),in:0...0.45,step:0.05)
                Toggle("Complete route each loop",isOn:worldBinding(\.routeSynchronized))
                Stepper("Walkway width · \(game.world.walkwayWidth,format:.number.precision(.fractionLength(2)))",value:worldBinding(\.walkwayWidth),in:0.83...2,step:0.1)
                Toggle("Reverse route",isOn:worldBinding(\.reversed))
                DisclosureGroup("Precise music settings") {
                    PreciseMusicField(title:"Tempo (60–160)",value:worldBinding(\.tempo),range:60...160)
                    PreciseMusicField(title:"Swing (0–0.4)",value:worldBinding(\.swing),range:0...0.4)
                    PreciseMusicField(title:"Echo (0–0.45)",value:worldBinding(\.echo),range:0...0.45)
                    PreciseMusicField(title:"Walkway width (0.83–2)",value:worldBinding(\.walkwayWidth),range:0.83...2)
                }
            }
            ForEach(game.world.voices.indices,id:\.self) { i in VoicePanel(game:game,index:i) }
            Section {
                Text("Each creature follows its own musical rhythm. Changes stop playback; tap Play to hear them. Undo and Redo are in Build. Export World keeps the complete arrangement and architecture.").font(.caption)
            }
        }
    }
}
struct VoicePanel:View {
    @ObservedObject var game:Game
    let index:Int
    var voice:Voice { game.world.voices[index] }
    func binding<T>(_ key:WritableKeyPath<Voice,T>)->Binding<T> {
        Binding(get:{game.world.voices[index][keyPath:key]},set:{value in game.mutate{$0.voices[index][keyPath:key]=value}})
    }
    var body:some View {
        Section("\(voice.role.creature) · \(voice.role.title)") {
            Toggle("Enabled",isOn:Binding(get:{voice.enabled},set:{game.setVoiceEnabled(index,$0)})).disabled(game.rendering || game.exporting)
            Text(voice.role.behavior).font(.caption).foregroundStyle(.secondary)
            Picker("Timbre",selection:binding(\.timbre)) { ForEach(voice.role.timbres,id:\.self) { Text($0.title).tag($0) } }
            if voice.role != .drone {
                Picker("Rhythm",selection:binding(\.rhythm)) { ForEach(voice.role.rhythms,id:\.self) { Text($0.title).tag($0) } }
                Stepper("Density · \(Int(voice.density*100))%",value:binding(\.density),in:0...1,step:0.1)
                Stepper("Length · \(Int(voice.gate*100))%",value:binding(\.gate),in:0.15...1.5,step:0.1)
            }
            Stepper("Volume · \(Int(voice.gain*100))%",value:binding(\.gain),in:0...1,step:0.1)
            Stepper("Brightness · \(Int(voice.tone*100))%",value:binding(\.tone),in:0...1,step:0.1)
            Stepper("Pan · \(Int(voice.pan*100))",value:binding(\.pan),in:-1...1,step:0.2)
            if voice.role != .percussion {
            Stepper("Register · \(voice.octave) semitones",value:binding(\.octave),in:-24...24,step:12)
            }
            if [.arpeggio,.bass,.percussion].contains(voice.role) {
            Picker("Pattern",selection:binding(\.pattern)) { Text("A").tag(0);Text("B").tag(1);Text("C").tag(2) }
            }
            Stepper("Start pad · \(voice.offset+1)",value:binding(\.offset),in:0...max(0,game.world.tiles.count-1))
            DisclosureGroup("Precise voice settings") {
                PreciseMusicField(title:"Volume (0–1)",value:binding(\.gain),range:0...1)
                if voice.role != .drone {
                    PreciseMusicField(title:"Density (0–1)",value:binding(\.density),range:0...1)
                    PreciseMusicField(title:"Length (0.15–1.5)",value:binding(\.gate),range:0.15...1.5)
                }
                PreciseMusicField(title:"Brightness (0–1)",value:binding(\.tone),range:0...1)
                PreciseMusicField(title:"Pan (−1–1)",value:binding(\.pan),range:-1...1)
            }
        }
    }
}
struct HelpPanel:View {
    var body:some View {
        List {
            Section("Explore") {
                Label("Pinch or use + / − to zoom.",systemImage:"plus.magnifyingglass")
                Label("Drag with one finger to rotate. Drag with two fingers to move the world.",systemImage:"hand.draw")
                Label("The viewfinder fits the whole world. Follow opens character controls; arrows switch characters, and First person looks through their eyes. Drag to look around in first person.",systemImage:"viewfinder")
            }
            Section("Make music") {
                Text("Azure walks a melody; Gold takes bass strides; Ember plays percussion. Violet hovers safely above its beacon, holding the tonic in a glowing core. Sage flies over architecture, opening its canopy and three lights for sustained chords. Flying characters do not use ground collision maneuvers or portal fades.")
                Text("Coral plays the shared chord progression. Filter Gate opens or closes its low-pass filter; Octave Bloom expands the arpeggio from one to three octaves. These settings remain until another gate changes them. Coral’s lens shows filter openness and its glowing rings show the active octave range. Find both gates in Build → Musical Steps and adjust them in Details.")
                Text("Random prefers continuous stairs and bridges. Silent or disabled steps do not create teleportation when a connected walkway exists. Steep return links may keep one portal; flying characters cross the gaps through the air.")
                Text("Note sets the melody pitch; Drum accents arrivals; Chord adds a melody triad; Transpose changes pitched walking voices; Rest silences arrivals. Pads and bass follow the chord progression. The drone holds the tonic.")
                Text("Harp strings vibrate when plucked, Wind pipes breathe a flute tone, and Wood bars ring like a marimba. Arrivals animate the sounding surface and the creature’s arms. Choose them under Build → Mechanism, or select String, Flute and Clarinet in Music & Voices.")
                Text("Stay in scale / mode keeps every pitched voice and instrument in the world’s mode, including chords, bass fifths and transpose gates. Gates move by scale steps. Turn it off in Music & Voices for chromatic semitone shifts and manual major/minor chords. A new lap resets gates to the original shift.")
            }
            Section("Build & keep") {
                Text("New Empty World opens the builder. Choose a Musical Step or Scenery piece and tap the grid to place it. Empty worlds have no characters: add them from Build → Characters when your path is ready. New steps connect after the selected step; bridges and portals appear automatically. Tap Select to choose existing pieces, or hold a piece briefly and drag it.")
                Text("Placement height chooses the layer for the next piece. Snap on aligns placement to the grid; Free allows any position. Move relocates the selected piece with a tap. Details offers elevation, precise position, size and rotation. Copy, Rotate, Delete and Undo are always in the bottom tray.")
                Text("Random and the builder use the same piece catalogue. Every generated structure can be selected, moved, resized, duplicated and deleted. Listen leaves the builder and plays your creation; Build brings you back. Save and Export World preserve your pieces and music together.")
                Text("When creatures meet, one can jump over the other. Under a low ceiling it turns back instead. The other waits until the maneuver ends; music keeps its own precise clock.")
                Text("Tap a colored pad or open Build. Change its sound, add neighboring pads or delete a step. Use Undo and Redo to experiment.")
                Text("Music & Voices changes tempo, volumes, mutes and travel direction. Editing stops playback to preserve precise timing.")
                Text("Full screen starts playback and hides all controls. Tap the world to return. Share video offers a loop or about 15, 30 or 60 seconds in vertical 1080p with stereo sound. Automatic editing changes cameras every two bars, with walking first person and optional split screen. It works with randomized worlds too. Export Stereo WAV saves a musical loop without video.")
                Text("Backdrop chooses Sky, Space, Underwater, Mist or Sunset without stopping playback. Front provides an aligned camera view. Random changes backdrop, architecture, palette, key, harmony, tempo, rhythms, instruments and creature routes. The menu exports a complete world as JSON to share from Files, imports worlds, or exports the musical loop as stereo WAV. Random and imports can be undone.")
            }
            Section("Ocean video credits") {
                Text("Ocean pilot footage by 2FILMZ Studios. Adapted from a stereoscopic beach time-lapse: one eye extracted, resized, trimmed, silenced and crossfaded into an 11-second loop.")
                Link("Source: Oceanside Beach",destination:URL(string:"https://commons.wikimedia.org/wiki/File:3D_360_4K_Motion_TIme-lapse_-_Oceanside_Beach.webm")!)
                Link("Creative Commons Attribution 3.0",destination:URL(string:"https://creativecommons.org/licenses/by/3.0/")!)
            }
        }.font(.subheadline)
    }
}
