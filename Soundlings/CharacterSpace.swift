import Foundation

// Kinematic collision resolution is separate from the sample-accurate music clock.
// Every candidate must remain on a real pad/bridge at the same elevation.
struct SpacePoint {
    var x:Double,y:Double,z:Double
    func distance(_ other:SpacePoint)->Double { hypot(x-other.x,z-other.z) }
}
struct SpaceBody {
    var point:SpacePoint
    var radius:Double
    var height:Double
    var floating:Bool=false
}
struct SpaceObstacle {
    var min:SpacePoint,max:SpacePoint
    var walkSurface=false
    func intersects(_ body:SpaceBody)->Bool {
        if walkSurface && body.point.y>=max.y-0.22 {return false}
        guard body.point.y+body.height>min.y+0.02,body.point.y<max.y-0.02 else {return false}
        let x=Swift.max(min.x,Swift.min(max.x,body.point.x)),z=Swift.max(min.z,Swift.min(max.z,body.point.z))
        return hypot(body.point.x-x,body.point.z-z)<body.radius
    }
}
final class NavigationMemory {
    struct Choice {var target:SpacePoint;var budget:Double}
    var choices=[Int:Choice]()
    func reset() {choices=[:]}
}
enum CharacterSpace {
    static func intersects(_ a:SpaceBody,_ b:SpaceBody)->Bool {
        a.point.y+a.height>b.point.y+0.02 && b.point.y+b.height>a.point.y+0.02 && a.point.distance(b.point)<a.radius+b.radius+0.025
    }
    // Foot clearance follows the route's raised landing before the body reaches
    // its front edge. This prevents the upper step from cutting into the ankles.
    static func grounded(_ point:SpacePoint,radius:Double,world:World)->SpacePoint {
        return SpacePoint(x:point.x,y:groundHeight(point,radius:radius,world:world) ?? point.y,z:point.z)
    }
    static func shadowFloor(_ point:SpacePoint,world:World)->Double? {groundHeight(point,radius:0.05,world:world,maxDrop:8)}
    private static func groundHeight(_ point:SpacePoint,radius:Double,world:World,maxDrop:Double=0.7)->Double? {
        var best:Double?,score=Double.infinity
        for tile in world.tiles {
            let dx=abs(point.x-Double(tile.x)),dz=abs(point.z-Double(tile.z)),height=Double(tile.y)+tile.footClearance
            if dx<=0.47-radius && dz<=0.47-radius && height-point.y<=0.7 && point.y-height<=maxDrop {
                let distance=hypot(dx,dz)+abs(height-point.y)*0.2
                if distance<score {best=height;score=distance}
            }
        }
        for i in world.tiles.indices {
            let j=(i+1)%world.tiles.count
            guard !world.requiresPortalLink(from:i,to:j) else {continue}
            let a=world.tiles[i],b=world.tiles[j]
            let dx=Double(b.x-a.x),dz=Double(b.z-a.z),length=hypot(dx,dz)
            guard length>0.001 else {continue}
            let t=max(0,min(1,((point.x-Double(a.x))*dx+(point.z-Double(a.z))*dz)/(length*length)))
            let lateral=hypot(point.x-Double(a.x)-dx*t,point.z-Double(a.z)-dz*t)
            guard lateral<=world.walkwayWidth/2-radius else {continue}
            let landing=min(0.75,(world.walkwayWidth/2+0.055+radius)/length)
            let dy=Double(b.y-a.y)
            let u=dy>0 ? min(1,t/max(0.1,1-landing)) : max(0,(t-landing)/max(0.1,1-landing))
            let liftA=a.footClearance*max(0,min(1,(0.55-t*length)/0.15)),liftB=b.footClearance*max(0,min(1,(0.55-(1-t)*length)/0.15))
            let height=Double(a.y)+dy*u+max(liftA,liftB)
            let distance=lateral+abs(height-point.y)*0.2
            if height-point.y<=0.7 && point.y-height<=maxDrop && distance<score {best=height;score=distance}
        }
        return best
    }
    private static func routeGoal(from origin:SpacePoint,to target:SpacePoint,world:World)->SpacePoint {
        guard origin.distance(target)>0.6,world.tiles.count>2 else {return target}
        func segment(_ point:SpacePoint)->Int? {
            var best:Int?,distance=Double.infinity
            for i in world.tiles.indices {
                let j=(i+1)%world.tiles.count
                if world.requiresPortalLink(from:i,to:j) {continue}
                let a=world.tiles[i],b=world.tiles[j],dx=Double(b.x-a.x),dz=Double(b.z-a.z)
                let length=dx*dx+dz*dz
                if length<0.001 {continue}
                let t=max(0,min(1,((point.x-Double(a.x))*dx+(point.z-Double(a.z))*dz)/length))
                let d=hypot(point.x-Double(a.x)-dx*t,point.z-Double(a.z)-dz*t)+abs(point.y-Double(a.y)-Double(b.y-a.y)*t)*0.15
                if d<distance {distance=d;best=i}
            }
            return distance<0.8 ? best : nil
        }
        guard let current=segment(origin),let destination=segment(target),current != destination else {return target}
        let count=world.tiles.count,direction=world.reversed ? -1 : 1
        var next=world.reversed ? current : (current+1)%count
        let tile=world.tiles[next]
        if hypot(origin.x-Double(tile.x),origin.z-Double(tile.z))<0.08 {next=(next+direction+count)%count}
        let waypoint=world.tiles[next]
        return SpacePoint(x:Double(waypoint.x),y:Double(waypoint.y),z:Double(waypoint.z))
    }
    static func supported(_ body:SpaceBody,world:World)->Bool {
        guard !world.tiles.isEmpty else {return false}
        if body.floating {return true}
        let p=body.point,r=body.radius
        if let floor=groundHeight(p,radius:r,world:world),abs(floor-p.y)<0.22 {return true}
        if world.voices.contains(where:{$0.role == .percussion && $0.enabled}) {
            let stage=world.percussionStage()
            if abs(Double(stage.y)-p.y)<0.22 && abs(p.x-Double(stage.x))<=0.75-r && abs(p.z-Double(stage.z))<=0.75-r {return true}
        }
        for tile in world.tiles where abs(Double(tile.y)-p.y)<0.22 {
            if abs(p.x-Double(tile.x))<=world.walkwayWidth/2+0.055-r && abs(p.z-Double(tile.z))<=world.walkwayWidth/2+0.055-r {return true}
        }
        return false
    }
    // Integrate from the previous pose. Reserving every other actor's current space
    // prevents two actors from swapping through each other in the same frame.
    static func advance(_ wanted:[SpaceBody],previous:[SpacePoint],world:World,obstacles:[SpaceObstacle],maxStep:Double,portals:Set<Int>,locked:Set<Int>=[],memory:NavigationMemory?=nil)->[SpacePoint] {
        guard previous.count==wanted.count else {return resolve(wanted,previous:[],world:world,obstacles:obstacles)}
        for i in locked {memory?.choices.removeValue(forKey:i)}
        var result=previous
        func limit(_ point:SpacePoint,from origin:SpacePoint,factor:Double=1,radius:Double?=nil)->SpacePoint {
            let dx=point.x-origin.x,dy=point.y-origin.y,dz=point.z-origin.z
            let distance=sqrt(dx*dx+dy*dy+dz*dz),ratio=min(1,maxStep*factor/max(0.000001,distance))
            var candidate=SpacePoint(x:origin.x+dx*ratio,y:origin.y+dy*ratio,z:origin.z+dz*ratio)
            if let radius {
                for _ in 0..<4 {
                    candidate=grounded(candidate,radius:radius,world:world)
                    let distance=sqrt(pow(candidate.x-origin.x,2)+pow(candidate.y-origin.y,2)+pow(candidate.z-origin.z,2))
                    if distance<=maxStep*factor+0.000001 {break}
                    let scale=maxStep*factor/distance
                    candidate=SpacePoint(x:origin.x+(candidate.x-origin.x)*scale,y:origin.y+(candidate.y-origin.y)*scale,z:origin.z+(candidate.z-origin.z)*scale)
                }
            }
            return candidate
        }
        for i in wanted.indices where !locked.contains(i) {
            var body=wanted[i]
            if !body.floating {body.point=grounded(body.point,radius:body.radius,world:world)}
            let origin=previous[i],teleport=portals.contains(i)
            func free(_ point:SpacePoint)->Bool {
                var test=body;test.point=point
                // A previously raised spawn can descend gradually instead of snapping down.
                if origin.y>body.point.y+0.24 {test.floating=true}
                guard supported(test,world:world),!obstacles.contains(where:{$0.intersects(test)}) else {return false}
                for j in wanted.indices where j != i {
                    var other=wanted[j];other.point=result[j]
                    if intersects(test,other) {return false}
                }
                return true
            }
            func swept(_ point:SpacePoint)->Bool {
                if teleport {return free(point)}
                for step in 1...4 {
                    let t=Double(step)/4
                    if !free(SpacePoint(x:origin.x+(point.x-origin.x)*t,y:origin.y+(point.y-origin.y)*t,z:origin.z+(point.z-origin.z)*t)) {return false}
                }
                return true
            }
            if var choice=memory?.choices[i] {
                choice.budget-=maxStep
                if choice.budget<=0 || teleport {memory?.choices.removeValue(forKey:i)}
                else {memory?.choices[i]=choice}
            }
            let routed=body.floating || teleport ? body.point : routeGoal(from:origin,to:body.point,world:world)
            let goal=memory?.choices[i]?.target ?? routed
            let direct=teleport ? body.point : limit(goal,from:origin,factor:memory?.choices[i]==nil ? 1 : 0.25,radius:body.floating ? nil : body.radius)
            if swept(direct) {result[i]=direct;continue}
            if body.floating && !teleport {
                // Airborne creatures yield vertically; they never use ground detours or jump encounters.
                let climb=SpacePoint(x:origin.x,y:origin.y+maxStep*0.3,z:origin.z)
                if swept(climb) {result[i]=climb}
                continue
            }
            if memory != nil && memory?.choices[i]==nil && !teleport {
                var candidates=[SpacePoint]()
                for radius in [0.12,0.24,0.36,0.50,0.70,1.0] {
                    for step in 0..<16 {
                        let angle=Double((step+i*3)%16) * .pi/8
                        candidates.append(SpacePoint(x:body.point.x+cos(angle)*radius,y:body.point.y,z:body.point.z+sin(angle)*radius))
                    }
                }
                candidates.sort {
                    let a=limit($0,from:origin,factor:0.25),b=limit($1,from:origin,factor:0.25)
                    return a.distance(body.point)+abs(a.y-body.point.y)<b.distance(body.point)+abs(b.y-body.point.y)
                }
                for target in candidates {
                    let point=limit(target,from:origin,factor:0.25)
                    if point.distance(origin)>0.0001 && swept(point) {
                        result[i]=point;memory?.choices[i]=NavigationMemory.Choice(target:target,budget:2.4);break
                    }
                }
            }
            if teleport {
                // A portal may choose a nearby clear landing, while the avatar is invisible.
                for radius in [0.12,0.24,0.36,0.50,0.70,1.0] {
                    var found=false
                    for step in 0..<16 {
                        let angle=Double(step) * .pi/8
                        let point=SpacePoint(x:body.point.x+cos(angle)*radius,y:body.point.y,z:body.point.z+sin(angle)*radius)
                        if free(point) {result[i]=point;found=true;break}
                    }
                    if found {break}
                }
            }
            // No free path: wait at the last safe pose. Never eject upwards during playback.
        }
        return result
    }
    static func resolve(_ wanted:[SpaceBody],previous:[SpacePoint],world:World,obstacles:[SpaceObstacle])->[SpacePoint] {
        var placed=[SpaceBody]()
        for (index,body) in wanted.enumerated() {
            var body=body
            if !body.floating {body.point=grounded(body.point,radius:body.radius,world:world)}
            var candidates=[body.point]
            // A stable order prevents rapid left/right oscillation when two walkers meet.
            for radius in [0.12,0.24,0.36,0.50,0.70,1.0] {
                for step in 0..<16 {
                    let angle=Double((step+index*3)%16) * .pi/8
                    candidates.append(SpacePoint(x:body.point.x+cos(angle)*radius,y:body.point.y,z:body.point.z+sin(angle)*radius))
                }
            }
            if previous.indices.contains(index),previous[index].distance(body.point)<1.2 {candidates.append(previous[index])}
            var result:SpaceBody?
            for candidate in candidates {
                var test=body;test.point=candidate
                if supported(test,world:world) && !obstacles.contains(where:{$0.intersects(test)}) && !placed.contains(where:{intersects(test,$0)}) {
                    result=test;break
                }
            }
            // Dense imported scenes can have no free floor. A short hop yields vertical space.
            // This is explicit separation, never permission to pass through another actor.
            if result==nil {
                var test=body;test.floating=true
                for level in 1...12 {
                    test.point.y=body.point.y+Double(level)*0.32
                    if !obstacles.contains(where:{$0.intersects(test)}) && !placed.contains(where:{intersects(test,$0)}) {result=test;break}
                }
            }
            if result==nil {
                var clear=body
                clear.point.y=max(obstacles.map{$0.max.y}.max() ?? body.point.y,placed.map{$0.point.y+$0.height}.max() ?? body.point.y)+0.2
                result=clear
            }
            placed.append(result!)
        }
        return placed.map(\.point)
    }
}

