import Foundation

struct FlightPath {
    let points:[SpacePoint]
}
enum FlightSpace {
    static let clearance=0.35
    static func hover(_ point:SpacePoint,radius:Double,obstacles:[SpaceObstacle])->SpacePoint {
        var result=point
        for obstacle in obstacles where point.x+radius>obstacle.min.x && point.x-radius<obstacle.max.x && point.z+radius>obstacle.min.z && point.z-radius<obstacle.max.z {
            result.y=max(result.y,obstacle.max.y+clearance)
        }
        return result
    }
    static func crosses(_ a:SpacePoint,_ b:SpacePoint,obstacle:SpaceObstacle,radius:Double)->Bool {
        var enter=0.0,leave=1.0
        for (start,end,low,high) in [(a.x,b.x,obstacle.min.x-radius,obstacle.max.x+radius),(a.z,b.z,obstacle.min.z-radius,obstacle.max.z+radius)] {
            let delta=end-start
            if abs(delta)<0.000001 {if start<low || start>high {return false}}
            else {
                let t1=(low-start)/delta,t2=(high-start)/delta
                enter=max(enter,min(t1,t2));leave=min(leave,max(t1,t2))
                if enter>leave {return false}
            }
        }
        return true
    }
    static func path(from source:SpacePoint,to target:SpacePoint,radius:Double,obstacles:[SpaceObstacle])->FlightPath {
        let a=hover(source,radius:radius+0.1,obstacles:obstacles),b=hover(target,radius:radius+0.1,obstacles:obstacles)
        var altitude=max(a.y,b.y)
        for obstacle in obstacles where crosses(a,b,obstacle:obstacle,radius:radius+0.1) {altitude=max(altitude,obstacle.max.y+clearance)}
        var points=[source]
        for point in [a,SpacePoint(x:a.x,y:altitude,z:a.z),SpacePoint(x:b.x,y:altitude,z:b.z),b] {
            let last=points.last!
            if hypot(last.distance(point),last.y-point.y)>0.000001 {points.append(point)}
        }
        return FlightPath(points:points)
    }
}
final class FlightNavigation {
    struct Journey {var path:FlightPath;var cursor:Int=1}
    private var journeys=[Int:Journey]()
    func reset() {journeys=[:]}
    func advance(voice:Int,current:SpacePoint,target:SpacePoint,radius:Double,seconds:Double,obstacles:[SpaceObstacle])->SpacePoint {
        if journeys[voice]==nil {journeys[voice]=Journey(path:FlightSpace.path(from:current,to:target,radius:radius,obstacles:obstacles))}
        var journey=journeys[voice]!
        while journey.cursor<journey.path.points.count {
            let point=journey.path.points[journey.cursor]
            if hypot(current.distance(point),current.y-point.y)<0.015 {journey.cursor+=1} else {break}
        }
        if journey.cursor>=journey.path.points.count {
            journey=Journey(path:FlightSpace.path(from:current,to:target,radius:radius,obstacles:obstacles))
        }
        journeys[voice]=journey
        guard journey.cursor<journey.path.points.count else {return current}
        let point=journey.path.points[journey.cursor],dx=point.x-current.x,dy=point.y-current.y,dz=point.z-current.z
        let distance=sqrt(dx*dx+dy*dy+dz*dz)
        // Slow down at each turn and station; changes of musical destination never reset a flight mid-air.
        let speed=min(2.8,max(0.18,distance*4)),ratio=min(1,speed*seconds/max(distance,0.000001))
        return SpacePoint(x:current.x+dx*ratio,y:current.y+dy*ratio,z:current.z+dz*ratio)
    }
}
