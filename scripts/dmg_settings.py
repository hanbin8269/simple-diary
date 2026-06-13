# dmgbuild 설정 — Simple Diary 설치 창 레이아웃
import os.path

app = os.path.abspath("build/Simple Diary.app")
appname = os.path.basename(app)

# 출력 형식: 압축 읽기전용
format = "UDZO"

# 담을 항목 + Applications 심볼릭 링크
files = [app]
symlinks = {"Applications": "/Applications"}

# 마운트된 디스크의 볼륨 아이콘 = 앱 아이콘(잎사귀)
badge_icon = os.path.abspath("build/AppIcon.icns")

# 창/아이콘 배치 (배경 디자인 좌표 640x400과 일치)
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
