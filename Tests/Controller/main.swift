import Foundation
import SceneKit
var checks=0
func check(_ condition:@autoclosure()->Bool,_ message:String) {guard condition() else {fatalError(message)};checks+=1}
MainActor.assumeIsolated {
    let game=Game();game.world = .blank
    game.beginBuilding()
    check(game.building && game.panel==nil,"Builder is directly on the world, without a blocking sheet")
    game.chooseBuildItem(.tile(.harp));game.placeBuildItem(x:0.2,z:0.4)
    check(game.world.tiles.count==1 && game.world.tiles[0].kind == .harp && game.world.tiles[0].x==0,"Tap placement uses the shared musical catalogue and grid")
    check(game.history.count==1,"One placement is one undo")
    game.undo();check(game.world.tiles.isEmpty,"Undo removes first platform without hidden scenery")
    game.redo();check(game.world.tiles.count==1,"Redo restores it")
    game.chooseBuildItem(.structure(.gear));game.placeBuildItem(x:3,z:0)
    check(game.world.structures.count==1 && game.selectedStructure==0,"Place selects the new architecture")
    let selected=game.world.structures[0]
    game.rotateBuildSelection();check(game.world.structures[0].rotation==90,"Structure rotation editable")
    game.undo();check(game.world.structures[0]==selected,"Undo restores exact piece settings")
    game.selectBuildStructure(0);game.snapToGrid=false
    game.moveBuildSelection(x:3.123456,y:2.345678,z:-1.234567,snap:false)
    check(game.world.structures[0].x==3.123456 && game.world.structures[0].y==2.345678,"Inspector supports procedural precision")
    let source=game.world.structures[0],history=game.history.count
    game.snapToGrid=true;game.beginBuildDrag()
    game.moveBuildSelection(x:source.x+0.05,y:source.y,z:source.z,continuous:true)
    check(abs(Float(game.garden.buildPreview!.position.x)-source.x)<0.00001,"Dragging does not jump a fractional starting anchor onto the grid")
    game.moveBuildSelection(x:source.x+1.1,y:source.y,z:source.z,continuous:true)
    game.moveBuildSelection(x:source.x+2.1,y:source.y,z:source.z,continuous:true)
    check(game.world.structures[0]==source && game.history.count==history,"Dragging previews without rebuilding or modifying the saved world")
    game.endBuildDrag(cancelled:false)
    check(abs(game.world.structures[0].x-source.x-2)<0.00001 && game.history.count==history+1,"A whole drag commits as exactly one undo")
    check(game.garden.buildPreview==nil,"Committed drag clears its preview")
    game.undo();check(game.world.structures[0]==source,"Undo returns the entire drag")
    game.selectBuildStructure(0);game.beginBuildDrag()
    game.moveBuildSelection(x:8,y:source.y,z:0,continuous:true)
    let cancelCount=game.history.count
    game.endBuildDrag(cancelled:true)
    check(game.world.structures[0]==source && game.history.count==cancelCount,"Cancelled gesture preserves world and history")
    game.duplicateBuildSelection();check(game.world.structures.count==2,"Copy uses the same structure records")
    game.deleteBuildSelection();check(game.world.structures.count==1,"Delete removes only the selected piece")
    game.undo();check(game.world.structures.count==2,"Deleted architecture is recoverable")
    game.selectBuildTile(0);game.rotateBuildSelection()
    check(game.world.tiles[0].rotation==90 && game.garden.tileNodes.count==1,"Musical surfaces rotate and remain selectable")
    let encoded=try! game.world.encoded()
    let decoded=try! JSONDecoder().decode(World.self,from:encoded)
    check(try! decoded.encoded()==encoded,"Edited world export/import preserves every manual piece")
    let construction=Game();construction.world = .blank;construction.garden.rebuild(construction.world)
    construction.beginBuilding()
    construction.chooseBuildItem(.structure(.orbit));construction.placeBuildItem(x:0,z:0)
    check(construction.world.structures.map(\.kind)==[.orbit] && construction.world.tiles.isEmpty,"Orbit places exactly the chosen structure, without musical steps")
    check(construction.availableVoices.isEmpty && construction.garden.walkers.isEmpty,"Orbit cannot add a character")
    construction.chooseBuildItem(.tile(.note));construction.placeBuildItem(x:3,z:0)
    check(construction.availableVoices.isEmpty && construction.garden.walkers.allSatisfy(\.isHidden),"First step never creates an enabled character")
    construction.setVoiceEnabled(0,true)
    check(construction.availableVoices==[0] && construction.world.structures.count==1,"Characters are explicitly added after construction")
    let easy=Game();easy.world = .blank;easy.beginBuilding();easy.chooseBuildItem(.tile(.harp))
    easy.extendBuildPath();easy.extendBuildPath()
    check(easy.world.tiles.count==2,"Quick build starts and extends without coordinates")
    check(easy.world.tiles[0].y==easy.world.tiles[1].y,"Quick extension inherits path height")
    easy.placeBuildItem(x:easy.world.tiles[1].x,z:10)
    check(easy.world.tiles.count==3 && easy.world.tiles[2].x==easy.world.tiles[1].x,"Tap direction turns the path instead of leaving a distant island")
    check(easy.world.voices.allSatisfy{!$0.enabled},"Easy building still leaves characters to the user")
    easy.changeBuildSound(.wind)
    check(easy.world.tiles[2].kind == .wind && easy.history.count==4,"Changing sound is a single undoable action")
    easy.undo();check(easy.world.tiles[2].kind == .harp,"Undo restores the previous sound")
    for module in WorldModule.allCases {
        check(WorldModule(dragValue:module.dragValue)==module,"Drag payload round trips")
        let modular=Game();modular.world = .blank;modular.beginBuilding()
        modular.addModule(module,x:0,z:0)
        check(modular.world.tiles.count==module.path.count && modular.world.structures.count==(module.complex ? 3 : 1),"Module creates its complete musical structure")
        check(modular.world.voices[module.voice].enabled && modular.world.stayInScale,"Module activates its musical role in scale")
        check(modular.history.count==1,"A module is exactly one undo")
        modular.addModule(module)
        check(modular.world.tiles.count==module.path.count*2,"Modules attach to the existing path")
        modular.undo();check(modular.world.tiles.count==module.path.count,"Undo removes the whole module")
        modular.undo();check(modular.world.tiles.isEmpty && modular.availableVoices.isEmpty,"Undo restores empty world including characters")
    }
    let grouped=Game();grouped.world = .blank;grouped.beginBuilding();grouped.addModule(.courtyard)
    let beforeMove=grouped.world
    grouped.selectBuildTile(2);let anchor=grouped.buildSelectionPoint
    grouped.beginBuildDrag()
    check(grouped.garden.previewSources.count>15,"Drag previews every path, decoration and internal bridge in a complex module")
    grouped.moveBuildSelection(x:anchor.0,y:anchor.1,z:anchor.2+8,continuous:true)
    check(grouped.world.tiles[0].z==beforeMove.tiles[0].z,"Module drag stays a preview until release")
    grouped.endBuildDrag(cancelled:false)
    for i in grouped.world.tiles.indices {check(abs(grouped.world.tiles[i].z-beforeMove.tiles[i].z-8)<0.001,"Every module step shares the drag offset")}
    for i in grouped.world.structures.indices {check(abs(grouped.world.structures[i].z-beforeMove.structures[i].z-8)<0.001,"Every decoration shares the drag offset")}
    check(grouped.history.count==2,"Module movement creates one undo")
    let savedGroup=try! JSONDecoder().decode(World.self,from:grouped.world.encoded())
    check(Set(savedGroup.tiles.compactMap(\.moduleID)).count==1 && savedGroup.structures.allSatisfy{$0.moduleID==savedGroup.tiles[0].moduleID},"Grouping survives export and import")
    grouped.undo();check(try! grouped.world.encoded()==beforeMove.encoded(),"Undo restores the entire module")
    grouped.selectBuildStructure(0);grouped.beginBuildDrag();let p=grouped.buildSelectionPoint
    grouped.moveBuildSelection(x:p.0+3,y:p.1,z:p.2,continuous:true);grouped.endBuildDrag(cancelled:true)
    check(try! grouped.world.encoded()==beforeMove.encoded(),"Cancellation restores the whole module from a decoration drag")
    let legacy=Game();legacy.world = .blank;legacy.beginBuilding();legacy.addModule(.strings)
    for i in legacy.world.tiles.indices {legacy.world.tiles[i].moduleID=nil}
    for i in legacy.world.structures.indices {legacy.world.structures[i].moduleID=nil}
    legacy.beginBuilding()
    check(legacy.world.tiles.allSatisfy{$0.moduleID==legacy.world.structures[0].moduleID && $0.moduleID != nil},"Earlier six-piece modules regain their grouping")
    let blocker=Game();blocker.world = .blank;blocker.beginBuilding();blocker.addModule(.strings);blocker.addModule(.strings)
    blocker.selectBuildTile(0);let prior=try! blocker.world.encoded(),p0=blocker.buildSelectionPoint
    blocker.moveBuildSelection(x:p0.0+8.4,y:p0.1,z:p0.2,snap:false)
    check(try! blocker.world.encoded()==prior,"Moving a whole module into another module is rejected atomically")
    let growing=Game();growing.world = .blank;growing.beginBuilding()
    for _ in 0..<20 {growing.addModule(.stairs)}
    check(growing.world.tiles.count==120 && growing.world.valid,"Twenty modules exceed the former tile and world bounds caps")
    var large=growing.world
    for i in 0..<150 {large.structures.append(World.piece(.tree,x:Float(i)*3,y:0,z:-10))}
    check(large.valid,"Scenery is no longer capped at 128 pieces")
    check(try! JSONDecoder().decode(World.self,from:large.encoded()).tiles.count==120,"Larger worlds retain all modules on import")
    for source in [World.garden,World.generate(seed:98)] {
        for duration in MovieDuration.allCases {
            let plan=MovieEditPlan(world:source,duration:duration)
            check(plan.beats.truncatingRemainder(dividingBy:4)==0,"Movies end on a bar")
            check(plan.shots.first?.start==0 && plan.shots.last?.end==plan.beats,"Edit covers the complete chosen duration")
            for shot in plan.shots {
                check(shot.start.truncatingRemainder(dividingBy:8)==0,"Every camera cut falls on a two-bar boundary")
                if shot.kind == .firstPerson {check([VoiceRole.melody,.arpeggio,.bass].contains(source.voices[shot.voice].role) && source.voices[shot.voice].enabled,"First person uses enabled walking characters only")}
                check(plan.shot(at:shot.start).start==shot.start,"Shot lookup changes exactly on the musical boundary")
            }
        }
    }
    let splitPlan=MovieEditPlan(world:.garden,duration:.long)
    check(splitPlan.shots.contains{$0.kind == .split},"Long social edits include split-screen moments")
    check(MovieEditPlan(world:.garden,duration:.long,splitScreen:false).shots.allSatisfy{$0.kind != .split},"Split screen can be disabled")
    var noWalkers=World.garden
    for i in noWalkers.voices.indices {noWalkers.voices[i].enabled = [.drone,.pad,.percussion].contains(noWalkers.voices[i].role)}
    check(MovieEditPlan(world:noWalkers,duration:.long).shots.allSatisfy{$0.kind != .firstPerson},"Floating and stationary performers never get first person")
    for i in noWalkers.voices.indices {noWalkers.voices[i].enabled=false}
    check(MovieEditPlan(world:noWalkers,duration:.long).shots.allSatisfy{$0.kind == .overview},"No characters yields overview-only montage")
    check(WorldModule(dragValue:"unrelated text")==nil,"External drops are ignored")
    let orbit=Game();let fixedAngle=orbit.garden.sculpture.eulerAngles.y
    orbit.rotate()
    check(abs(orbit.garden.orbitYaw-Double.pi/2)<0.0001 && orbit.garden.sculpture.eulerAngles.y==fixedAngle,"Rotate control moves camera orbit instead of architecture")
    orbit.home();check(orbit.garden.orbitYaw==0,"Fit world resets camera orbit")
    orbit.garden.showBuilderGuide(enabled:true,height:1,structure:nil)
    check((orbit.garden.camera.camera!.categoryBitMask & 32) != 0,"Advanced builder keeps the panorama visible")
    orbit.garden.orbitYaw=1;orbit.toggleFrontView()
    check(orbit.garden.orbitYaw==0 && orbit.frontView,"Front view resets orbit alignment")
    let toggles=Game();toggles.world = .blank
    toggles.world.tiles=[Tile(x:0,y:1,z:0,note:60)]
    toggles.setVoiceEnabled(0,true)
    toggles.setVoiceEnabled(1,true)
    check(toggles.world.voices[1].enabled && toggles.world.voices[0].enabled,"Portrait toggles only the chosen voice")
    toggles.undo();check(!toggles.world.voices[1].enabled,"Character toggle can be undone")
    toggles.redo();check(toggles.world.voices[1].enabled,"Character toggle can be redone")
    toggles.playing=true;toggles.audio.prepared=true;toggles.audio.beat=7.25
    let priorStops=toggles.audio.stops
    toggles.viewCharacter(1)
    check(toggles.follow && toggles.cameraVoice==1 && !toggles.firstPerson,"Portrait opens follow camera")
    toggles.firstPerson=true;toggles.viewCharacter(0)
    check(toggles.firstPerson && toggles.cameraVoice==0,"Portrait preserves first person when changing character")
    toggles.follow=true;toggles.firstPerson=true;toggles.followedVoice=0
    toggles.setVoiceEnabled(0,false)
    check(toggles.cameraVoice==1 && toggles.followedVoice==1,"Disabling the followed character selects another enabled character")
    toggles.setVoiceEnabled(1,false)
    check(toggles.availableVoices.isEmpty && !toggles.follow && !toggles.firstPerson,"All characters off safely returns to world view")
    check(toggles.playing && toggles.audio.prepared && toggles.audio.beat==7.25 && toggles.audio.stops==priorStops,"Muting every character preserves playing transport and sample position")
    toggles.setVoiceEnabled(0,true)
    check(toggles.audio.beat==7.25 && toggles.audio.stops==priorStops,"Re-enabling joins the existing timeline")
    toggles.setVoiceEnabled(0,false)
    let muted=try! JSONDecoder().decode(World.self,from:toggles.world.encoded())
    check(muted.voices.allSatisfy{!$0.enabled},"Character states persist in the shared world")
    let count=toggles.history.count;toggles.rendering=true;toggles.setVoiceEnabled(0,true)
    check(!toggles.world.voices[0].enabled && toggles.history.count==count,"Render-in-progress blocks conflicting toggles")
    toggles.rendering=false;toggles.setVoiceEnabled(-1,true)
    check(toggles.history.count==count,"Invalid character index is ignored")
    let backdropStops=toggles.audio.stops
    toggles.setEnvironment(.underwater)
    check(toggles.world.environment == .underwater && toggles.playing && toggles.audio.stops==backdropStops,"Changing a backdrop preserves live playback")
    game.toggleFrontView()
    check(game.frontView && !game.follow && !game.firstPerson,"Front view leaves character cameras and aligns the overview")
    game.toggleFrontView()
    check(!game.frontView,"Isometric overview is recoverable")
    let beforeGuide=try! game.world.encoded(),guideHistory=game.history.count
    game.playing=true;game.audio.prepared=true;game.audio.beat=9.5
    let guideStops=game.audio.stops
    game.openBuildTutorial()
    check(game.buildTutorial != nil && !game.playing && game.audio.beat==9.5,"Opening tutorial pauses the shared clock without rewinding")
    check(try! game.buildTutorial!.world.encoded()==beforeGuide,"Tutorial captures the exact current world")
    game.finishBuildTutorial()
    check(game.playing && game.audio.beat==9.5 && game.audio.stops==guideStops,"Closing tutorial resumes the same audio position")
    check(try! game.world.encoded()==beforeGuide && game.history.count==guideHistory,"Tutorial does not edit the world or undo history")
    game.openBuildTutorial();game.finishBuildTutorial(resume:false)
    check(!game.playing,"Dismissing tutorial while inactive cannot resume audio")
    game.finishBuilding()
    check(!game.building && game.garden.builderBounds==nil,"Done restores normal world framing")
}
print("\(checks) production builder-controller checks passed with mocked platform audio/video services.")
