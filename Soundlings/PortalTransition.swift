import Foundation

// One envelope owns a complete departure → relocation → arrival transition.
// Close portal chains stay covered instead of briefly revealing the world between jumps.
struct PortalTransition {
    enum Phase {case visible,closing,covered,opening}
    private(set) var phase:Phase = .visible
    private(set) var alpha:Double=0
    private var elapsed:Double=0
    private var arrived=false
    static let fadeOut=0.14,fadeIn=0.22,minimumVisible=0.12
    static func ease(_ value:Double)->Double {let t=min(1,max(0,value));return t*t*(3-2*t)}
    mutating func update(seconds:Double,nextIn:Double?,waiting:Bool,transferred:Bool) {
        let closeChain=nextIn.map{$0<Self.fadeOut+Self.fadeIn+Self.minimumVisible} ?? false
        if transferred {
            alpha=1;elapsed=0;arrived=true;phase=closeChain ? .covered : .opening
            return
        }
        if waiting {alpha=1;elapsed=0;arrived=false;phase = .covered;return}
        guard seconds>0 else {return} // Pausing freezes the same envelope.
        switch phase {
        case .visible:
            if let nextIn,nextIn<Self.fadeOut {
                phase = .closing;arrived=false
                alpha=Self.ease(1-nextIn/Self.fadeOut)
            }
        case .closing:
            alpha=max(alpha,nextIn.map{Self.ease(1-$0/Self.fadeOut)} ?? 1)
            if alpha>=1 {phase = .covered}
        case .covered:
            alpha=1
            if arrived && !closeChain {phase = .opening;elapsed=0}
        case .opening:
            elapsed+=seconds;alpha=1-Self.ease(elapsed/Self.fadeIn)
            if alpha<=0 {phase = .visible;elapsed=0;arrived=false}
        }
    }
}
