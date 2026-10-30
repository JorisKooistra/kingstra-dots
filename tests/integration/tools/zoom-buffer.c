// One translucent primary surface, unlike GTK's optional subsurface offloading.
#define _GNU_SOURCE
#include <wayland-client.h>
#include "xdg-shell-client-protocol.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <unistd.h>

static struct wl_compositor *compositor;
static struct wl_shm *shm;
static struct xdg_wm_base *wm;
static struct wl_surface *surface;
static int width=640,height=400,running=1;
static void ping(void *data,struct xdg_wm_base *base,uint32_t serial) { xdg_wm_base_pong(base,serial); }
static const struct xdg_wm_base_listener wm_listener={.ping=ping};
static void global(void *data,struct wl_registry *registry,uint32_t name,const char *interface,uint32_t version) {
    if (!strcmp(interface,"wl_compositor")) compositor=wl_registry_bind(registry,name,&wl_compositor_interface,4);
    else if (!strcmp(interface,"wl_shm")) shm=wl_registry_bind(registry,name,&wl_shm_interface,1);
    else if (!strcmp(interface,"xdg_wm_base")) {
        wm=wl_registry_bind(registry,name,&xdg_wm_base_interface,1);
        xdg_wm_base_add_listener(wm,&wm_listener,NULL);
    }
}
static void removed(void *data,struct wl_registry *registry,uint32_t name) {}
static const struct wl_registry_listener registry_listener={global,removed};
static void released(void *data,struct wl_buffer *buffer) { wl_buffer_destroy(buffer); }
static const struct wl_buffer_listener buffer_listener={.release=released};
static void configured(void *data,struct xdg_surface *xdg,uint32_t serial) {
    xdg_surface_ack_configure(xdg,serial);
    const size_t length=(size_t)width*height*4;
    int fd=memfd_create("kingstra-zoom-buffer",MFD_CLOEXEC);
    if (fd<0 || ftruncate(fd,length)<0) exit(2);
    uint32_t *pixels=mmap(NULL,length,PROT_READ|PROT_WRITE,MAP_SHARED,fd,0);
    if (pixels==MAP_FAILED) exit(2);
    // Premultiplied blue, with real per-pixel alpha and no opaque region.
    for (size_t i=0;i<length/4;i++) pixels[i]=0xe02040d0;
    struct wl_shm_pool *pool=wl_shm_create_pool(shm,fd,length);
    struct wl_buffer *buffer=wl_shm_pool_create_buffer(pool,0,width,height,width*4,WL_SHM_FORMAT_ARGB8888);
    wl_shm_pool_destroy(pool);munmap(pixels,length);close(fd);
    wl_buffer_add_listener(buffer,&buffer_listener,NULL);
    wl_surface_attach(surface,buffer,0,0);
    wl_surface_damage(surface,0,0,width,height);
    wl_surface_commit(surface);
}
static const struct xdg_surface_listener surface_listener={.configure=configured};
static void sized(void *data,struct xdg_toplevel *top,int32_t w,int32_t h,struct wl_array *states) {
    if (w>0) width=w;
    if (h>0) height=h;
}
static void closed(void *data,struct xdg_toplevel *top) { running=0; }
static const struct xdg_toplevel_listener top_listener={.configure=sized,.close=closed};
int main(void) {
    struct wl_display *display=wl_display_connect(NULL);
    if (!display) return 1;
    struct wl_registry *registry=wl_display_get_registry(display);
    wl_registry_add_listener(registry,&registry_listener,NULL);
    wl_display_roundtrip(display);
    if (!compositor || !shm || !wm) return 1;
    surface=wl_compositor_create_surface(compositor);
    struct xdg_surface *xdg=xdg_wm_base_get_xdg_surface(wm,surface);
    xdg_surface_add_listener(xdg,&surface_listener,NULL);
    struct xdg_toplevel *top=xdg_surface_get_toplevel(xdg);
    xdg_toplevel_add_listener(top,&top_listener,NULL);
    xdg_toplevel_set_title(top,"zoom-blur");
    xdg_toplevel_set_app_id(top,"dev.kingstra.zoom-buffer");
    wl_surface_commit(surface);
    while (running && wl_display_dispatch(display)>=0) {}
    wl_display_disconnect(display);
    return 0;
}
