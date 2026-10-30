The virtual pointer fixture and Wayland protocol come from
[Phantomat](https://github.com/kaolti/phantomat/tree/a1e8a0806541640d01503ac861a8a39548de8724/tests/tools).
The C helper has an added wheel command. Its upstream BSD-3-Clause license is in
`config/hypr/native-zoom/LICENSE.upstream`; the XML preserves its own copyright
and permission notice. These tools run only inside the disposable test compositor.

`zoom-buffer.c` is a Kingstra test client with one translucent primary SHM buffer.
It catches blur clipping that GTK subsurface rendering can hide. Its xdg-shell
bindings are generated during the test from the installed `wayland-protocols`.
