// Native zoom for Hyprland's 0.57 scene renderer. Kingstra's Lua layout owns
// workspace geometry; this module changes only presentation and pointer mapping.
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdio>
#include <dlfcn.h>
#include <format>
#include <map>
#include <set>
#include <string>
#include <vector>
#include <lua.hpp>
#include <linux/input-event-codes.h>
#include <hyprland/src/plugins/PluginAPI.hpp>
#include <hyprland/src/config/values/types/BoolValue.hpp>
#define protected public
#include <hyprland/src/render/Renderer.hpp>
#undef protected
#include <hyprland/src/render/scene/SceneSelection.hpp>
#include <hyprland/src/render/pass/TexPassElement.hpp>
#include <hyprland/src/desktop/view/window/Window.hpp>
#include <hyprland/src/desktop/view/window/WindowPresentation.hpp>
#include <hyprland/src/desktop/view/LayerSurface.hpp>
#include <hyprland/src/desktop/state/FocusState.hpp>
#include <hyprland/src/desktop/state/GlobalWindowController.hpp>
#include <hyprland/src/desktop/state/WindowState.hpp>
#include <hyprland/src/desktop/state/ViewState.hpp>
#include <hyprland/src/layout/LayoutManager.hpp>
#include <hyprland/src/layout/algorithm/Algorithm.hpp>
#include <hyprland/src/layout/algorithm/TiledAlgorithm.hpp>
#include <hyprland/src/layout/space/Space.hpp>
#include <hyprland/src/managers/SeatManager.hpp>
#include <hyprland/src/managers/SessionLockManager.hpp>
#include <hyprland/src/keybinds/Manager.hpp>
#include <hyprland/src/protocols/LayerShell.hpp>
#include <hyprland/src/state/MonitorState.hpp>
#include <hyprland/src/workspace/HLWorkspace.hpp>
#include "Symbols.hpp"