// Encounters are committed actions, rather than competing corrections every frame.
final class EncounterMotion {
    enum Kind {case jump,turn}
    struct Action {
        var actor:Int,other:Int
        var start:SpacePoint,end:SpacePoint
        var age:Double=0
        var blockedTime:Double=0
        var duration:Double
        var kind:Kind
        func point(_ time:Double)->SpacePoint {
            let t=max(0,min(1,time/duration))
            let travel=kind == .jump ? max(0,min(1,(t-0.22)/0.56)) : t
            let u=travel*travel*(3-2*travel)
            return SpacePoint(x:start.x+(end.x-start.x)*u,y:start.y+(end.y-start.y)*u+(kind == .jump ? sin(.pi*t)*1.5 : 0),z:start.z+(end.z-start.z)*u)
        }
    }
    private(set) var actions=[Action]()
    private var cooldown=[Int:Double]()
    private(set) var jumps=0,turns=0
    func reset() {actions=[];cooldown=[:];jumps=0;turns=0}
    func step(_ bodies:[SpaceBody],previous:[SpacePoint],world:World,obstacles:[SpaceObstacle],seconds:Double,portals:Set<Int>)->(points:[SpacePoint],locked:Set<Int>,headings:[Int:Double]) {
        guard previous.count==bodies.count else {return(previous,[],[:])}
        cooldown=cooldown.mapValues{max(0,$0-seconds)}
        var points=previous,locked=Set<Int>(),headings=[Int:Double]()
        func safe(_ point:SpacePoint,actor:Int,positions:[SpacePoint],ground:Bool)->Bool {
            var test=bodies[actor];test.point=point
            if ground && !CharacterSpace.supported(test,world:world) {return false}
            if obstacles.contains(where:{$0.intersects(test)}) {return false}
            for j in bodies.indices where j != actor {
                var other=bodies[j];other.point=positions[j]
                if CharacterSpace.intersects(test,other) {return false}
            }
            return true
        }
        let busy=Set(actions.flatMap{[$0.actor,$0.other]})
        if seconds>0 {
            outer: for i in bodies.indices where !busy.contains(i) && !portals.contains(i) && (cooldown[i] ?? 0)==0 && !bodies[i].floating {
                for j in bodies.indices where j>i && !busy.contains(j) && !portals.contains(j) && (cooldown[j] ?? 0)==0 && !bodies[j].floating {
                    let a=previous[i],b=previous[j],distance=a.distance(b)
                    let gap=bodies[i].radius+bodies[j].radius
                    guard abs(a.y-b.y)<0.25,distance<gap+0.38 else {continue}
                    // Only react when a walker is actually approaching the other.
                    let da=(bodies[i].point.x-a.x)*(b.x-a.x)+(bodies[i].point.z-a.z)*(b.z-a.z)
                    let db=(bodies[j].point.x-b.x)*(a.x-b.x)+(bodies[j].point.z-b.z)*(a.z-b.z)
                    guard da>0.015 || db>0.015 else {continue}
                    let actor=bodies[i].radius<0.45 ? i : j,other=actor==i ? j : i
                    guard bodies[actor].radius<0.45 else {continue}
                    let start=previous[actor],center=previous[other]
                    let length=max(0.001,start.distance(center)),dx=(center.x-start.x)/length,dz=(center.z-start.z)/length
                    let end=SpacePoint(x:center.x+dx*(gap+0.18),y:center.y,z:center.z+dz*(gap+0.18))
                    var action=Action(actor:actor,other:other,start:start,end:end,duration:0.95,kind:.jump)
                    var valid=safe(end,actor:actor,positions:previous,ground:true)
                    if valid {
                        for frame in 1...48 where !safe(action.point(Double(frame)/48*action.duration),actor:actor,positions:previous,ground:false) {valid=false;break}
                    }
                    if !valid {
                        action.kind = .turn;action.duration=0.65
                        action.end=SpacePoint(x:start.x-dx*0.65,y:start.y,z:start.z-dz*0.65)
                        valid=true
                        for frame in 1...32 where !safe(action.point(Double(frame)/32*action.duration),actor:actor,positions:previous,ground:true) {valid=false;break}
                    }
                    if valid {
                        actions.append(action)
                        if action.kind == .jump {jumps+=1} else {turns+=1}
                        break outer
                    }
                }
            }
        }
        for i in actions.indices {
            let a=actions[i],next=min(a.duration,a.age+seconds),point=a.point(next)
            // Reserve both participants; if a third actor obstructs the landing, hold the maneuver.
            locked.insert(a.actor)
            // A third arrival can temporarily obstruct a maneuver. Let the waiting
            // partner move away instead of reserving both characters forever.
            if a.blockedTime<0.35 {locked.insert(a.other)}
            if safe(point,actor:a.actor,positions:points,ground:a.kind == .turn) {
                actions[i].age=next;actions[i].blockedTime=0;points[a.actor]=point
            } else {actions[i].blockedTime+=seconds}
            headings[a.actor]=atan2(a.end.x-a.start.x,a.end.z-a.start.z)
            if actions[i].age>=a.duration {cooldown[a.actor]=0.9;cooldown[a.other]=0.9}
        }
        actions.removeAll{$0.age >= $0.duration}
        return(points,locked,headings)
    }
}
