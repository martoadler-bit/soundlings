import SwiftUI

// Shared, non-Menu replacements for value pickers and action menus.
// AGENTS.md bans SwiftUI Menu / menu-style Picker / push-to-pick screens;
// these inline expanding panels and chip rows replace them everywhere in the app.

private struct DismissExpandingMenuKey:EnvironmentKey { static let defaultValue:() -> Void = {} }
extension EnvironmentValues {
    var dismissExpandingMenu:() -> Void {
        get {self[DismissExpandingMenuKey.self]}
        set {self[DismissExpandingMenuKey.self]=newValue}
    }
}

/// An inline panel that expands next to its trigger button instead of presenting a system Menu.
struct ExpandingActionButton<Label:View,Content:View>:View {
    var alignment:Alignment = .topTrailing
    @ViewBuilder var label:(Bool)->Label
    @ViewBuilder var content:()->Content
    @State private var expanded=false
    var body:some View {
        Button {withAnimation(.snappy(duration:0.18)) {expanded.toggle()}} label: {label(expanded)}
            .overlay(alignment:alignment) {
                if expanded {
                    VStack(alignment:.leading,spacing:0) {content()}
                        .padding(.vertical,6)
                        .frame(minWidth:230,alignment:.leading)
                        .background(.ultraThinMaterial,in:RoundedRectangle(cornerRadius:16))
                        .fixedSize(horizontal:true,vertical:true)
                        .offset(y:alignment == .topTrailing || alignment == .topLeading ? -8 : 8)
                        .transition(.scale(scale:0.94,anchor:anchor).combined(with:.opacity))
                        .environment(\.dismissExpandingMenu) {withAnimation(.snappy(duration:0.18)) {expanded=false}}
                }
            }
            .zIndex(expanded ? 20 : 0)
    }
    private var anchor:UnitPoint {
        switch alignment {
        case .topTrailing:return .topTrailing
        case .topLeading:return .topLeading
        case .bottomTrailing:return .bottomTrailing
        default:return .bottomLeading
        }
    }
}

/// One row inside an ExpandingActionButton's panel; dismisses the panel after its action runs.
struct ExpandingMenuRow:View {
    @Environment(\.dismissExpandingMenu) private var dismiss
    let title:String
    var symbol:String?=nil
    var checked=false
    var role:ButtonRole?=nil
    var disabled=false
    let action:()->Void
    init(_ title:String,symbol:String?=nil,checked:Bool=false,role:ButtonRole?=nil,disabled:Bool=false,action:@escaping()->Void) {
        self.title=title;self.symbol=symbol;self.checked=checked;self.role=role;self.disabled=disabled;self.action=action
    }
    var body:some View {
        Button {dismiss();action()} label: {
            HStack {
                if let symbol {Image(systemName:symbol).frame(width:20)}
                Text(title)
                Spacer(minLength:12)
                if checked {Image(systemName:"checkmark")}
            }
            .padding(.horizontal,14).padding(.vertical,10).contentShape(Rectangle())
        }
        .buttonStyle(.plain).disabled(disabled)
        .foregroundStyle(role == .destructive ? Color.red : Color.primary)
    }
}

/// A visible row of choice chips, replacing Picker (which pushes a screen or opens a menu on iOS).
struct ChipPicker<T:Hashable>:View {
    var title:String?
    @Binding var selection:T
    let options:[T]
    let label:(T)->String
    init(_ title:String?=nil,selection:Binding<T>,options:[T],label:@escaping(T)->String) {
        self.title=title;self._selection=selection;self.options=options;self.label=label
    }
    var body:some View {
        VStack(alignment:.leading,spacing:6) {
            if let title {Text(title).font(.caption).foregroundStyle(.secondary)}
            ScrollView(.horizontal,showsIndicators:false) {
                HStack(spacing:8) {
                    ForEach(options,id:\.self) {option in
                        Button(label(option)) {selection=option}
                            .font(.caption.weight(.medium))
                            .padding(.horizontal,14).padding(.vertical,8)
                            .background(option==selection ? Color.teal : Color.white.opacity(0.08),in:Capsule())
                            .foregroundStyle(option==selection ? Color.black : Color.primary)
                    }
                }
            }
        }
    }
}
