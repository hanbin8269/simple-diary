# dmgbuild config — Simple Diary install-window layout
import os.path

app = os.path.abspath("build/Simple Diary.app")
appname = os.path.basename(app)

# Output format: compressed read-only
format = "UDZO"

# Bundled items + Applications symlink
files = [app]
symlinks = {"Applications": "/Applications"}

# Volume icon of the mounted disk = the app icon (leaf)
badge_icon = os.path.abspath("build/AppIcon.icns")

# Window/icon layout (matches the 640x400 background design coordinates)
background = os.path.abspath("build/dmg-bg.tiff")
window_rect = ((360, 220), (640, 400))
default_view = "icon-view"
icon_size = 128
text_size = 13

icon_locations = {
    appname: (170, 210),
    "Applications": (470, 210),
}

show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