namespace {
HANDLE handle;
using namespace Desktop::View;
struct Zoom { PHLMONITORREF monitor; PHLWORKSPACE workspace; double factor=1; };
std::map<std::string,Zoom> zooms;
struct Grab {
    PHLWINDOW window;
    PHLMONITORREF monitor;
    Vector2D ratio, size, start;
    CBox box;
    bool tiled=false, resize=false;
    Layout::eRectCorner corner=Layout::CORNER_NONE;
    uint32_t button=BTN_LEFT;
} grab;
PHLWINDOW pointerWindow;
SP<CWLSurfaceResource> pointerSurface;
PHLMONITORREF pointerMonitor;
std::set<uint32_t> pointerButtons;
std::set<uint32_t> heldButtons;
std::vector<CHyprSignalListener> listeners;
CFunctionHook *windowsHook, *fullscreenHook, *shouldRenderHook, *windowAtHook,
              *damageHook, *beginDragHook, *endDragHook, *textureHook;
using WindowsFn=void (*)(void*,Render::CRenderContext&,PHLMONITOR,PHLWORKSPACE,const Time::steady_tp&,Render::eSceneMode);
using RenderableFn=bool (*)(void*,PHLWINDOW,PHLMONITOR);
using HitFn=PHLWINDOW (*)(const void*,const Vector2D&,uint16_t,PHLWINDOW);
using DamageFn=void (*)(void*,SP<CWLSurfaceResource>,double,double,double);
using BeginFn=void (*)(void*,SP<Layout::ITarget>,eMouseBindMode,std::optional<Layout::eRectCorner>,bool);
using EndFn=bool (*)(void*);
using TextureFn=void (*)(void*,Render::CRenderContext&,WP<CTexPassElement>,const CRegion&);

Zoom* zoomFor(PHLMONITOR monitor) {
    if (!monitor) return nullptr;
    auto it=zooms.find(monitor->m_name);
    if (it==zooms.end() || it->second.workspace!=monitor->m_activeWorkspace) return nullptr;
    return &it->second;
}
PHLMONITOR monitorAt(const Vector2D& point) {
    return State::monitorState()->query().vec(point).run();
}
Vector2D toWorld(PHLMONITOR monitor,const Vector2D& point) {
    const auto z=zoomFor(monitor);
    if (!z) return point;
    const auto center=monitor->m_position+monitor->m_size/2;
    return center+(point-center)/z->factor;
}
void damageAll() {
    for (const auto& m:State::monitorState()->monitors()) g_pHyprRenderer->damageMonitor(m);
}
bool clipped(PHLWINDOW window,PHLMONITOR monitor) {
    return window && window->m_workspace && !(window->m_state & WINDOW_STATE_PINNED) &&
        zoomFor(window->m_workspace->m_monitor.lock()) && window->m_workspace->m_monitor!=monitor;
}
bool renderable(void* self,PHLWINDOW window,PHLMONITOR monitor) {
    if (window==grab.window) return false;
    if (clipped(window,monitor)) return false;
    if (const auto z=zoomFor(monitor);z && window && !(window->m_state & WINDOW_STATE_PINNED))
        return window->m_workspace==z->workspace && window->mapped() && !window->isHidden();
    return reinterpret_cast<RenderableFn>(shouldRenderHook->m_original)(self,window,monitor);
}
// The scene renderer keeps transforms in the frame's own context. Disable
// untransformed occlusion bounds while zoomed, including off-screen page buffers.
class ZoomHint : public IPassElement {
    Render::SRenderModifData mod;
    bool active;
  public:
    explicit ZoomHint(const Render::SRenderModifData& value,bool enabled=true):mod(value),active(enabled) {}
    std::vector<UP<IPassElement>> draw(Render::CRenderContext& ctx) override {
        ctx.m_data.renderModif=mod;
        // Surface damage and visible regions are in unscaled coordinates.
        // The scene renderer's transformed-source path applies clipping after
        // presentation, allowing complete buffers on neighbouring pages.
        ctx.m_data.renderingTransformedSource=active;
        return {};
    }
    ePassElementType type() override { return EK_CUSTOM; }
    const char* passName() override { return "KingstraZoomTransform"; }
    bool needsLiveBlur(Render::CRenderContext&) override { return false; }
    bool needsPrecomputeBlur(Render::CRenderContext&) override { return false; }
    bool disableSimplification(Render::CRenderContext&) override { return true; }
    bool requiresFullDamage(Render::CRenderContext&) override { return true; }
};
void transform(Render::CRenderContext& ctx,double factor,const Vector2D& offset) {
    Render::SRenderModifData mod;
    mod.modifs.emplace_back(Render::SRenderModifData::RMOD_TYPE_SCALE,static_cast<float>(factor));
    mod.modifs.emplace_back(Render::SRenderModifData::RMOD_TYPE_TRANSLATE,offset);
    Render::IHyprRenderer::addPassElement(ctx,makeUnique<ZoomHint>(mod));
}
void resetTransform(Render::CRenderContext& ctx) {
    Render::IHyprRenderer::addPassElement(ctx,makeUnique<ZoomHint>(Render::SRenderModifData{},false));
}
void drawTexture(void* self,Render::CRenderContext& ctx,WP<CTexPassElement> element,const CRegion& damage) {
    const auto texture=element.get();
    const bool transformed=texture && ctx.m_data.renderingTransformedSource && !zooms.empty() &&
        texture->m_data.blur && !texture->m_data.useProvidedDamage;
    CRegion previousDamage;
    if (transformed) {
        // The blur path otherwise transforms output-space damage a second
        // time, clipping translucent apps to the shrunken native viewport.
        previousDamage=texture->m_data.damage;
        texture->m_data.damage=damage;
        texture->m_data.useProvidedDamage=true;
    }
    reinterpret_cast<TextureFn>(textureHook->m_original)(self,ctx,element,damage);
    if (transformed) {
        texture->m_data.damage=previousDamage;
        texture->m_data.useProvidedDamage=false;
    }
}
void drawPreview(Render::CRenderContext& ctx,PHLMONITOR monitor,const Time::steady_tp& now,Render::eSceneMode mode) {
    if (!grab.window || grab.resize || monitorAt(g_pInputManager->getMouseCoordsInternal())!=monitor || mode!=Render::eSceneMode::MONITOR) return;
    const auto z=zoomFor(monitor);
    const double factor=z?z->factor:1;
    const auto point=g_pInputManager->getMouseCoordsInternal();
    const auto pos=point-monitor->m_position-Vector2D{grab.size.x*grab.ratio.x,grab.size.y*grab.ratio.y}*factor;
    auto presentation=grab.window->presentation().renderPresentation(mode);
    presentation.workspaceOffset={};
    presentation.floatingOffset=monitor->m_position-grab.window->position(IGeometric::GEOMETRIC_CURRENT);
    presentation.alphaVisible=true;
    presentation.alpha=presentation.fadeAlpha=presentation.workspaceAlpha=1;
    transform(ctx,factor,pos*monitor->m_scale);
    g_pHyprRenderer->renderWindow(ctx,grab.window,monitor,presentation,now,true,Render::RENDER_PASS_ALL);
    resetTransform(ctx);
}
void renderWindows(CFunctionHook* hook,void* self,Render::CRenderContext& ctx,PHLMONITOR monitor,PHLWORKSPACE workspace,const Time::steady_tp& now,Render::eSceneMode mode) {
    const auto z=zoomFor(monitor);
    const bool active=z && z->workspace==workspace && mode==Render::eSceneMode::MONITOR;
    if (active) transform(ctx,z->factor,monitor->m_size*(1-z->factor)*.5*monitor->m_scale);
    reinterpret_cast<WindowsFn>(hook->m_original)(self,ctx,monitor,workspace,now,mode);
    if (active) resetTransform(ctx);
    drawPreview(ctx,monitor,now,mode);
}
void windows(void* self,Render::CRenderContext& ctx,PHLMONITOR m,PHLWORKSPACE w,const Time::steady_tp& t,Render::eSceneMode mode) {
    renderWindows(windowsHook,self,ctx,m,w,t,mode);
}
void fullscreen(void* self,Render::CRenderContext& ctx,PHLMONITOR m,PHLWORKSPACE w,const Time::steady_tp& t,Render::eSceneMode mode) {
    renderWindows(fullscreenHook,self,ctx,m,w,t,mode);
}
void damageSurface(void* self,SP<CWLSurfaceResource> surface,double x,double y,double scale) {
    reinterpret_cast<DamageFn>(damageHook->m_original)(self,surface,x,y,scale);
    // Native damage coordinates describe the unscaled buffer. Redraw the owning
    // zoomed output without touching frame callbacks on independent outputs.
    for (auto& [name,z]:zooms) if (auto monitor=z.monitor.lock()) g_pHyprRenderer->damageMonitor(monitor);
}
// A tracker adapter avoids mutating hidden flags or window geometry during hit
// testing, and preserves normal overflow behavior when a zoom is closed.
struct FilteredTracker : Desktop::IViewStateTracker {
    const Desktop::IViewStateTracker& source;
    std::vector<PHLWINDOW> filtered;
    explicit FilteredTracker(const Desktop::IViewStateTracker& s):source(s) {}
    const std::vector<PHLWINDOW>& windows() const override { return filtered; }
    const std::vector<PHLLS>& layers() const override { return source.layers(); }
    const std::vector<PHLVIEWREF>& otherViews() const override { return source.otherViews(); }
};
PHLWINDOW windowAt(const void* self,const Vector2D& point,uint16_t flags,PHLWINDOW ignored) {
    if (zooms.empty()) return reinterpret_cast<HitFn>(windowAtHook->m_original)(self,point,flags,ignored);
    const auto monitor=monitorAt(point);
    FilteredTracker tracker{*Desktop::viewState()};
    for (const auto& w:tracker.source.windows()) if (!clipped(w,monitor)) tracker.filtered.push_back(w);
    if (tracker.filtered.size()==tracker.source.windows().size())
        return reinterpret_cast<HitFn>(windowAtHook->m_original)(self,point,flags,ignored);
    const Desktop::CViewHitTester tester{tracker};
    return reinterpret_cast<HitFn>(windowAtHook->m_original)(&tester,point,flags,ignored);
}
bool topLayerAt(PHLMONITOR monitor,const Vector2D& point) {
    if (!monitor) return false;
    Vector2D local;
    PHLLS layer;
    const auto tester=Desktop::viewState()->hitTest();
    if (tester.layerPopupSurfaceAt(point,monitor,&local,&layer) && layer && layer->m_layer>=ZWLR_LAYER_SHELL_V1_LAYER_TOP) return true;
    for (const auto level:{ZWLR_LAYER_SHELL_V1_LAYER_OVERLAY,ZWLR_LAYER_SHELL_V1_LAYER_TOP})
        if (tester.layerSurfaceAt(point,&monitor->m_layerSurfaceLayers[level],&local,&layer)) return true;
    return false;
}
PHLWINDOW appAt(PHLMONITOR monitor,const Vector2D& point) {
    const auto z=zoomFor(monitor);
    if (!z) return {};
    return Desktop::viewState()->hitTest().windowAtWorkspace(toWorld(monitor,point),z->workspace,ALLOW_FLOATING|INPUT_EXTENTS|RESERVED_EXTENTS);
}
bool forwardMotion(PHLMONITOR monitor,uint32_t time=0) {
    const auto point=g_pInputManager->getMouseCoordsInternal();
    const auto world=toWorld(monitor,point);
    const auto w=pointerButtons.empty()?appAt(monitor,point):pointerWindow;
    if (!w || !w->mapped() || !w->wlSurface() || !w->wlSurface()->resource()) {
        if (pointerButtons.empty()) {
            pointerWindow.reset(); pointerSurface.reset(); g_pSeatManager->setPointerFocus(nullptr,{});
            Desktop::focusState()->rawMonitorFocus(monitor);
        }
        return false;
    }
    const auto tester=Desktop::viewState()->hitTest();
    Vector2D local;
    auto surface=pointerSurface;
    if (w->backend().isX11()) {
        surface=w->wlSurface()->resource();
        local=world-w->position(IGeometric::GEOMETRIC_CURRENT);
    } else if (pointerButtons.empty()) surface=tester.windowSurfaceAt(world,w,local);
    else if (surface) local=tester.surfaceLocalAt(world,w,surface);
    if (!surface) {
        surface=w->wlSurface()->resource();
        local=tester.surfaceLocalAt(world,w,surface);
    }
    pointerWindow=w; pointerSurface=surface; pointerMonitor=monitor;
    if (pointerButtons.empty() && Desktop::focusState()->window()!=w)
        Desktop::focusState()->fullWindowFocus(w,Desktop::FOCUS_REASON_FFM,surface);
    g_pSeatManager->setPointerFocus(surface,local);
    g_pSeatManager->sendPointerMotion(time?time:Time::millis(Time::steadyNow()),local);
    g_pSeatManager->sendPointerFrame();
    return true;
}
void place(PHLWINDOW window,PHLMONITOR monitor,const Vector2D& world,bool tiled,const Vector2D& size,const Vector2D& ratio) {
    if (!window || !window->mapped() || !monitor) return;
    const auto workspace=monitor->m_activeSpecialWorkspace?monitor->m_activeSpecialWorkspace:monitor->m_activeWorkspace;
    if (!workspace) return;
    if (window->m_workspace!=workspace) Desktop::globalWindowController()->moveWindowToWorkspace(window,workspace);
    const auto target=window->layoutTarget();
    const auto space=target?target->space():nullptr;
    const auto algorithm=space?space->algorithm():nullptr;
    if (!algorithm) return;
    if (target->floating()==tiled) algorithm->setFloating(target,!tiled,false);
    if (tiled) {
        const auto layout=algorithm->tiledAlgo()->layoutName().value_or("");
        if (layout=="hyprscroll2d" || layout=="lua:hyprscroll2d")
            (void)algorithm->layoutMsg(std::format("dropat 0x{:x} {:.4f} {:.4f}",reinterpret_cast<uintptr_t>(window.get()),world.x,world.y));
        else { algorithm->removeTarget(target); algorithm->moveTarget(target,world); }
        algorithm->recalculate();
    } else {
        target->setPositionGlobal(CBox{world-Vector2D{size.x*ratio.x,size.y*ratio.y},size});
        target->warpPositionSize();
    }
    Desktop::focusState()->fullWindowFocus(window,Desktop::FOCUS_REASON_DESKTOP_STATE_CHANGE);
}
void beginGrab(PHLWINDOW window,PHLMONITOR monitor,uint32_t button,bool resize=false,std::optional<Layout::eRectCorner> edge=std::nullopt) {
    if (!window || !window->layoutTarget()) return;
    const auto point=toWorld(monitor,g_pInputManager->getMouseCoordsInternal());
    const auto box=window->layoutTarget()->position();
    grab={.window=window,.monitor=monitor,.ratio={(point.x-box.x)/std::max(1.,box.width),(point.y-box.y)/std::max(1.,box.height)},
          .size=box.size(),.start=point,.box=box,.tiled=!window->isFloating(),.resize=resize,.button=button};
    if (resize) grab.corner=edge.value_or(static_cast<Layout::eRectCorner>(
        (point.x<box.x+box.width/2?Layout::CORNER_LEFT:Layout::CORNER_RIGHT) |
        (point.y<box.y+box.height/2?Layout::CORNER_TOP:Layout::CORNER_BOTTOM)));
    pointerButtons.clear(); pointerWindow.reset(); pointerSurface.reset();
    g_pSeatManager->setPointerFocus(nullptr,{});
    damageAll();
}
void updateResize() {
    const auto m=grab.monitor.lock();
    const auto target=grab.window?grab.window->layoutTarget():nullptr;
    if (!target || !m) return;
    const auto point=toWorld(m,g_pInputManager->getMouseCoordsInternal());
    const auto delta=point-grab.start;
    if (grab.tiled) { g_layoutManager->resizeTarget(delta,target,grab.corner); grab.start=point; }
    else {
        auto box=grab.box;
        if (Layout::edgeLeft(grab.corner)) { box.x+=delta.x; box.width-=delta.x; }
        if (Layout::edgeRight(grab.corner)) box.width+=delta.x;
        if (Layout::edgeTop(grab.corner)) { box.y+=delta.y; box.height-=delta.y; }
        if (Layout::edgeBottom(grab.corner)) box.height+=delta.y;
        box.width=std::max(100.,box.width); box.height=std::max(60.,box.height);
        target->rememberFloatingSize(box.size()); target->setPositionGlobal(box); target->warpPositionSize();
    }
}
bool cameraModifiers() {
    const auto mods=g_pInputManager->getModsFromAllKBs();
    return (mods&Input::HL_MODIFIER_META) && (mods&Input::HL_MODIFIER_CTRL);
}
void mouseMove(Vector2D,Event::SCallbackInfo& info) {
    if (g_pSessionLockManager->isSessionLocked()) return;
    if (grab.window) { if (grab.resize) updateResize(); damageAll(); info.cancelled=true; return; }
    if (g_layoutManager->dragController()->target() || cameraModifiers()) return;
    const auto point=g_pInputManager->getMouseCoordsInternal();
    const auto monitor=pointerButtons.empty()?monitorAt(point):pointerMonitor.lock();
    if (!zoomFor(monitor) || (pointerButtons.empty() && topLayerAt(monitor,point))) return;
    forwardMotion(monitor);
    info.cancelled=true;
}
void mouseButton(IPointer::SButtonEvent event,Event::SCallbackInfo& info) {
    if (event.state==WL_POINTER_BUTTON_STATE_PRESSED) heldButtons.insert(event.button);
    else heldButtons.erase(event.button);
    if (info.cancelled || g_pSessionLockManager->isSessionLocked()) return;
    if (grab.window) {
        info.cancelled=true;
        if (event.state==WL_POINTER_BUTTON_STATE_RELEASED && event.button==grab.button) {
            const auto saved=grab;
            grab={};
            const auto point=g_pInputManager->getMouseCoordsInternal();
            const auto monitor=monitorAt(point);
            if (!saved.resize) place(saved.window,monitor,toWorld(monitor,point),saved.tiled,saved.size,saved.ratio);
            g_pInputManager->releaseAllMouseButtons();
            damageAll();
        }
        return;
    }
    if (g_layoutManager->dragController()->target() || cameraModifiers()) return;
    const auto point=g_pInputManager->getMouseCoordsInternal();
    const auto monitor=pointerButtons.empty()?monitorAt(point):pointerMonitor.lock();
    if (!zoomFor(monitor) || (pointerButtons.empty() && topLayerAt(monitor,point))) return;
    const auto mods=g_pInputManager->getModsFromAllKBs();
    if ((mods&Input::HL_MODIFIER_META) && event.state==WL_POINTER_BUTTON_STATE_PRESSED && (event.button==BTN_LEFT || event.button==BTN_RIGHT)) {
        beginGrab(appAt(monitor,point),monitor,event.button,event.button==BTN_RIGHT);
        info.cancelled=bool(grab.window);
        return;
    }
    if (!forwardMotion(monitor,event.timeMs)) return;
    if (event.state==WL_POINTER_BUTTON_STATE_PRESSED) pointerButtons.insert(event.button);
    else pointerButtons.erase(event.button);
    g_pSeatManager->sendPointerButton(event.timeMs,event.button,event.state);
    g_pSeatManager->sendPointerFrame();
    info.cancelled=true;
    if (event.state==WL_POINTER_BUTTON_STATE_RELEASED && pointerButtons.empty()) g_pInputManager->releaseAllMouseButtons();
}
bool spatialMonitor(PHLMONITOR monitor);
void layoutMessage(PHLMONITOR monitor,const std::string& message);
// One finger-scroll gesture moves a single page. High-resolution pad events
// keep arriving after the step, so further deltas wait until the fingers lift.
struct FingerPage { double x=0,y=0; bool sent=false; std::chrono::steady_clock::time_point last{}; };
FingerPage fingerPage;
void fingerPageSnap(PHLMONITOR monitor,const IPointer::SAxisEvent& event) {
    const auto now=std::chrono::steady_clock::now();
    if (fingerPage.last.time_since_epoch().count() && now-fingerPage.last>std::chrono::milliseconds(220)) fingerPage={};
    fingerPage.last=now;
    if (event.axis==WL_POINTER_AXIS_VERTICAL_SCROLL) fingerPage.y+=event.delta;
    else fingerPage.x+=event.delta;
    if (fingerPage.sent) return;
    if (std::max(std::abs(fingerPage.x),std::abs(fingerPage.y))<64) return;
    fingerPage.sent=true;
    // Same direction as Super+wheel: positive is down/right, after natural scroll.
    const char* dir=std::abs(fingerPage.y)>=std::abs(fingerPage.x)
        ?(fingerPage.y>0?"down":"up"):(fingerPage.x>0?"right":"left");
    layoutMessage(monitor,std::string("pan ")+dir);
}
void mouseAxis(IPointer::SAxisEvent event,Event::SCallbackInfo& info) {
    if (info.cancelled || g_pSessionLockManager->isSessionLocked()) return;
    const auto mods=g_pInputManager->getModsFromAllKBs();
    if ((mods&Input::HL_MODIFIER_META) && event.source==WL_POINTER_AXIS_SOURCE_WHEEL) {
        // The keybind manager forwards events within scroll_event_delay.
        // Keep running the binding, but consume every reserved Super detent,
        // including throttled ones, before it reaches the focused document.
        (void)Keybinds::mgr()->onAxisEvent(event,g_pSeatManager->m_mouse.lock());
        info.cancelled=true;
        return;
    }
    const auto monitor=monitorAt(g_pInputManager->getMouseCoordsInternal());
    // Two-finger scroll is an axis, not a swipe. While zoomed out it used to
    // scroll the shrunken app (and a touch pinch wobbled the scale). Super+
    // two fingers, or any two-finger scroll while zoomed, steps one page.
    if (event.source==WL_POINTER_AXIS_SOURCE_FINGER && spatialMonitor(monitor)
        && ((mods&Input::HL_MODIFIER_META) || zoomFor(monitor))) {
        fingerPageSnap(monitor,event);
        info.cancelled=true;
        return;
    }
    if (!zoomFor(monitor) || topLayerAt(monitor,g_pInputManager->getMouseCoordsInternal()) || !forwardMotion(monitor,event.timeMs)) return;
    // Hyprland stores wheel detents in 120ths. Wayland v8+ clients consume
    // value120 instead of legacy discrete ticks; zero loses the wheel step.
    const int32_t discrete=(event.deltaDiscrete>0)-(event.deltaDiscrete<0);
    g_pSeatManager->sendPointerAxis(event.timeMs,event.axis,event.delta,discrete,event.deltaDiscrete,event.source,event.relativeDirection);
    g_pSeatManager->sendPointerFrame();
    info.cancelled=true;
}
void beginDrag(void* self,SP<Layout::ITarget> target,eMouseBindMode mode,std::optional<Layout::eRectCorner> edge,bool exclusive) {
    // Client-side title bars use the same presentation-space grab as Super drag.
    if (target && target->window()==pointerWindow && !pointerButtons.empty()) {
        const auto monitor=pointerMonitor.lock();
        if (zoomFor(monitor) && (mode==MBIND_MOVE || mode==MBIND_RESIZE)) {
            beginGrab(target->window(),monitor,*pointerButtons.begin(),mode==MBIND_RESIZE,edge);
            return;
        }
    }
    reinterpret_cast<BeginFn>(beginDragHook->m_original)(self,target,mode,edge,exclusive);
}
bool endDrag(void* self) {
    const auto& controller=g_layoutManager->dragController();
    const auto target=controller->target();
    const auto window=target?target->window():PHLWINDOW{};
    const auto point=g_pInputManager->getMouseCoordsInternal();
    const auto monitor=monitorAt(point);
    const bool nativeDrop=window && zoomFor(monitor) && controller->mode()==MBIND_MOVE;
    const bool tiled=nativeDrop && (controller->draggingTiled() || !target->floating());
    const auto size=target?target->position().size():Vector2D{};
    const auto offset=target?point-target->position().pos():Vector2D{};
    const auto world=toWorld(monitor,point);
    const bool result=reinterpret_cast<EndFn>(endDragHook->m_original)(self);
    if (nativeDrop) {
        place(window,monitor,world,tiled,size,{offset.x/std::max(1.,size.x),offset.y/std::max(1.,size.y)});
        damageAll();
    }
    return result;
}
// Touchscreens do not emit trackpad gestures. Two fingers pan and pinch the
// spatial workspace; one finger still goes to the app under it. Fingers that
// start on a layer, the overview map or a screen edge stay with Hyprland.
struct Contact { Vector2D pos; bool blocked=false; };
std::map<int32_t,Contact> contacts;
bool touchCaptured=false, touchArmed=false, touchStartedZoomed=false, touchPinched=false;
PHLMONITORREF touchMonitor;
PHLWORKSPACE touchWorkspace;
Vector2D touchCentroid, touchStartCentroid;
double touchSpan=0, touchZoomSpan=0;
bool spatialMonitor(PHLMONITOR monitor) {
    if (!monitor || monitor->m_activeSpecialWorkspace) return false;
    const auto workspace=monitor->m_activeWorkspace;
    if (!workspace || !workspace->space() || !workspace->space()->algorithm()) return false;
    const auto& algo=workspace->space()->algorithm()->tiledAlgo();
    if (!algo) return false;
    const auto name=algo->layoutName().value_or("");
    return name=="hyprscroll2d" || name=="lua:hyprscroll2d";
}
PHLMONITOR touchOutput(const SP<ITouch>& device) {
    if (device && !device->m_boundOutput.empty())
        if (const auto named=State::monitorState()->query().name(device->m_boundOutput).run()) return named;
    return Desktop::focusState()->monitor();
}
void layoutMessage(PHLMONITOR monitor,const std::string& message) {
    if (!monitor || !monitor->m_activeWorkspace || !monitor->m_activeWorkspace->space()) return;
    const auto algorithm=monitor->m_activeWorkspace->space()->algorithm();
    if (algorithm) (void)algorithm->layoutMsg(message);
}
bool safeMonitorName(const std::string& name) {
    return !name.empty() && name.find_first_not_of("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789_:.-")==std::string::npos;
}
std::string zoomStateJson() {
    std::string body="{";
    bool first=true;
    for (const auto& [name,z]:zooms) {
        if (!safeMonitorName(name)) continue;
        if (!first) body+=",";
        first=false;
        body+=std::format("\"{}\":{:.6f}",name,z.factor);
    }
    return body+"}";
}
void endTouchGesture();
void publishZoomFile() {
    const auto runtime=getenv("XDG_RUNTIME_DIR");
    if (!runtime || !*runtime) return;
    const auto path=std::string(runtime)+"/kingstra-native-zoom.json";
    const auto tmp=path+".tmp";
    if (FILE* file=std::fopen(tmp.c_str(),"w")) {
        std::fputs((zoomStateJson()+"\n").c_str(),file);
        std::fclose(file);
        std::rename(tmp.c_str(),path.c_str());
    }
}
void closeStaleZooms() {
    std::vector<std::string> drop;
    for (const auto& [name,z]:zooms) {
        const auto monitor=z.monitor.lock();
        if (!monitor || monitor->m_activeWorkspace!=z.workspace) drop.push_back(name);
    }
    if (drop.empty()) return;
    bool gestureDropped=false;
    for (const auto& name:drop) {
        if (grab.monitor && grab.monitor->m_name==name) grab={};
        if (const auto monitor=touchMonitor.lock(); monitor && monitor->m_name==name) gestureDropped=true;
        zooms.erase(name);
    }
    if (gestureDropped) endTouchGesture();
    publishZoomFile();
    damageAll();
}
void scaleTouchZoom(PHLMONITOR monitor,double ratio) {
    if (!monitor || !(ratio>0) || std::abs(ratio-1)<0.004) return;
    if (ratio<1 && !zoomFor(monitor)) {
        const auto workspace=monitor->m_activeWorkspace;
        if (!workspace) return;
        zooms[monitor->m_name]={monitor,workspace,1};
    }
    auto z=zoomFor(monitor);
    if (!z) return;
    z->factor=std::clamp(z->factor*ratio,0.25,1.0);
    if (z->factor>=0.97) zooms.erase(monitor->m_name);
    publishZoomFile();
    damageAll();
}
Vector2D touchCentroidPx(PHLMONITOR monitor) {
    Vector2D sum;
    int count=0;
    for (const auto& [id,contact]:contacts) { sum+=contact.pos; ++count; }
    if (!count || !monitor) return {};
    const double x=sum.x/count, y=sum.y/count;
    return monitor->m_position+Vector2D{x*monitor->m_size.x,y*monitor->m_size.y};
}
double touchSpanPx(PHLMONITOR monitor) {
    if (contacts.size()<2 || !monitor) return 0;
    auto it=contacts.begin();
    const auto a=it->second.pos;
    const auto b=(++it)->second.pos;
    return std::hypot((a.x-b.x)*monitor->m_size.x,(a.y-b.y)*monitor->m_size.y);
}
void endTouchGesture() {
    touchArmed=false;
    if (touchCaptured && touchStartedZoomed && !touchPinched) {
        const auto travel=touchCentroid-touchStartCentroid;
        if (std::max(std::abs(travel.x),std::abs(travel.y))>=48 && touchWorkspace && touchWorkspace->space() && touchWorkspace->space()->algorithm()) {
            // Fingers drag the canvas: down reveals the page above.
            const char* dir=std::abs(travel.y)>=std::abs(travel.x)
                ?(travel.y>0?"up":"down"):(travel.x>0?"left":"right");
            (void)touchWorkspace->space()->algorithm()->layoutMsg(std::string("pan ")+dir);
        }
    } else if (touchCaptured) {
        if (touchWorkspace && touchWorkspace->space() && touchWorkspace->space()->algorithm())
            (void)touchWorkspace->space()->algorithm()->layoutMsg("dragend");
    }
    touchCaptured=false;
    touchStartedZoomed=false;
    touchPinched=false;
    touchWorkspace.reset();
    touchMonitor.reset();
}
bool touchBlocked(PHLMONITOR monitor,const Vector2D& pos) {
    if (!monitor || g_pSessionLockManager->isSessionLocked() || !spatialMonitor(monitor)) return true;
    const double marginX=28.0/std::max(1.0,monitor->m_size.x), marginY=28.0/std::max(1.0,monitor->m_size.y);
    if (pos.x<marginX || pos.y<marginY || pos.x>1-marginX || pos.y>1-marginY) return true;
    const auto global=monitor->m_position+pos*monitor->m_size;
    if (topLayerAt(monitor,global)) return true;
    const auto window=Desktop::viewState()->hitTest().windowAt(global,ALLOW_FLOATING|INPUT_EXTENTS|RESERVED_EXTENTS);
    return window && window->metadata().title()=="Kingstra Werkvlak";
}
void beginTouchGesture(PHLMONITOR monitor) {
    g_pSeatManager->sendTouchCancel();
    touchCaptured=true;
    touchMonitor=monitor;
    touchWorkspace=monitor?monitor->m_activeWorkspace:nullptr;
    // Arm recorded the span and centroid before this gesture crossed the
    // threshold. Keep that baseline so the opening pinch still counts and a
    // one-percent wobble does not multiply the zoom on every frame.
    const double armedSpan=touchSpan;
    touchStartCentroid=touchCentroid;
    touchCentroid=touchCentroidPx(monitor);
    touchSpan=touchSpanPx(monitor);
    touchZoomSpan=armedSpan>24?armedSpan:std::max(1.0,touchSpan);
    touchStartedZoomed=zoomFor(monitor)!=nullptr;
    touchPinched=false;
    if (!touchStartedZoomed) layoutMessage(monitor,"dragstart");
    damageAll();
}
void updateTouchGesture(PHLMONITOR monitor) {
    const auto centroid=touchCentroidPx(monitor);
    const auto span=touchSpanPx(monitor);
    const auto delta=centroid-touchCentroid;
    // Already zoomed: free panning fights the scale and looks like the page
    // slides under the fingers. A real pinch still zooms; a swipe snaps later.
    if (!touchStartedZoomed) {
        const auto z=zoomFor(monitor);
        const double factor=z&&z->factor>0?z->factor:1;
        if (std::hypot(delta.x,delta.y)>=0.4 && std::hypot(delta.x,delta.y)<4000)
            layoutMessage(monitor,std::format("panby {:.4f} {:.4f}",-delta.x/factor,-delta.y/factor));
    }
    if (touchZoomSpan>24 && span>24) {
        const double ratio=span/touchZoomSpan;
        if (ratio<=0.92 || ratio>=1.08) {
            scaleTouchZoom(monitor,std::clamp(ratio,0.5,2.0));
            touchZoomSpan=span;
            touchPinched=true;
        }
    }
    touchCentroid=centroid;
    touchSpan=span;
    damageAll();
}
bool touchEligible() {
    if (contacts.size()<2) return false;
    for (const auto& [id,contact]:contacts) if (contact.blocked) return false;
    return true;
}
void touchDown(ITouch::SDownEvent event,Event::SCallbackInfo& info) {
    if (g_pSessionLockManager->isSessionLocked()) return;
    const auto monitor=touchOutput(event.device);
    contacts[event.touchID]={event.pos,touchBlocked(monitor,event.pos)};
    if (touchCaptured) {
        info.cancelled=true;
        if (monitor) touchMonitor=monitor;
        return;
    }
    touchArmed=false;
}
void touchMove(ITouch::SMotionEvent event,Event::SCallbackInfo& info) {
    auto found=contacts.find(event.touchID);
    if (found==contacts.end()) return;
    found->second.pos=event.pos;
    auto monitor=touchMonitor.lock();
    if (!monitor) monitor=Desktop::focusState()->monitor();
    if (touchCaptured) {
        info.cancelled=true;
        if (monitor && spatialMonitor(monitor)) updateTouchGesture(monitor);
        else endTouchGesture();
        return;
    }
    if (!touchEligible() || !monitor) { touchArmed=false; return; }
    if (!touchArmed) {
        touchArmed=true;
        touchCentroid=touchCentroidPx(monitor);
        touchSpan=std::max(1.0,touchSpanPx(monitor));
        return;
    }
    const auto now=touchCentroidPx(monitor);
    const auto travel=std::hypot(now.x-touchCentroid.x,now.y-touchCentroid.y);
    const auto span=touchSpanPx(monitor);
    if (travel<16 && std::abs(span/touchSpan-1)<=0.12) return;
    beginTouchGesture(monitor);
    info.cancelled=true;
}
void touchUp(ITouch::SUpEvent event,Event::SCallbackInfo& info) {
    contacts.erase(event.touchID);
    if (!touchCaptured) {
        if (contacts.size()<2) touchArmed=false;
        return;
    }
    info.cancelled=true;
    if (contacts.size()<2) endTouchGesture();
}
void touchCancel(ITouch::SCancelEvent event,Event::SCallbackInfo&) {
    contacts.erase(event.touchID);
    if (touchCaptured && contacts.size()<2) endTouchGesture();
}
std::pair<std::string,std::string> split(const std::string& text) {
    const auto i=text.find(' ');
    return i==std::string::npos?std::pair{text,std::string{}}:std::pair{text.substr(0,i),text.substr(i+1)};
}
int dispatch(lua_State* lua) {
    const std::string action=luaL_checkstring(lua,1),arg=luaL_optstring(lua,2,"");
    const auto [command,name]=split(arg);
    if (action=="overview") {
        if (command=="close") {
            if (name=="all" || (grab.monitor && grab.monitor->m_name==name)) grab={};
            if (name=="all") zooms.clear(); else zooms.erase(name);
            pointerButtons.clear(); pointerWindow.reset(); pointerSurface.reset();
        } else if (command=="open") {
            for (const auto& m:State::monitorState()->monitors())
                if (m->m_name==name) zooms[name]={m,m->m_activeWorkspace,1};
        }
    } else if (action=="canvas") {
        const auto monitor=monitorAt(g_pInputManager->getMouseCoordsInternal());
        if (auto z=zoomFor(monitor);z && (arg=="zoom out" || arg=="zoom in"))
            z->factor=std::clamp(z->factor*(arg=="zoom in"?1.12:1/1.12),.25,1.);
    }
    damageAll();
    return 0;
}
std::string status() {
    std::string screens;
    for (auto& [name,z]:zooms) {
        const auto m=z.monitor.lock();
        if (!m) continue;
        const auto size=m->m_size/z.factor;
        const auto pos=m->m_position+(m->m_size-size)/2;
        if (!screens.empty()) screens+=",";
        screens+=std::format("{{\"monitor\":\"{}\",\"zoom\":{:.6f},\"navigating\":false,\"closing\":false,\"view\":[{:.6f},{:.6f},{:.6f},{:.6f}]}}",
            name,z.factor,pos.x,pos.y,size.x,size.y);
    }
    return "{\"linked\":false,\"leader\":\"\",\"screens\":["+screens+"],\"fullscreen\":[],\"filled\":[],\"selected\":\"\"}";
}
void hook(CFunctionHook*& target,const char* symbol,void* callback) {
    const auto address=dlsym(RTLD_DEFAULT,symbol);
    if (!address) throw std::runtime_error(std::string("Missing Hyprland 0.57 export: ")+symbol);
    target=HyprlandAPI::createFunctionHook(handle,address,callback);
    if (!target || !target->hook()) throw std::runtime_error(std::string("Cannot hook ")+symbol);
}
} // namespace

