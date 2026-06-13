# Simple Diary

나만 보는 macOS 네이티브 일기장. SwiftUI로 만든 단일 창 앱이다.
(영어 이름 Simple Diary로 통일, 한국어 이름 없음. 프로젝트 코드명/데이터 폴더는 ilgi 유지.)

```
┌────────────┬──────────────────┐
│  잔디 캘린더  │                  │
├────────────┤   글 작성 (오늘)    │
│  최근 글     │                  │
│  (잠금)     │                  │
└────────────┴──────────────────┘
```

## 기능

- **바로 쓰기** — 앱을 켜면 우측 에디터에 오늘 일기가 바로 열려 있다(자동 포커스). 타이핑하면 0.6초 디바운스로 자동 저장. 하루에 한 개의 일기. 다른 날을 보다가도 ⌘N 또는 "오늘로" 버튼으로 복귀.
- **잔디 캘린더** — 좌측 상단 월 캘린더에 일기 쓴 날이 깃허브 잔디처럼 표시된다(글자 수가 많을수록 진해짐: 100/300/700자 기준 4단계). ◀ ▶로 달 이동, 달 제목 클릭 시 이번 달로 복귀. 날짜를 클릭하면 그날 일기가 우측에 열린다(지난 일기는 Touch ID 인증).
- **지난 일기 잠금** — 좌측 하단 최근 글 목록은 기본 잠김. "보기"를 누르면 **Touch ID(지문)** 인증을 통과해야 보인다(지문 실패/미지원 시 Mac 로그인 암호로 대체). 잠금 해제 상태는 저장되지 않아 앱을 다시 켜면 항상 잠긴다.
- **내보내기** — 모든 일기를 Markdown / 일반 텍스트 / JSON 한 파일로 내보낸다. 툴바의 공유 버튼 또는 파일 메뉴(⌘E = Markdown).
- **색 테마** — 설정(⌘,)에서 7가지 테마 선택: **Claude(기본, 테라코타 #D97757)**·Leaf·Tangerine·Ocean·Lavender·Sakura·Graphite. 잔디·하이라이트·버튼·커서가 모두 따라 바뀐다. iOS는 캘린더 시트 하단에서 변경.
- **매일 자동 열기** — 설정(⌘,)에서 켜면 매일 정해진 시간에 앱이 자동으로 열린다. launchd 로그인 에이전트(`~/Library/LaunchAgents/com.hanbin.ilgi.autoopen.plist`)로 동작해 재부팅해도 유지되고, Mac이 자던 시간의 예약은 깨어날 때 처리된다. 끄면 에이전트도 제거된다.
- **Day One 가져오기** — 파일 메뉴 → "Day One에서 가져오기…"에서 Day One이 내보낸 JSON(또는 JSON이 든 ZIP)을 선택하면 일기로 변환된다.
  - 항목의 타임존 기준 현지 날짜로 분류 (자정 넘어 쓴 글도 올바른 날짜로)
  - 하루에 여러 항목이면 `[21:09]` 시간 라벨을 붙여 한 파일로 병합
  - Day One의 마크다운 이스케이프(`\.` 등) 복원, 사진/동영상 첨부는 `(사진)` 표시로 대체
  - 이미 일기가 있는 날은 건너뛰므로 여러 번 실행해도 안전. 실행 전 기존 일기를 `Ilgi/backup/`에 자동 백업.

## 빌드 & 실행

```sh
./build.sh
open "build/Simple Diary.app"
```

Xcode 없이 Command Line Tools만으로 빌드된다. 응용 프로그램 폴더에 설치하려면:

```sh
cp -R "build/Simple Diary.app" /Applications/
```

데스크탑 바로가기(심볼릭 링크)는 이렇게 만든다 (빌드를 다시 해도 링크는 유효):

```sh
ln -sfn "$(pwd)/build/Simple Diary.app" "$HOME/Desktop/Simple Diary.app"
```

앱 아이콘(초록 잎사귀)은 빌드 때 `scripts/make_icon.swift`가 그린다.
디자인을 바꾼 뒤에는 `build/AppIcon.icns`를 지우고 다시 빌드해야 반영된다.

## 단축키

| 키 | 동작 |
|---|---|
| ⌘N | 오늘 일기로 이동 |
| ⌘E | Markdown으로 내보내기 |
| ⌘Q | 종료 (창을 닫아도 종료) |

## 데이터

일기는 기본적으로 iCloud Drive의 `Simple Diary` 폴더에 저장된다 (Finder → iCloud Drive → Simple Diary):

```
~/Library/Mobile Documents/com~apple~CloudDocs/Simple Diary/entries/2026-06-12.md
```

날짜별 평문 Markdown 파일이라 앱 없이도 읽을 수 있고, iCloud Drive를 통해 다른 기기와 자동 동기화된다.

- **저장 폴더 변경** — 설정(⌘,) → 저장 위치 → "폴더 변경…"에서 원하는 폴더를 직접 지정할 수 있다(지정한 폴더에 `.md`가 바로 저장됨). "기본 위치(iCloud)로 되돌리기"로 복귀. 폴더를 바꾸면 기존 일기도 함께 옮겨진다.
- **기본/폴백** — 지정하지 않으면 iCloud Drive의 `Simple Diary/entries`. iCloud가 꺼진 Mac에서는 `~/Library/Application Support/Simple Diary/entries/`로 폴백한다.
- **자동 이전** — 예전 `Ilgi` 폴더(iCloud·로컬)에 일기가 있으면 첫 실행 때 새 `Simple Diary` 폴더로 자동으로 옮긴다.

- Touch ID 잠금은 **앱 안에서의 열람**을 막는 것이다. 파일 자체는 Finder/iCloud Drive에서 보이므로, Mac 잠금과 iCloud 계정 보안이 실제 방어선이다.
- 두 기기에서 같은 날을 동시에 고치면 iCloud가 "2026-06-12 2.md" 같은 충돌 사본을 만들 수 있는데, 앱은 날짜 형식이 아닌 파일명을 무시한다(내용은 Finder에서 확인 가능).
- 내용을 전부 지운 채 다른 날로 이동하거나 앱을 닫으면 그날 파일도 삭제된다. 목록에서 우클릭 → 삭제도 가능.

개발/테스트용으로 `ILGI_DATA_DIR` 환경 변수로 저장 위치를 바꿀 수 있다:

```sh
ILGI_DATA_DIR=/tmp/ilgi-test ./build/Simple Diary.app/Contents/MacOS/Ilgi
```

## 구조

```
Sources/Ilgi/
  IlgiApp.swift      앱 진입점, 메뉴 커맨드, 종료 시 저장 플러시
  DiaryStore.swift   파일 저장소(로드/디바운스 저장/삭제/내보내기/가져오기 UI)
  DayOneImporter.swift Day One JSON/ZIP → 날짜별 .md 변환 (순수 로직)
  BiometricGate.swift Touch ID 인증 게이트
  ContentView.swift  좌/우 분할 컨테이너 + 툴바
  SidebarView.swift  좌측: 캘린더 + 잠긴 최근 글 목록
  CalendarView.swift 잔디 스타일 월 캘린더
  EditorView.swift   우측: 상시 에디터(자동 저장, 글자 수)
  Formatters.swift   날짜 포맷터
  Theme.swift        포인트 컬러
scripts/make_icon.swift  앱 아이콘 렌더링(빌드 시 자동 실행)
packaging/Info.plist     앱 번들 메타데이터
build.sh                 swift build → .app 번들 → 아이콘 → 서명
site/                    소개 랜딩 페이지 (정적, Vercel 배포용)
```

## iOS 앱 (ios/)

Mac과 **같은 iCloud Drive 폴더**를 읽고 쓰는 iPhone 앱. 잔디 캘린더와 Face ID 잠금 동일.
iOS는 샌드박스 때문에 첫 실행 때 앱 안에서 "iCloud 폴더 연결하기"로 `iCloud Drive → Ilgi` 폴더를
한 번 선택해야 한다(보안 북마크로 기억, entries 하위 폴더 자동 인식). 파일 접근은 NSFileCoordinator 사용.

빌드 (풀 Xcode 필요, XcodeGen으로 프로젝트 생성):

```sh
cd ios
xcodegen generate
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  xcodebuild -project IlgiMobile.xcodeproj -scheme IlgiMobile \
  -destination 'generic/platform=iOS Simulator' build CODE_SIGNING_ALLOWED=NO
```

iPhone에 설치:

1. iPhone 연결(USB) → "이 컴퓨터를 신뢰" → 설정 → 개인정보 보호 및 보안 → **개발자 모드** 켜고 재부팅
2. `open ios/IlgiMobile.xcodeproj` → Xcode Settings → Accounts에 Apple ID 추가
3. 타깃 IlgiMobile → Signing & Capabilities → Team에 본인(Personal Team) 선택
4. 상단 기기에서 iPhone 선택 → ▶ Run
5. iPhone에서 설정 → 일반 → VPN 및 기기 관리 → 개발자 앱 **신뢰**
6. 무료 Apple ID는 서명이 **7일 후 만료** → Xcode에서 다시 Run하면 재설치(일기는 iCloud에 있으니 안전)

시뮬레이터 테스트: `SIMCTL_CHILD_ILGI_USE_LOCAL=1`로 실행하면 iCloud 연결 없이 로컬 Documents를 쓴다.

## 소개 사이트

**https://ilgi-diary.vercel.app** — `site/`의 정적 랜딩 페이지가 Vercel 프로젝트 `ilgi-diary`로 배포된다. 앱 zip(`site/ilgi.zip`)과 아이콘은 빌드 산출물에서 복사된다:

```sh
# 앱을 다시 빌드한 뒤 배포용 DMG 갱신 (site/SimpleDiary.dmg)
./build.sh && ./make_dmg.sh

# 로컬 미리보기
python3 -m http.server 4173 --directory site

# Vercel 배포 (최초 1회 vercel login 필요)
cd site && vercel deploy --prod --yes
```

> 배포 파일은 `.dmg`(드래그-투-Applications)다. Apple 공증을 안 했으므로 Chrome의
> "uncommon file" 경고와 macOS Gatekeeper 경고가 뜰 수 있다 — 완전 제거하려면
> Apple Developer($99/년) 공증이 필요하다. 그 전까지 받는 쪽은 Chrome에서 유지(Keep),
> 첫 실행 시 우클릭 → 열기로 통과한다.
