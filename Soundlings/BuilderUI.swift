import SwiftUI

struct BuilderHeader:View {
    @ObservedObject var game:Game
    var body:some View {
        HStack {
            VStack(alignment:.leading,spacing:4) {
                Text("WORLD BUILDER").font(.system(size:16,weight:.medium,design:.rounded)).tracking(2)
                Text(game.simpleBuilding ? "Drag · Listen · Share" : "Build a path · Add friends · Press Play").font(.caption).lineLimit(1)
            }
            Spacer()
            Button {game.finishBuilding();game.playPause()} label: {Image(systemName:"play.fill").frame(width:44,height:44)}.disabled(game.world.tiles.isEmpty).accessibilityLabel("Listen to your world")
            Button("Save",action:game.save).font(.subheadline).frame(minHeight:44)
            Button("Done",action:game.finishBuilding).buttonStyle(.borderedProminent).tint(.teal)
        }.padding(.horizontal,18).padding(.top,8).padding(.bottom,12)
        .background(LinearGradient(colors:[.black.opacity(0.55),.clear],startPoint:.top,endPoint:.bottom))
    }
}
struct DetailedBuilderTray:View {
    @ObservedObject var game:Game
    @State private var category=0
    @State private var advanced=false
    var body:some View {
        VStack(spacing:10) {
            HStack(spacing:8) {
                Button(action:game.undo) {Image(systemName:"arrow.uturn.backward").frame(width:44,height:44)}.disabled(game.history.isEmpty).accessibilityLabel("Undo")
                Button(action:game.redo) {Image(systemName:"arrow.uturn.forward").frame(width:44,height:44)}.disabled(game.future.isEmpty).accessibilityLabel("Redo")
                Spacer(minLength:0)
                if advanced {Button {game.snapToGrid.toggle()} label: {Label(game.snapToGrid ? "Snap on" : "Free",systemImage:"square.grid.3x3").font(.caption).frame(minHeight:44)}.accessibilityLabel("Snap placement to grid")}
                if advanced {Button {game.panel = .mixer} label: {Image(systemName:"slider.horizontal.3").frame(width:44,height:44)}.accessibilityLabel("Music and voices")}
                Button {game.panel = .help} label: {Image(systemName:"questionmark.circle").frame(width:44,height:44)}.accessibilityLabel("Builder help")
            }
            Picker("Piece category",selection:$category) {Text("Path & sound").tag(0);Text("Decorate").tag(1);Text("Friends").tag(2)}.pickerStyle(.segmented)
                .onChange(of:category) {_,_ in game.buildTool = .select}
            if category==2 {
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:8) {
                        ForEach(game.world.voices.indices,id:\.self) {index in
                            let voice=game.world.voices[index]
                            Button {game.setVoiceEnabled(index,!voice.enabled)} label: {
                                VStack(spacing:3) {
                                    CharacterPortrait(role:voice.role,color:Color(uiColor:game.garden.colors[index])).frame(width:32,height:38)
                                    Label(voice.role.creature,systemImage:voice.enabled ? "checkmark.circle.fill" : "plus.circle")
                                        .font(.caption2)
                                }.frame(width:86,height:66)
                                    .background(voice.enabled ? Color.teal.opacity(0.5) : Color.white.opacity(0.07),in:RoundedRectangle(cornerRadius:12))
                            }.buttonStyle(.plain).disabled(game.world.tiles.isEmpty || game.rendering || game.exporting)
                            .accessibilityLabel("\(voice.enabled ? "Remove" : "Add") \(voice.role.creature)")
                        }
                    }
                }
                Text(game.world.tiles.isEmpty ? "Build a musical step first, then add characters." : "Add characters when your path is ready. Pieces never add characters.").font(.caption2)
            } else {
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:8) {
                    ForEach(category==0 ? (advanced ? BuildItem.instruments : [.tile(.rest),.tile(.note),.tile(.drum),.tile(.harp),.tile(.wind),.tile(.wood),.tile(.chord)]) : BuildItem.scenery) {item in
                        Button {game.chooseBuildItem(item)} label: {
                            VStack(spacing:6) {Image(systemName:item.symbol).font(.title3);Text(item.title).font(.caption2).lineLimit(1)}
                                .frame(width:80,height:58)
                                .background(game.buildTool == .place && game.buildItem==item ? Color.teal.opacity(0.75) : Color.white.opacity(0.07),in:RoundedRectangle(cornerRadius:12))
                        }.buttonStyle(.plain).accessibilityLabel("Place \(item.title)")
                        .accessibilityIdentifier("build-piece-"+item.id)
                    }
                }
            }
            }
            if category==0 {
                HStack {
                    Button {game.extendBuildPath()} label:{Label(game.world.tiles.isEmpty ? "Start path" : "Extend path",systemImage:"plus.circle.fill")}.buttonStyle(.borderedProminent).tint(.teal)
                    if game.hasBuildSelection && game.selectedStructure==nil {
                        Menu("Change sound") {
                            ForEach(advanced ? BuildItem.instruments : [.tile(.rest),.tile(.note),.tile(.drum),.tile(.harp),.tile(.wind),.tile(.wood),.tile(.chord)]) {item in
                                if case .tile(let kind)=item {Button(item.title) {game.changeBuildSound(kind)}}
                            }
                        }.frame(minHeight:44)
                    }
                }
            }
            if advanced {
            Text(game.buildTool == .place ? "Placing: \(game.buildItem.title)" : "Select a piece to edit").font(.caption.weight(.semibold))
            HStack {
                Text("Placement height").font(.caption)
                Spacer()
                Stepper(value:$game.buildHeight,in:-4...24,step:0.5) {Text(game.buildHeight,format:.number.precision(.fractionLength(0...2))).font(.caption.monospacedDigit()).frame(minWidth:36)}.fixedSize()
            }
            }
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:8) {
                    tool("Select","cursorarrow",active:game.buildTool == .select) {game.buildTool = .select;game.message="Tap a piece to select it. Hold to drag it."}
                    if advanced {tool("Move","arrow.up.and.down.and.arrow.left.and.right",active:game.buildTool == .move) {game.buildTool = .move;game.message="Tap the grid to move the selected piece."}.disabled(!game.hasBuildSelection)
                    tool("Details","slider.horizontal.3") {game.panel = .editor}.disabled(!game.hasBuildSelection)
                    }
                    tool("Copy","plus.square.on.square",action:game.duplicateBuildSelection).disabled(!game.hasBuildSelection)
                    tool("Rotate","rotate.right",action:game.rotateBuildSelection).disabled(!game.hasBuildSelection)
                    tool("Delete","trash",action:game.deleteBuildSelection).disabled(!game.hasBuildSelection)
                }
            }
            Toggle("Advanced",isOn:$advanced).font(.caption).onChange(of:advanced) {_,value in game.simpleBuilding = !value;if !value {game.snapToGrid=true}}
            Text(game.message).font(.caption2).lineLimit(2).frame(maxWidth:.infinity,alignment:.leading).accessibilityIdentifier("builder-hint")
        }.onAppear {advanced = !game.simpleBuilding}.padding(12).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:22)).padding(.horizontal,10).padding(.bottom,6)
    }
    func tool(_ title:String,_ symbol:String,active:Bool=false,action:@escaping()->Void)->some View {
        Button(action:action) {Label(title,systemImage:symbol).font(.caption).padding(.horizontal,12).frame(height:44).background(active ? Color.teal.opacity(0.65) : Color.white.opacity(0.06),in:Capsule())}
    }
}
struct EditorPanel:View {
    @ObservedObject var game:Game
    var body:some View {
        Group {if game.selectedStructure != nil {StructureInspector(game:game)} else {TileEditorPanel(game:game)}}
    }
}
struct BuildPositionEditor:View {
    @ObservedObject var game:Game
    var point:(Float,Float,Float) {
        if let i=game.selectedStructure,game.world.structures.indices.contains(i) {let p=game.world.structures[i];return(p.x,p.y,p.z)}
        if game.world.tiles.indices.contains(game.selected) {let p=game.world.tiles[game.selected];return(p.x,p.y,p.z)}
        return(0,1,0)
    }
    func coordinate(_ axis:Int)->Binding<Float> {
        Binding(get:{axis==0 ? point.0 : axis==1 ? point.1 : point.2},set:{value in
            let p=point
            game.moveBuildSelection(x:axis==0 ? value : p.0,y:axis==1 ? value : p.1,z:axis==2 ? value : p.2,snap:false)
        })
    }
    var body:some View {
        HStack {
            Label("Elevation",systemImage:"square.3.layers.3d")
            Spacer()
            Button {game.raiseBuildSelection(-0.5)} label:{Image(systemName:"minus").frame(width:44,height:44)}.buttonStyle(.borderless).accessibilityLabel("Lower piece")
            Text(point.1,format:.number.precision(.fractionLength(0...2))).font(.caption.monospacedDigit())
            Button {game.raiseBuildSelection(0.5)} label:{Image(systemName:"plus").frame(width:44,height:44)}.buttonStyle(.borderless).accessibilityLabel("Raise piece")
        }
        Button("Move by Tapping the World",systemImage:"hand.tap") {game.buildTool = .move;game.panel=nil;game.message="Tap the grid to move \(game.selectionTitle)."}
        DisclosureGroup("Precise position") {
            ForEach(0..<3,id:\.self) {axis in
                HStack {Text(["Left / Right (X)","Elevation (Y)","Front / Back (Z)"][axis]);Spacer();TextField("Position",value:coordinate(axis),format:.number.precision(.significantDigits(1...9))).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation).frame(width:112).accessibilityLabel(["X position","Y position","Z position"][axis])}
            }
            Text("Free coordinates preserve the exact positions used by Random. These fields do not snap.").font(.caption).foregroundStyle(.secondary)
        }
    }
}
struct StructureInspector:View {
    @ObservedObject var game:Game
    var piece:Structure? {game.selectedStructure.flatMap{game.world.structures.indices.contains($0) ? game.world.structures[$0] : nil}}
    func binding<T>(_ key:WritableKeyPath<Structure,T>,fallback:T)->Binding<T> {Binding(get:{piece?[keyPath:key] ?? fallback},set:{value in game.updateBuildStructure{$0[keyPath:key]=value}})}
    var body:some View {
        Form {
            if let piece {
                Section(piece.kind.title) {
                    Picker("Piece",selection:Binding(get:{piece.kind},set:{kind in
                        var replacement=World.piece(kind,x:piece.x,y:piece.y,z:piece.z)
                        replacement.rotation=piece.rotation;replacement.enabled=piece.enabled
                        game.updateBuildStructure{$0=replacement}
                    })) {ForEach(StructureKind.allCases,id:\.self) {Text($0.title).tag($0)}}
                    Toggle("Visible",isOn:binding(\.enabled,fallback:true))
                    Text("This is the same piece used by Random. Its placement and shape are saved with your world.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Position") {BuildPositionEditor(game:game)}
                Section("Shape") {
                    dimension("Width",key:\.width,value:piece.width)
                    dimension("Height",key:\.height,value:piece.height)
                    dimension("Depth",key:\.depth,value:piece.depth)
                    Stepper("Turn · \(Int(piece.rotation))°",value:binding(\.rotation,fallback:0),in:-360...360,step:15)
                    DisclosureGroup("Precise shape") {
                        field("Width",key:\.width);field("Height",key:\.height);field("Depth",key:\.depth);field("Rotation",key:\.rotation)
                    }
                    if piece.kind == .orbit {Stepper("Globe size · \(piece.detail.formatted(.number.precision(.fractionLength(2))))",value:binding(\.detail,fallback:0.45),in:0.1...1.5,step:0.05)}
                }
                Section {
                    Button("Duplicate",systemImage:"plus.square.on.square",action:game.duplicateBuildSelection)
                    Button("Rotate 90°",systemImage:"rotate.right",action:game.rotateBuildSelection)
                    Button("Delete Piece",role:.destructive,action:game.deleteBuildSelection)
                }
            } else {Text("Select a piece in the world.")}
        }
    }
    func dimension(_ label:String,key:WritableKeyPath<Structure,Float>,value:Float)->some View {Stepper("\(label) · \(value.formatted(.number.precision(.fractionLength(0...2))))",value:binding(key,fallback:1),in:0.02...48,step:0.1)}
    func field(_ label:String,key:WritableKeyPath<Structure,Float>)->some View {HStack {Text(label);Spacer();TextField(label,value:binding(key,fallback:1),format:.number.precision(.significantDigits(1...9))).multilineTextAlignment(.trailing).keyboardType(.numbersAndPunctuation).frame(width:112)}}
}

struct PreciseMusicField:View {
    let title:String
    @Binding var value:Double
    let range:ClosedRange<Double>
    var body:some View {
        HStack {
            Text(title)
            Spacer()
            TextField(title,value:Binding(get:{value},set:{candidate in if candidate.isFinite && range.contains(candidate) {value=candidate}}),format:.number.precision(.significantDigits(1...17)))
                .keyboardType(.numbersAndPunctuation).multilineTextAlignment(.trailing).frame(minWidth:90,maxWidth:170)
        }
    }
}

struct BuilderTray:View {
    @ObservedObject var game:Game
    var body:some View {
        if game.simpleBuilding {
            VStack(spacing:10) {
                HStack {
                    Text("Drag to build · Hold a module to move").font(.subheadline.weight(.semibold))
                    Spacer()
                    Button(action:game.undo) {Image(systemName:"arrow.uturn.backward").frame(width:44,height:44)}.disabled(game.history.isEmpty).accessibilityLabel("Undo module")
                }
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:10) {
                        ForEach(WorldModule.allCases) {module in
                            Button {game.addModule(module)} label: {
                                VStack(spacing:6) {
                                    ModuleThumbnail(module:module).frame(width:96,height:66)
                                    Text(module.title).font(.caption2.weight(.medium)).lineLimit(2)
                                }.frame(width:112,height:104).background(Color.white.opacity(0.08),in:RoundedRectangle(cornerRadius:16))
                            }.buttonStyle(.plain)
                            .draggable(module.dragValue)
                            .accessibilityHint("Drag into the world, or double tap to attach to the path")
                        }
                    }
                }
                HStack {
                    Text(game.message).font(.caption2).lineLimit(2)
                    Spacer()
                    Button {game.exportVideo()} label:{Label("Share video",systemImage:"square.and.arrow.up").font(.caption)}.disabled(game.world.tiles.isEmpty || game.exporting)
                    Menu {
                        Button("Redo",action:game.redo).disabled(game.future.isEmpty)
                        Button("Edit individual pieces") {game.simpleBuilding=false}
                    } label:{Image(systemName:"ellipsis.circle").frame(width:44,height:44)}.accessibilityLabel("More building options")
                }
            }.padding(12).background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:22)).padding(.horizontal,10).padding(.bottom,6)
        } else {DetailedBuilderTray(game:game)}
    }
}
private struct ModuleThumbnail:View {
    let module:WorldModule
    var body:some View {
        Canvas {context,size in
            let points=module.path.map {point in CGPoint(x:Double(point.0-point.2)*12,y:Double(point.0+point.2)*6-Double(point.1)*16)}
            let minX=points.map(\.x).min() ?? 0,maxX=points.map(\.x).max() ?? 0
            let minY=points.map(\.y).min() ?? 0,maxY=points.map(\.y).max() ?? 0
            let scale=min(size.width/(maxX-minX+28),size.height/(maxY-minY+24))
            for p in points {
                let x=(p.x-(minX+maxX)/2)*scale+size.width/2
                let y=(p.y-(minY+maxY)/2)*scale+size.height/2-3
                let w=11*scale,h=5.5*scale,d=7*scale
                var side=Path();side.move(to:CGPoint(x:x-w,y:y));side.addLines([CGPoint(x:x,y:y+h),CGPoint(x:x+w,y:y),CGPoint(x:x+w,y:y+d),CGPoint(x:x,y:y+h+d),CGPoint(x:x-w,y:y+d)]);side.closeSubpath()
                context.fill(side,with:.color(.teal.opacity(0.55)))
                var top=Path();top.move(to:CGPoint(x:x,y:y-h));top.addLines([CGPoint(x:x+w,y:y),CGPoint(x:x,y:y+h),CGPoint(x:x-w,y:y)]);top.closeSubpath()
                context.fill(top,with:.color(module.complex ? Color(red:0.85,green:0.72,blue:0.60) : Color(red:0.57,green:0.82,blue:0.77)))
                context.stroke(top,with:.color(.white.opacity(0.4)),lineWidth:0.6)
            }
        }.overlay(alignment:.topTrailing) {Image(systemName:module.symbol).font(.system(size:15)).foregroundStyle(.yellow)}.accessibilityHidden(true)
    }
}