APICALL EXPORT std::string PLUGIN_API_VERSION() { return HYPRLAND_API_VERSION; }
APICALL EXPORT PLUGIN_DESCRIPTION_INFO PLUGIN_INIT(HANDLE owner) {
    handle=owner;
    if (std::string_view{__hyprland_api_get_hash()}!=__hyprland_api_get_client_hash()) throw std::runtime_error("Kingstra zoom: Hyprland ABI mismatch");
    hook(windowsHook,renderWindowsSymbol,reinterpret_cast<void*>(windows));
    hook(fullscreenHook,renderFullscreenSymbol,reinterpret_cast<void*>(fullscreen));
    hook(shouldRenderHook,shouldRenderSymbol,reinterpret_cast<void*>(renderable));
    hook(windowAtHook,windowAtSymbol,reinterpret_cast<void*>(windowAt));
    hook(damageHook,damageSurfaceSymbol,reinterpret_cast<void*>(damageSurface));
    hook(beginDragHook,beginDragSymbol,reinterpret_cast<void*>(beginDrag));
    hook(endDragHook,endDragSymbol,reinterpret_cast<void*>(endDrag));
    hook(textureHook,drawTextureSymbol,reinterpret_cast<void*>(drawTexture));
    HyprlandAPI::addLuaFunction(handle,"spatialoverview","_dispatch",dispatch);
    HyprlandAPI::addLuaFunction(handle,"spatialoverview","_backend",[](lua_State* l) { lua_pushstring(l,"kingstra-0.57"); return 1; });
    HyprlandAPI::addLuaFunction(handle,"spatialoverview","_button_down",[](lua_State* l) {
        lua_pushboolean(l,heldButtons.contains(static_cast<uint32_t>(luaL_checkinteger(l,1)))); return 1;
    });
    HyprlandAPI::addLuaFunction(handle,"spatialoverview","_zoom",[](lua_State* l) {
        const auto zoom=zoomFor(monitorAt(g_pInputManager->getMouseCoordsInternal()));
        lua_pushnumber(l,zoom?zoom->factor:1); return 1;
    });
    HyprlandAPI::addLuaFunction(handle,"spatialoverview","_state_json",[](lua_State* l) {
        lua_pushstring(l,zoomStateJson().c_str()); return 1;
    });
    HyprlandAPI::addConfigValueV2(handle,makeShared<Config::Values::CBoolValue>("plugin:spatialoverview:canvas:hover_focus","Focus follows the mouse while zoomed",true));
    HyprlandAPI::registerHyprCtlCommand(handle,{.name="spatialoverview",.handler=[](const auto&) { return IPC::Socket1::SResponse{status()}; }});
    listeners.push_back(Event::bus()->m_events.input.mouse.move.listen(mouseMove));
    listeners.push_back(Event::bus()->m_events.input.mouse.button.listen(mouseButton));
    listeners.push_back(Event::bus()->m_events.input.mouse.axis.listen(mouseAxis));
    listeners.push_back(Event::bus()->m_events.input.touch.down.listen(touchDown));
    listeners.push_back(Event::bus()->m_events.input.touch.motion.listen(touchMove));
    listeners.push_back(Event::bus()->m_events.input.touch.up.listen(touchUp));
    listeners.push_back(Event::bus()->m_events.input.touch.cancel.listen(touchCancel));
    listeners.push_back(Event::bus()->m_events.workspace.active.listen([](PHLWORKSPACE){ closeStaleZooms(); }));
    return {"spatialoverview","Kingstra native workspace zoom for Hyprland 0.57","Kingstra","0.57.0"};
}
APICALL EXPORT void PLUGIN_EXIT() {
    listeners.clear(); zooms.clear(); grab={}; pointerButtons.clear(); heldButtons.clear(); pointerWindow.reset(); pointerSurface.reset();
    contacts.clear(); touchCaptured=false; touchArmed=false; touchStartedZoomed=false; touchPinched=false; touchMonitor.reset(); touchWorkspace.reset(); fingerPage={};
    damageAll();
}
