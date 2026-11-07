import QtQuick
import QtMultimedia

Window {
    id: win
    width: 1280; height: 760
    minimumWidth: 1060; minimumHeight: 520
    visible: true
    color: "#07080C"
    flags: Qt.Window | Qt.FramelessWindowHint | (cfgGet("onTop") ? Qt.WindowStaysOnTopHint : 0)
    title: fileName === "" ? "Player 64X" : fileName + " - Player 64X"

    // ---- 색상 ----
    readonly property color cAccent: "#4DA3FF"
    readonly property color cInk: "#ECEEF4"
    readonly property color cDim: "#8F95A6"
    readonly property color cPanel: "#E0101218"
    readonly property color cLine: "#26FFFFFF"
    readonly property color cHover: "#24FFFFFF"

    // ---- 상태 ----
    property string fileName: ""
    readonly property bool fs: visibility === Window.FullScreen
    property bool prevMax: false
    property bool chrome: true
    property real zoom: 1
    property real panX: 0
    property real panY: 0
    property int rot: 0
    property bool flipped: false
    property int aspectIdx: 0
    property int speedIdx: 4
    property real loopA: -1             // 구간 반복 (ms)
    property real loopB: -1
    readonly property bool loopOn: loopA >= 0 && loopB > loopA
    // ---- 화질 개선 ----
    property bool qualityOpen: false
    property bool enhanceOn: false      // GPU 선명화
    property real fxSharp: 0.5
    property real fxDenoise: 0.15
    property real fxContrast: 1.0
    property real fxSaturation: 1.0
    property bool aiOn: false           // 실시간 AI 업스케일
    property int aiModel: 0             // 0 실사, 1 애니
    property bool aiShow: false         // AI 프레임이 실제로 화면에 나오는 중

    property bool ctxOpen: false        // 오른쪽 버튼 메뉴
    property real ctxX: 0
    property real ctxY: 0
    property bool helpOpen: false
    property int helpTab: 0             // 0 사용 설명서, 1 단축키 설정
    property string capId: ""           // 단축키 입력 대기 중인 동작
    property var keymap: ({})           // 동작 id -> 키 문자열
    property string errorText: ""
    readonly property var aspects: [["원본", 0], ["16:9", 16 / 9], ["21:9", 21 / 9], ["32:9", 32 / 9], ["4:3", 4 / 3], ["꽉 채우기", -1]]
    readonly property var speeds: [0.1, 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 3.0, 4.0]

    // ---- 단축키 정의 (id, 이름, 기본 키) ----
    readonly property var actionDefs: [
        { id: "playPause", label: "재생 / 일시정지", key: "Space" },
        { id: "back5", label: "짧게 뒤로 (설정에서 초 지정)", key: "Left" },
        { id: "fwd5", label: "짧게 앞으로", key: "Right" },
        { id: "back30", label: "길게 뒤로", key: "Shift+Left" },
        { id: "fwd30", label: "길게 앞으로", key: "Shift+Right" },
        { id: "volUp", label: "볼륨 올리기", key: "Up" },
        { id: "volDown", label: "볼륨 내리기", key: "Down" },
        { id: "fullscreen", label: "전체화면 (화면 크게)", key: "Enter" },
        { id: "capture", label: "현재 화면 캡처 (원본 크기)", key: "C" },
        { id: "quality", label: "화질 개선 메뉴", key: "Q" },
        { id: "enhance", label: "GPU 선명화 켜기/끄기", key: "E" },
        { id: "aiToggle", label: "실시간 AI 화질 켜기/끄기", key: "I" },
        { id: "aiCapture", label: "AI 캡처 (장면을 AI 로 키워 저장)", key: "Shift+C" },
        { id: "zoomIn", label: "확대", key: "+" },
        { id: "zoomOut", label: "축소", key: "-" },
        { id: "zoomReset", label: "확대 · 이동 초기화", key: "0" },
        { id: "panLeft", label: "영상 왼쪽으로 밀기", key: "Ctrl+Left" },
        { id: "panRight", label: "영상 오른쪽으로 밀기", key: "Ctrl+Right" },
        { id: "panUp", label: "영상 위로 밀기", key: "Ctrl+Up" },
        { id: "panDown", label: "영상 아래로 밀기", key: "Ctrl+Down" },
        { id: "rotate", label: "90° 회전 (옆으로 보기)", key: "R" },
        { id: "flip", label: "좌우반전", key: "H" },
        { id: "aspect", label: "화면 비율 바꾸기", key: "A" },
        { id: "speedDown", label: "재생 속도 느리게", key: "[" },
        { id: "speedUp", label: "재생 속도 빠르게", key: "]" },
        { id: "slowMo", label: "슬로우 모션 (0.5x → 0.25x → 0.1x → 보통)", key: "Z" },
        { id: "abLoop", label: "구간 반복 (A → B → 해제)", key: "B" },
        { id: "next", label: "다음 영상", key: "N" },
        { id: "prev", label: "이전 영상", key: "P" },
        { id: "playlist", label: "재생목록 열기/닫기", key: "T" },
        { id: "open", label: "파일 열기", key: "O" },
        { id: "subMenu", label: "자막 메뉴", key: "S" },
        { id: "liveCaps", label: "실시간 자동 자막 켜기", key: "L" },
        { id: "subEarlier", label: "자막 0.5초 빠르게", key: "," },
        { id: "subLater", label: "자막 0.5초 늦게", key: "." },
        { id: "panelBigger", label: "조작 패널 크게", key: "Ctrl+]" },
        { id: "panelSmaller", label: "조작 패널 작게", key: "Ctrl+[" },
        { id: "panelOpaque", label: "조작 패널 더 진하게", key: "Alt+]" },
        { id: "panelClear", label: "조작 패널 더 투명하게", key: "Alt+[" },
        { id: "repeat", label: "반복 재생 바꾸기 (끔 → 전체 → 한 곡)", key: "Ctrl+R" },
        { id: "settings", label: "설정 열기", key: "F2" },
        { id: "help", label: "사용 설명서", key: "F1" }
    ]

    // ---- 자막 상태 ----
    property var subTracks: []          // 외부 자막 파일 [{name, cues}]
    property int subSel: -1             // -1 끔, 0.. 외부, 1000+ 내장
    property bool subMenuOpen: false
    property int subOffset: 0           // ms (+ 이면 자막이 늦게 나옴)
    property int subSize: 30

    // ================= 설정 =================
    readonly property var settingDefs: [
        { sec: "재생" },
        { key: "repeat", title: "반복 재생", desc: "영상(재생목록)이 끝나면 어떻게 할지", type: "choice", def: 0,
          choices: [[0, "끔"], [1, "전체 반복"], [2, "한 곡 반복"]] },
        { key: "shuffle", title: "셔플", desc: "재생목록을 무작위 순서로 재생", type: "toggle", def: false },
        { key: "autoPlay", title: "열면 바로 재생", desc: "끄면 영상을 열고 멈춘 상태로 시작", type: "toggle", def: true },
        { key: "resume", title: "이어보기", desc: "전에 보던 위치부터 이어서 재생", type: "toggle", def: true },
        { key: "speed", title: "시작 재생 속도", desc: "프로그램을 켤 때의 기본 속도", type: "choice", def: 1,
          choices: [[0.5, "0.5x"], [0.75, "0.75x"], [1, "1x"], [1.25, "1.25x"], [1.5, "1.5x"], [2, "2x"]] },
        { key: "skipShort", title: "짧게 건너뛰기", desc: "← → 키로 이동하는 시간", type: "step", def: 5, min: 1, max: 60, step: 1, unit: "초" },
        { key: "skipLong", title: "길게 건너뛰기", desc: "Shift + ← → 키로 이동하는 시간", type: "step", def: 30, min: 5, max: 300, step: 5, unit: "초" },
        { key: "rememberPlaylist", title: "재생목록 기억", desc: "끌어놓거나 연 영상 목록을 저장해서, 다음에 켜도 그대로 남김", type: "toggle", def: true },
        { key: "rememberVolume", title: "볼륨 기억", desc: "다음에 켜도 마지막 볼륨 유지", type: "toggle", def: true },
        { sec: "화면" },
        { key: "seekPreview", title: "탐색 막대 미리보기", desc: "막대 위에 마우스를 올리면 그 시간의 장면을 작게 보여줌", type: "toggle", def: true },
        { key: "hideSec", title: "조작바 자동 숨김", desc: "마우스를 가만히 두면 숨겨지기까지의 시간", type: "step", def: 3, min: 1, max: 15, step: 1, unit: "초" },
        { key: "uiScale", title: "조작 패널 크기", desc: "아래쪽 조작 패널 전체 크기 (70~110%)", type: "step", def: 100, min: 70, max: 110, step: 10, unit: "%" },
        { key: "barAlpha", title: "조작 패널 투명도", desc: "낮을수록 투명해서 영상이 비쳐 보임 (20~100%)", type: "step", def: 85, min: 20, max: 100, step: 5, unit: "%" },
        { key: "smallOnExit", title: "전체화면을 끝내면 작은 창으로", desc: "Esc 로 전체화면을 나올 때 작은 창(1100x620)으로. 끄면 이전 창 상태로", type: "toggle", def: true },
        { key: "onTop", title: "항상 위에 표시", desc: "다른 창 위에 계속 띄워 둠", type: "toggle", def: false },
        { sec: "자막" },
        { key: "autoSubs", title: "자막 자동 불러오기", desc: "영상과 같은 이름의 자막 파일을 자동으로 사용", type: "toggle", def: true },
        { key: "subSize", title: "자막 글자 크기", desc: "기본 글자 크기", type: "step", def: 30, min: 16, max: 70, step: 2, unit: "" },
        { sec: "화질 · 캡처" },
        { key: "rememberQuality", title: "화질 설정 기억", desc: "GPU 선명화 값과 AI 모델을 다음에도 유지", type: "toggle", def: true },
        { key: "aiAtStart", title: "시작할 때 실시간 AI 켜기", desc: "NVIDIA GPU 에서 AI 엔진을 바로 준비", type: "toggle", def: false },
        { key: "capDir", title: "캡처 저장 위치", desc: "캡처한 사진이 저장되는 폴더 (비우면 사진\\Player64X)", type: "folder", def: "" },
        { key: "capFmt", title: "캡처 저장 형식", desc: "PNG 는 무손실, JPG 는 용량이 작음", type: "choice", def: "png",
          choices: [["png", "PNG"], ["jpg", "JPG"]] }
    ]
    property var cfg: ({})
    property bool cfgLoaded: false
    readonly property var cfgDefaults: {
        var d = { volume: 0.8, qEnhance: false, qSharp: 0.5, qDenoise: 0.15, qContrast: 1.0, qSaturation: 1.0, qAiModel: 0, resumeMap: ({}), playlist: [], plIdx: 0 }
        for (var i = 0; i < settingDefs.length; ++i)
            if (settingDefs[i].key !== undefined) d[settingDefs[i].key] = settingDefs[i].def
        return d
    }
    function cfgGet(k) { var v = cfg[k]; return v === undefined ? cfgDefaults[k] : v }
    function setCfg(k, v) {
        if (cfg[k] === v || (cfg[k] === undefined && cfgDefaults[k] === v)) return
        var c = {}
        for (var i in cfg) c[i] = cfg[i]
        c[k] = v
        cfg = c
        applyCfg(k)
        cfgSaveTimer.restart()
    }
    function applyCfg(k) {
        if (k === "repeat") { if (repeatMode !== cfgGet("repeat")) repeatMode = cfgGet("repeat") }
        else if (k === "shuffle") { if (shuffle !== cfgGet("shuffle")) shuffle = cfgGet("shuffle") }
        else if (k === "hideSec") hideTimer.interval = cfgGet("hideSec") * 1000
        else if (k === "capDir") backend.setCaptureDir(cfgGet("capDir"))
        else if (k === "subSize") { if (subSize !== cfgGet("subSize")) subSize = cfgGet("subSize") }
        else if (k === "speed") { var i = speeds.indexOf(cfgGet("speed")); if (i >= 0) { speedIdx = i; player.playbackRate = speeds[i] } }
    }
    function applyAllCfg() {
        var keys = ["repeat", "shuffle", "hideSec", "subSize", "speed", "capDir"]
        for (var i = 0; i < keys.length; ++i) applyCfg(keys[i])
        audio.volume = cfgGet("rememberVolume") ? cfgGet("volume") : 0.8
        if (cfgGet("rememberQuality")) {
            enhanceOn = cfgGet("qEnhance"); fxSharp = cfgGet("qSharp"); fxDenoise = cfgGet("qDenoise")
            fxContrast = cfgGet("qContrast"); fxSaturation = cfgGet("qSaturation"); aiModel = cfgGet("qAiModel")
        }
    }
    function restorePlaylist() {
        var saved = cfgGet("playlist")
        if (!saved || saved.length === 0) return
        var l = backend.existingUrls(saved)          // 지워졌거나 연결이 빠진 파일은 건너뜀
        if (l.length === 0) return
        playlist = l
        plIdx = Math.max(0, Math.min(cfgGet("plIdx"), l.length - 1))
        openUrl(l[plIdx])
        pendingPause = true                          // 켜자마자 소리가 나지 않게 멈춘 상태로 시작
        osd("재생목록 " + l.length + "개를 불러왔습니다")
    }
    function loadCfg() {
        try { cfg = JSON.parse(backend.loadConfig("settings.json") || "{}") } catch (err) { cfg = {} }
        applyAllCfg()
        cfgLoaded = true
    }
    function saveCfgNow() { if (cfgLoaded) backend.saveConfig("settings.json", JSON.stringify(cfg)) }
    function resetCfg() {
        cfg = {}
        applyAllCfg()
        saveCfgNow()
        osd("설정을 기본값으로 되돌렸습니다")
    }
    Timer { id: cfgSaveTimer; interval: 500; onTriggered: win.saveCfgNow() }

    // 화면에서 직접 바꾼 값도 설정에 기억
    onPlaylistChanged: if (cfgLoaded && cfgGet("rememberPlaylist")) setCfg("playlist", playlist.slice(0, 500))
    onPlIdxChanged: if (cfgLoaded && cfgGet("rememberPlaylist")) setCfg("plIdx", plIdx)
    onRepeatModeChanged: if (cfgLoaded) setCfg("repeat", repeatMode)
    onShuffleChanged: if (cfgLoaded) setCfg("shuffle", shuffle)
    onSubSizeChanged: if (cfgLoaded) setCfg("subSize", subSize)
    onEnhanceOnChanged: if (cfgLoaded && cfgGet("rememberQuality")) setCfg("qEnhance", enhanceOn)
    onFxSharpChanged: if (cfgLoaded && cfgGet("rememberQuality")) setCfg("qSharp", Math.round(fxSharp * 100) / 100)
    onFxDenoiseChanged: if (cfgLoaded && cfgGet("rememberQuality")) setCfg("qDenoise", Math.round(fxDenoise * 100) / 100)
    onFxContrastChanged: if (cfgLoaded && cfgGet("rememberQuality")) setCfg("qContrast", Math.round(fxContrast * 100) / 100)
    onFxSaturationChanged: if (cfgLoaded && cfgGet("rememberQuality")) setCfg("qSaturation", Math.round(fxSaturation * 100) / 100)
    onAiModelChanged: if (cfgLoaded && cfgGet("rememberQuality")) setCfg("qAiModel", aiModel)

    // ---- 이어보기 ----
    property real pendingResume: 0
    property bool pendingPause: false
    function saveResumePos() {
        if (!cfgLoaded || !cfgGet("resume") || player.source.toString() === "") return
        var key = player.source.toString(), pos = player.position, dur = player.duration
        var old = cfgGet("resumeMap"), r = {}
        for (var k in old) r[k] = old[k]
        delete r[key]
        if (dur > 0 && pos > 5000 && pos < dur - 10000) r[key] = Math.round(pos)
        var keys = Object.keys(r)
        while (keys.length > 100) delete r[keys.shift()]
        setCfg("resumeMap", r)
    }
    Timer { interval: 5000; repeat: true; running: true
            onTriggered: if (player.playbackState === MediaPlayer.PlayingState) win.saveResumePos() }
    onClosing: function (close) { saveResumePos(); saveCfgNow() }

    // ---- 재생목록 ----
    property var playlist: []           // 동영상 URL 목록
    property int plIdx: -1
    property bool plOpen: false
    property int repeatMode: 0          // 0 순서대로, 1 전체 반복, 2 한 곡 반복
    property bool shuffle: false
    readonly property var repeatNames: ["반복 끔", "전체 반복", "한 곡 반복"]
    function nameOf(u) {
        var s = decodeURIComponent(u.toString())
        return s.substring(s.lastIndexOf("/") + 1)
    }
    function setPlaylist(urls, start) {
        if (!urls || urls.length === 0) return
        playlist = urls
        if (urls.length > 1) { plOpen = true; showChrome() }
        playTo(start || 0)
    }
    function dropVideos(urls) {
        if (!urls || urls.length === 0) return
        var cur = playlist.slice(), first = -1
        for (var i = 0; i < urls.length; ++i) {
            var k = cur.indexOf(urls[i])
            if (k < 0) { cur.push(urls[i]); k = cur.length - 1 }
            if (first < 0) first = k
        }
        playlist = cur
        plOpen = true
        showChrome()
        playTo(first)
        osd(urls.length + "개를 재생목록에 넣었습니다")
    }
    function addToPlaylist(urls) {
        if (!urls || urls.length === 0) return
        if (playlist.length === 0) { setPlaylist(urls, 0); return }
        playlist = playlist.concat(urls)
        osd(urls.length + "개 추가됨")
    }
    function playTo(i) {
        if (i < 0 || i >= playlist.length) return
        plIdx = i
        openUrl(playlist[i])
    }
    function cycleRepeat() {
        repeatMode = (repeatMode + 1) % 3
        osd(repeatNames[repeatMode] + (repeatMode === 1 ? " — 끝나면 처음부터 다시" : repeatMode === 2 ? " — 지금 영상만 계속" : ""))
    }
    function nextTrack(auto) {
        if (playlist.length === 0) return
        if (auto && (repeatMode === 2 || (playlist.length <= 1 && repeatMode === 1))) { player.setPosition(0); player.play(); return }
        var n = plIdx + 1
        if (shuffle && playlist.length > 1) {
            do { n = Math.floor(Math.random() * playlist.length) } while (n === plIdx)
        }
        if (n >= playlist.length) {
            if (repeatMode === 1 || !auto) n = 0
            else { chrome = true; return }
        }
        playTo(n)
    }
    function prevTrack() {
        if (playlist.length === 0) return
        if (player.position > 3000) { player.setPosition(0); return }
        playTo(plIdx - 1 < 0 ? playlist.length - 1 : plIdx - 1)
    }
    function removeAt(i) {
        var l = playlist.slice()
        l.splice(i, 1)
        playlist = l
        if (i < plIdx) plIdx--
        else if (i === plIdx) {
            if (l.length === 0) { player.stop(); player.source = ""; plIdx = -1; fileName = ""; subTracks = []; subSel = -1 }
            else playTo(Math.min(i, l.length - 1))
        }
    }
    function clearPlaylist() {
        playlist = []; plIdx = -1
        player.stop(); player.source = ""; fileName = ""; subTracks = []; subSel = -1
    }

    // ---- 화면 맞춤 계산 ----
    readonly property real sw: stage.width
    readonly property real sh: stage.height
    property int vRot: 0                // 영상 자체의 회전(0/90/180/270) — 세로로 찍은 핸드폰 영상 등
    readonly property real vw: vRot % 180 !== 0 ? vo.sourceRect.height : vo.sourceRect.width
    readonly property real vh: vRot % 180 !== 0 ? vo.sourceRect.width : vo.sourceRect.height
    function refreshRot() {
        var r = backend.frameRotation(vo.videoSink)
        if (r >= 0 && r !== vRot) vRot = r
    }
    Connections { target: vo; function onSourceRectChanged() { win.refreshRot() } }
    Timer { id: rotTimer; interval: 300; repeat: true; property int n: 0
            onTriggered: { win.refreshRot(); if (++n >= 6) { stop(); n = 0 } } }
    readonly property real aStretch: {
        var r = aspects[aspectIdx][1]
        if (r === 0 || vw <= 0 || vh <= 0) return 1
        if (r < 0) r = (rot % 180 !== 0) ? sh / sw : sw / sh
        return r / (vw / vh)
    }
    readonly property real fitK: {
        if (vw <= 0 || vh <= 0 || sw <= 0 || sh <= 0) return 1
        var s0 = Math.min(sw / vw, sh / vh)
        var dw = vw * s0 * aStretch, dh = vh * s0
        if (rot % 180 !== 0) { var t = dw; dw = dh; dh = t }
        return Math.min(sw / dw, sh / dh)
    }

    // ---- 현재 자막 ----
    function cueAt(cues, ms) {
        var lo = 0, hi = cues.length - 1
        while (lo <= hi) {
            var mid = (lo + hi) >> 1
            var c = cues[mid]
            if (ms < c[0]) hi = mid - 1
            else if (ms > c[1]) lo = mid + 1
            else return c[2]
        }
        return ""
    }
    readonly property string subText: {
        if (subSel === -1) return ""
        if (subSel >= 1000) return vo.videoSink.subtitleText
        var tr = subTracks[subSel]
        return tr ? cueAt(tr.cues, player.position - subOffset) : ""
    }
    readonly property var subEntries: {
        var out = [{ label: "자막 끄기", sel: -1, kind: "pick" }]
        for (var i = 0; i < subTracks.length; ++i)
            out.push({ label: subTracks[i].name, sel: i, kind: "pick" })
        var emb = player.subtitleTracks
        for (var j = 0; j < emb.length; ++j) {
            var t = emb[j].stringValue(MediaMetaData.Title)
            out.push({ label: "내장 자막 " + (j + 1) + (t ? " · " + t : ""), sel: 1000 + j, kind: "pick" })
        }
        return out
    }

    function fmt(ms) {
        var s = Math.max(0, Math.floor(ms / 1000))
        var h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), x = s % 60
        var p = function (n) { return (n < 10 ? "0" : "") + n }
        return h > 0 ? h + ":" + p(m) + ":" + p(x) : p(m) + ":" + p(x)
    }
    function osd(t) { osdText.text = t; osdAnim.restart() }
    function showChrome() { chrome = true; hideTimer.restart() }

    function selectSub(sel) {
        subSel = sel
        player.activeSubtitleTrack = sel >= 1000 ? sel - 1000 : -1
        osd(sel === -1 ? "자막 끔" : "자막: " + (sel >= 1000 ? "내장 " + (sel - 999) : subTracks[sel].name))
    }
    function addSubs(list) {
        if (!list || list.length === 0) return
        var first = subTracks.length
        subTracks = subTracks.concat(list)
        selectSub(first)
    }
    function openSubDialog() { addSubs(backend.openSubtitleDialog()) }
    function startLive() {
        subMenuOpen = false
        osd(backend.liveCaptions() ? "Windows 실시간 캡션 시작 (설정 ⚙ 에서 언어 선택)" : "이 PC에서 실시간 캡션을 찾을 수 없습니다")
    }
    function pickEntry(e) {
        if (e.kind === "pick") selectSub(e.sel)
    }

    function openUrl(u) {
        if (!u) return
        saveResumePos()
        errorText = ""
        subTracks = []
        subSel = -1
        subOffset = 0
        loopA = -1; loopB = -1
        rotTimer.restart()
        previewPreload.restart()
        player.source = u
        var s = decodeURIComponent(u.toString())
        fileName = s.substring(s.lastIndexOf("/") + 1)
        resetView()
        var found = cfgGet("autoSubs") ? backend.findSubtitles(u.toString()) : []
        if (found.length > 0) { subTracks = found; subSel = 0 }
        player.playbackRate = speeds[speedIdx]
        pendingResume = cfgGet("resume") ? (cfgGet("resumeMap")[player.source.toString()] || 0) : 0
        pendingPause = !cfgGet("autoPlay")
        player.play()
    }
    function openDialog() { setPlaylist(backend.openDialog(), 0) }
    function addDialog() { addToPlaylist(backend.openDialog()) }
    function togglePlay() {
        if (player.source.toString() === "") { openDialog(); return }
        if (player.playbackState === MediaPlayer.PlayingState) player.pause(); else player.play()
        showChrome()
    }
    function skip(sec) {
        player.setPosition(Math.max(0, Math.min(player.duration, player.position + sec * 1000)))
        osd((sec > 0 ? "+" : "") + sec + "초")
    }
    function setZoom(nz, px, py) {
        nz = Math.max(0.1, Math.min(32, nz))
        var k = nz / zoom
        var cx = px - sw / 2, cy = py - sh / 2
        panX = cx - k * (cx - panX)
        panY = cy - k * (cy - panY)
        zoom = nz
    }
    function zoomBy(f, px, py) {
        if (px === undefined) { px = sw / 2; py = sh / 2 }
        setZoom(zoom * f, px, py)
        osd("확대 " + Math.round(zoom * 100) + "%")
    }
    function resetZoom() { zoom = 1; panX = 0; panY = 0 }
    function resetView() { resetZoom(); rot = 0; flipped = false; aspectIdx = 0 }
    function rotate() { rot = (rot + 90) % 360; osd("회전 " + rot + "°") }
    function flip() { flipped = !flipped; osd(flipped ? "좌우반전" : "반전 해제") }
    function cycleAspect() { aspectIdx = (aspectIdx + 1) % aspects.length; osd("화면 비율 " + aspects[aspectIdx][0]) }
    function capture() {
        if (player.source.toString() === "") { osd("재생 중인 영상이 없습니다"); return }
        var p = backend.capture(vo.videoSink, fileName, Math.round(player.position), cfgGet("capFmt"))
        osd(p !== "" ? "캡처 저장됨 · " + p : "캡처에 실패했습니다")
    }
    // ---- 화질 개선 동작 ----
    function toggleEnhance() { enhanceOn = !enhanceOn; osd(enhanceOn ? "GPU 선명화 켬" : "GPU 선명화 끔") }
    function applyPreset(name) {
        if (name === "off") { enhanceOn = false; setAi(false); osd("화질 개선 끔"); return }
        var p = { sharp: { s: 0.55, d: 0.15, c: 1.04, v: 1.05 }, movie: { s: 0.35, d: 0.25, c: 1.10, v: 1.08 }, anime: { s: 0.60, d: 0.30, c: 1.05, v: 1.10 } }[name]
        fxSharp = p.s; fxDenoise = p.d; fxContrast = p.c; fxSaturation = p.v
        if (name === "anime") aiModel = 1; else if (name === "movie") aiModel = 0
        enhanceOn = true
        osd({ sharp: "선명 프리셋", movie: "영화 프리셋", anime: "애니 프리셋" }[name])
    }
    function setAi(on) {
        aiOn = on
        ai.setRealtime(on, aiModel, vo.videoSink, aiVo.videoSink)
        if (on) osd("실시간 AI 켜는 중…")
        else { aiShow = false; osd("실시간 AI 끔") }
    }
    function setAiModel(m) {
        aiModel = m
        ai.setModel(m)
        if (aiOn) ai.setRealtime(true, m, vo.videoSink, aiVo.videoSink)
    }
    function aiCapture() {
        if (player.source.toString() === "") { osd("재생 중인 영상이 없습니다"); return }
        osd("AI 캡처 처리 중…")
        ai.capture(vo.videoSink, fileName, Math.round(player.position), aiModel)
    }
    Connections {
        target: ai
        function onFlowChanged(f) { win.aiShow = f && win.aiOn }
        function onCaptureDone(msg) { win.osd(msg) }
    }

    // ---- 오른쪽 버튼 메뉴 ----
    function openCtx(x, y) {
        subMenuOpen = false; qualityOpen = false
        ctxX = Math.max(6, Math.min(x, win.width - 262))
        ctxY = Math.max(6, Math.min(y, win.height - ctxMenu.height - 6))
        ctxOpen = true
        showChrome()
    }
    function revealFile() {
        if (player.source.toString() === "") { osd("재생 중인 파일이 없습니다"); return }
        backend.revealFile(player.source.toString())
    }
    function ctxDo(id) {
        ctxOpen = false
        // 파일 열기 창처럼 오래 걸리는 동작은 메뉴 처리가 끝난 뒤에 실행 (메뉴 항목이 사라진 뒤 돌아와 꺼지는 문제 방지)
        Qt.callLater(function () {
            switch (id) {
            case "add": addDialog(); break
            case "reveal": revealFile(); break
            case "subfile": openSubDialog(); break
            default: doAction(id)
            }
        })
    }
    // 항목 목록은 고정, 바뀌는 글자(재생/일시정지 등)는 ctxLabel 이 따로 계산한다
    function ctxLabel(it) {
        if (it.id === "playPause") return player.playbackState === MediaPlayer.PlayingState ? "일시정지" : "재생"
        if (it.id === "fullscreen") return fs ? "창 모드" : "전체화면"
        if (it.id === "repeat") return "반복 재생: " + repeatNames[repeatMode]
        return it.label
    }
    readonly property var ctxItems: [
        { id: "open", label: "파일 열기…" },
        { id: "add", label: "재생목록에 파일 추가…" },
        { id: "reveal", label: "파일 위치 열기 (탐색기)" },
        { sep: true },
        { id: "playPause", label: "재생" },
        { id: "fullscreen", label: "전체화면" },
        { id: "repeat", label: "반복 재생" },
        { sep: true },
        { id: "subfile", label: "자막 파일 열기…" },
        { id: "capture", label: "현재 화면 캡처" },
        { id: "quality", label: "화질 개선" },
        { sep: true },
        { id: "settings", label: "설정" },
        { id: "help", label: "도움말 · 사용 설명서" }
    ]

    function setSpeed(r) {
        var i = speeds.indexOf(r)
        if (i < 0) return
        speedIdx = i
        player.playbackRate = r
        osd("속도 " + r + "x")
    }
    function slowMo() {
        var r = speeds[speedIdx]
        setSpeed(r > 0.5 ? 0.5 : r > 0.25 ? 0.25 : r > 0.1 ? 0.1 : 1.0)
    }
    function abLoop() {
        if (player.source.toString() === "") return
        if (loopA < 0) { loopA = player.position; loopB = -1; osd("구간 시작(A) " + fmt(loopA) + "  —  끝 지점에서 다시 누르세요") }
        else if (loopB < 0) {
            if (player.position <= loopA + 300) { osd("A 지점보다 뒤에서 눌러주세요"); return }
            loopB = player.position
            osd("구간 반복  " + fmt(loopA) + " ~ " + fmt(loopB))
            player.setPosition(loopA)
        } else { loopA = -1; loopB = -1; osd("구간 반복 해제") }
    }
    function changeSpeed(d, wrap) {
        var n = speedIdx + d
        if (n >= speeds.length) n = wrap ? 0 : speeds.length - 1
        if (n < 0) n = 0
        speedIdx = n
        player.playbackRate = speeds[n]
        osd("속도 " + speeds[n] + "x")
    }
    function setVolume(v) { audio.volume = Math.max(0, Math.min(1, v)); osd("볼륨 " + Math.round(audio.volume * 100)) }
    function toggleFs() {
        if (fs) {
            if (cfgGet("smallOnExit")) { showNormal(); smallTimer.restart() }
            else if (prevMax) showMaximized()
            else showNormal()
        } else { prevMax = (visibility === Window.Maximized); showFullScreen() }
    }
    Timer {
        id: smallTimer
        interval: 80
        onTriggered: {
            win.width = 1100; win.height = 620
            win.x = Math.max(0, Math.round((Screen.width - 1100) / 2))
            win.y = Math.max(0, Math.round((Screen.height - 620) / 2))
        }
    }
    function toggleMax() { if (visibility === Window.Maximized) showNormal(); else showMaximized() }

    // ================= 단축키 엔진 =================
    property var keyToAction: ({})
    readonly property var keyNames: {
        var t = {}
        t[Qt.Key_Space] = "Space"; t[Qt.Key_Left] = "Left"; t[Qt.Key_Right] = "Right"
        t[Qt.Key_Up] = "Up"; t[Qt.Key_Down] = "Down"; t[Qt.Key_Return] = "Enter"; t[Qt.Key_Enter] = "Enter"
        t[Qt.Key_Tab] = "Tab"; t[Qt.Key_Backspace] = "Backspace"; t[Qt.Key_Delete] = "Delete"
        t[Qt.Key_Home] = "Home"; t[Qt.Key_End] = "End"; t[Qt.Key_PageUp] = "PageUp"; t[Qt.Key_PageDown] = "PageDown"
        t[Qt.Key_Insert] = "Insert"
        for (var i = 0; i < 12; ++i) t[Qt.Key_F1 + i] = "F" + (i + 1)
        // Shift 없이 눌러도, 누른 상태에서도 같은 키로 취급하는 기호 키
        t[Qt.Key_Plus] = "+"; t[Qt.Key_Equal] = "+"
        t[Qt.Key_Minus] = "-"; t[Qt.Key_Underscore] = "-"
        t[Qt.Key_Comma] = ","; t[Qt.Key_Less] = ","
        t[Qt.Key_Period] = "."; t[Qt.Key_Greater] = "."
        t[Qt.Key_BracketLeft] = "["; t[Qt.Key_BraceLeft] = "["
        t[Qt.Key_BracketRight] = "]"; t[Qt.Key_BraceRight] = "]"
        t[Qt.Key_Slash] = "/"; t[Qt.Key_Question] = "/"
        t[Qt.Key_Backslash] = "\\"; t[Qt.Key_Semicolon] = ";"; t[Qt.Key_Apostrophe] = "'"
        return t
    }
    readonly property var symbolKeys: [Qt.Key_Plus, Qt.Key_Equal, Qt.Key_Minus, Qt.Key_Underscore, Qt.Key_Comma, Qt.Key_Less,
        Qt.Key_Period, Qt.Key_Greater, Qt.Key_BracketLeft, Qt.Key_BraceLeft, Qt.Key_BracketRight, Qt.Key_BraceRight,
        Qt.Key_Slash, Qt.Key_Question]

    function keyName(e) {
        var k = e.key
        if (k === Qt.Key_Shift || k === Qt.Key_Control || k === Qt.Key_Alt || k === Qt.Key_Meta || k === Qt.Key_AltGr) return ""
        var base = ""
        if ((k >= Qt.Key_A && k <= Qt.Key_Z) || (k >= Qt.Key_0 && k <= Qt.Key_9)) base = String.fromCharCode(k)
        else if (keyNames[k] !== undefined) base = keyNames[k]
        else return ""
        var m = ""
        if (e.modifiers & Qt.ControlModifier) m += "Ctrl+"
        if (e.modifiers & Qt.AltModifier) m += "Alt+"
        if ((e.modifiers & Qt.ShiftModifier) && symbolKeys.indexOf(k) < 0) m += "Shift+"
        return m + base
    }
    function rebuildKeys() {
        var r = {}
        for (var i = 0; i < actionDefs.length; ++i) {
            var k = keymap[actionDefs[i].id]
            if (k) r[k] = actionDefs[i].id
        }
        keyToAction = r
    }
    function loadKeys() {
        var saved = {}
        try { saved = JSON.parse(backend.loadKeys() || "{}") } catch (err) { saved = {} }
        var km = {}
        for (var i = 0; i < actionDefs.length; ++i) {
            var d = actionDefs[i]
            km[d.id] = saved.hasOwnProperty(d.id) ? saved[d.id] : d.key
        }
        keymap = km
        rebuildKeys()
    }
    function setKey(id, name) {
        var km = {}
        for (var k in keymap) km[k] = keymap[k]
        if (name !== "") for (var o in km) if (km[o] === name && o !== id) km[o] = ""   // 같은 키를 쓰던 동작은 해제
        km[id] = name
        keymap = km
        rebuildKeys()
        backend.saveKeys(JSON.stringify(km))
    }
    function resetKeys() {
        var km = {}
        for (var i = 0; i < actionDefs.length; ++i) km[actionDefs[i].id] = actionDefs[i].key
        keymap = km
        rebuildKeys()
        backend.saveKeys(JSON.stringify(km))
        osd("단축키를 기본값으로 되돌렸습니다")
    }
    function keyLabel(id) { return keymap[id] ? keymap[id] : "—" }

    function doAction(id) {
        switch (id) {
        case "playPause": togglePlay(); break
        case "back5": skip(-cfgGet("skipShort")); break
        case "fwd5": skip(cfgGet("skipShort")); break
        case "back30": skip(-cfgGet("skipLong")); break
        case "fwd30": skip(cfgGet("skipLong")); break
        case "volUp": setVolume(audio.volume + 0.05); break
        case "volDown": setVolume(audio.volume - 0.05); break
        case "fullscreen": toggleFs(); break
        case "capture": capture(); break
        case "quality": qualityOpen = !qualityOpen; break
        case "enhance": toggleEnhance(); break
        case "aiToggle": setAi(!aiOn); break
        case "aiCapture": aiCapture(); break
        case "zoomIn": zoomBy(1.25); break
        case "zoomOut": zoomBy(0.8); break
        case "zoomReset": resetZoom(); osd("보기 초기화"); break
        case "panLeft": panX += 80; break
        case "panRight": panX -= 80; break
        case "panUp": panY += 80; break
        case "panDown": panY -= 80; break
        case "rotate": rotate(); break
        case "flip": flip(); break
        case "aspect": cycleAspect(); break
        case "speedDown": changeSpeed(-1, false); break
        case "speedUp": changeSpeed(1, false); break
        case "slowMo": slowMo(); break
        case "abLoop": abLoop(); break
        case "next": nextTrack(false); break
        case "prev": prevTrack(); break
        case "playlist": plOpen = !plOpen; break
        case "open": openDialog(); break
        case "subMenu": subMenuOpen = !subMenuOpen; break
        case "liveCaps": startLive(); break
        case "subEarlier": subOffset -= 500; osd("자막 싱크 " + (subOffset / 1000).toFixed(1) + "s"); break
        case "subLater": subOffset += 500; osd("자막 싱크 " + (subOffset / 1000).toFixed(1) + "s"); break
        case "panelBigger": setCfg("uiScale", Math.min(110, cfgGet("uiScale") + 10)); osd("조작 패널 크기 " + cfgGet("uiScale") + "%"); break
        case "panelSmaller": setCfg("uiScale", Math.max(70, cfgGet("uiScale") - 10)); osd("조작 패널 크기 " + cfgGet("uiScale") + "%"); break
        case "panelOpaque": setCfg("barAlpha", Math.min(100, cfgGet("barAlpha") + 10)); osd("조작 패널 투명도 " + cfgGet("barAlpha") + "%"); break
        case "panelClear": setCfg("barAlpha", Math.max(20, cfgGet("barAlpha") - 10)); osd("조작 패널 투명도 " + cfgGet("barAlpha") + "%"); break
        case "repeat": cycleRepeat(); break
        case "settings": helpOpen = !(helpOpen && helpTab === 2); helpTab = 2; capId = ""; break
        case "help": helpOpen = !helpOpen; helpTab = 0; capId = ""; break
        }
    }

    property bool previewOn: false
    property real previewPos: 0
    // 영상을 열고 잠시 뒤(재생이 안정된 뒤) 미리보기 재생기를 미리 준비 — 마우스를 올렸을 때 바로 장면이 나오도록.
    // 8K 같은 매우 큰 영상은 부담이 커서 처음 마우스를 올릴 때 준비한다.
    Timer {
        id: previewPreload
        interval: 1500
        onTriggered: if (cfgGet("seekPreview") && vw > 0 && vw * vh <= 8300000) previewOn = true
    }
    MediaPlayer {
        id: previewPlayer
        source: (win.previewOn && win.cfgGet("seekPreview")) ? player.source : ""
        videoOutput: pvo
        property bool ready: false          // 새 파일이 로드되어 일시정지된 상태인지
        onSourceChanged: ready = false
        onMediaStatusChanged: {
            // 로드 직후 딱 한 번만 일시정지 (pause/seek 가 상태를 다시 바꿔도 반복하지 않음)
            if (!ready && mediaStatus === MediaPlayer.LoadedMedia) {
                ready = true
                pause()
                setPosition(win.previewPos)
            }
        }
    }
    Timer {
        id: previewTimer
        interval: 90
        onTriggered: if (previewPlayer.ready) previewPlayer.setPosition(win.previewPos)
    }

    MediaPlayer {
        id: player
        videoOutput: vo
        audioOutput: AudioOutput { id: audio; volume: 0.8
            onVolumeChanged: if (win.cfgLoaded && win.cfgGet("rememberVolume")) win.setCfg("volume", Math.round(volume * 100) / 100) }
        onErrorOccurred: function (error, errorString) { win.errorText = errorString }
        onMediaStatusChanged: {
            if (mediaStatus === MediaPlayer.LoadedMedia || mediaStatus === MediaPlayer.BufferedMedia) {
                win.refreshRot()
                if (win.pendingResume > 0) { var t = win.pendingResume; win.pendingResume = 0; setPosition(t); win.osd("이어보기 " + win.fmt(t)) }
                if (win.pendingPause) { win.pendingPause = false; pause() }
            }
            if (mediaStatus === MediaPlayer.EndOfMedia && duration > 0 && position >= duration - 1500) {
                win.chrome = true
                win.saveResumePos()
                win.nextTrack(true)
            }
        }
        onPositionChanged: function (pos) { if (win.loopOn && pos >= win.loopB) setPosition(win.loopA) }
        onTracksChanged: {
            if (win.subTracks.length === 0 && subtitleTracks.length > 0 && win.subSel === -1)
                win.selectSub(1000)
        }
    }

    // ================= 영상 영역 =================
    Item {
        id: stage
        anchors.fill: parent
        clip: true

        // 이동(맨 바깥) → 확대 → 회전 → 가로비율/반전 → 영상
        Item {
            width: stage.width; height: stage.height
            x: win.panX; y: win.panY
            Item {
                anchors.fill: parent
                scale: win.zoom
                Item {
                    anchors.fill: parent
                    rotation: win.rot
                    Item {
                        id: shaper
                        anchors.fill: parent
                        transform: Scale {
                            origin.x: shaper.width / 2
                            origin.y: shaper.height / 2
                            xScale: win.fitK * win.aStretch * (win.flipped ? -1 : 1)
                            yScale: win.fitK
                        }
                        // 영상 + AI 고화질 층 (영상 비율 그대로의 크기)
                        Item {
                            id: videoStack
                            anchors.centerIn: parent
                            readonly property real fit0: (win.vw > 0 && win.vh > 0) ? Math.min(win.sw / win.vw, win.sh / win.vh) : 1
                            width: win.vw > 0 ? win.vw * fit0 : shaper.width
                            height: win.vh > 0 ? win.vh * fit0 : shaper.height
                            VideoOutput {
                                id: vo
                                anchors.fill: parent
                                fillMode: win.vw > 0 ? VideoOutput.Stretch : VideoOutput.PreserveAspectFit
                            }
                            VideoOutput {
                                id: aiVo
                                anchors.fill: parent
                                fillMode: VideoOutput.Stretch
                                visible: win.aiShow
                            }
                        }
                        // GPU 선명화 (노이즈 제거 · 선명도 · 대비 · 채도)
                        ShaderEffect {
                            id: fx
                            anchors.fill: videoStack
                            visible: win.enhanceOn && win.vw > 0
                            readonly property size texSize: (win.aiShow && aiVo.sourceRect.width > 0)
                                ? Qt.size(aiVo.sourceRect.width, aiVo.sourceRect.height)
                                : Qt.size(Math.max(1, win.vw), Math.max(1, win.vh))
                            property variant src: ShaderEffectSource {
                                sourceItem: videoStack
                                hideSource: win.enhanceOn && fx.status === ShaderEffect.Compiled
                                live: true
                                textureSize: fx.texSize
                            }
                            property real sharp: win.fxSharp
                            property real denoise: win.fxDenoise
                            property real contrast: win.fxContrast
                            property real saturation: win.fxSaturation
                            property vector2d texel: Qt.vector2d(1 / fx.texSize.width, 1 / fx.texSize.height)
                            fragmentShader: Qt.resolvedUrl("enhance.frag.qsb")
                        }
                    }
                }
            }
        }

        // 시작 화면
        Column {
            visible: player.source.toString() === ""
            anchors.centerIn: parent
            spacing: 10
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 76; height: 76; radius: 20
                color: "#141826"; border.color: win.cLine
                Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: 3; text: "▶"; color: win.cAccent; font.pixelSize: 32 }
            }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "Player 64X"; color: win.cInk; font.pixelSize: 28; font.weight: Font.DemiBold }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "8K · HEVC · AV1 · 실시간 자막"; color: win.cDim; font.pixelSize: 14; font.letterSpacing: 1 }
            Item { width: 1; height: 10 }
            Text { anchors.horizontalCenter: parent.horizontalCenter; text: "영상 파일을 끌어놓거나  O  키를 누르세요"; color: win.cDim; font.pixelSize: 14 }
        }
        Text {
            visible: win.errorText !== ""
            anchors.centerIn: parent
            width: parent.width - 80
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            color: "#FF8A80"; font.pixelSize: 16
            text: "재생할 수 없습니다.\n" + win.errorText
        }

        // OSD
        Rectangle {
            id: osdBox
            x: 24; y: 64
            width: osdText.implicitWidth + 28; height: 38; radius: 10
            color: "#B0101218"; border.color: win.cLine
            opacity: osdText.opacity
            Text { id: osdText; anchors.centerIn: parent; opacity: 0; color: win.cInk; font.pixelSize: 15
                SequentialAnimation {
                    id: osdAnim
                    PropertyAction { target: osdText; property: "opacity"; value: 1 }
                    PauseAnimation { duration: 1100 }
                    NumberAnimation { target: osdText; property: "opacity"; to: 0; duration: 500 }
                }
            }
        }

        // 마우스: 휠=확대, 드래그=이동, 클릭=재생/정지, 더블클릭=전체화면, 가운데=초기화
        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
            cursorShape: win.chrome ? Qt.ArrowCursor : Qt.BlankCursor
            property real sx; property real sy; property real px0; property real py0
            property bool moved: false
            onPressed: function (m) {
                win.subMenuOpen = false
                win.qualityOpen = false
                if (m.button === Qt.RightButton) { win.openCtx(m.x, m.y); return }
                win.ctxOpen = false
                if (m.button === Qt.MiddleButton) { win.resetZoom(); win.osd("보기 초기화"); return }
                sx = m.x; sy = m.y; px0 = win.panX; py0 = win.panY; moved = false
            }
            onPositionChanged: function (m) {
                win.showChrome()
                if (!pressed || !(pressedButtons & Qt.LeftButton)) return
                var dx = m.x - sx, dy = m.y - sy
                if (!moved && Math.abs(dx) + Math.abs(dy) < 4) return
                moved = true
                win.panX = px0 + dx
                win.panY = py0 + dy
            }
            onReleased: function (m) {
                if (m.button === Qt.LeftButton && !moved) clickTimer.restart()
            }
            onDoubleClicked: { clickTimer.stop(); win.toggleFs() }
            onWheel: function (w) { win.zoomBy(w.angleDelta.y > 0 ? 1.12 : 1 / 1.12, w.x, w.y) }
        }
        Timer { id: clickTimer; interval: 260; onTriggered: win.togglePlay() }
    }

    // ================= 자막 표시 =================
    Rectangle {
        visible: win.subText !== ""
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: win.chrome ? barRef.height + 34 : 44
        width: Math.min(parent.width - 60, subLabel.implicitWidth + 36)
        height: subLabel.implicitHeight + 16
        radius: 10
        color: "#9E000000"
        Behavior on anchors.bottomMargin { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
        Text {
            id: subLabel
            anchors.centerIn: parent
            width: parent.width - 36
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: win.subText
            color: "white"
            font.pixelSize: win.subSize
            font.weight: Font.Medium
            lineHeight: 1.12
        }
    }

    DropArea {
        anchors.fill: parent
        onDropped: function (d) {
            if (d.urls.length === 0) return
            var subRe = /\.(srt|smi|sami|vtt|ass|ssa)$/
            var all = [], vids = []
            for (var i = 0; i < d.urls.length; ++i) all.push(d.urls[i].toString())
            // 폴더/여러 파일 -> 동영상만 골라 자연 정렬한 재생목록
            vids = backend.expandUrls(all.filter(function (u) { return !subRe.test(u.toLowerCase()) }))
            if (vids.length > 0) { win.dropVideos(vids); return }
            for (var j = 0; j < all.length; ++j)
                if (subRe.test(all[j].toLowerCase())) win.addSubs(backend.loadSubtitleUrl(all[j]))
        }
    }

    // ================= 공용 버튼 =================
    component Btn: Rectangle {
        property alias label: t.text
        property bool on: false
        property color tint: win.cInk
        signal clicked
        implicitWidth: Math.max(t.implicitWidth + 18, 30)
        height: 30; radius: 8
        color: ma.pressed ? "#33FFFFFF" : ma.containsMouse ? win.cHover : (on ? "#244DA3FF" : "transparent")
        Text { id: t; anchors.centerIn: parent; color: parent.on ? win.cAccent : parent.tint; font.pixelSize: 12 }
        MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: parent.clicked() }
    }

    // ================= 상단 바 =================
    Rectangle {
        id: topBar
        anchors { left: parent.left; right: parent.right; top: parent.top }
        height: 52
        visible: win.chrome
        gradient: Gradient {
            GradientStop { position: 0; color: "#B3000000" }
            GradientStop { position: 1; color: "#00000000" }
        }
        MouseArea {
            anchors.fill: parent
            hoverEnabled: true
            onPositionChanged: win.showChrome()
            onPressed: if (!win.fs) win.startSystemMove()
            onDoubleClicked: if (!win.fs) win.toggleMax()
        }
        Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 18 }
            spacing: 10
            Rectangle { width: 8; height: 8; radius: 4; color: win.cAccent; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Player 64X"; color: win.cInk; font.pixelSize: 13; font.weight: Font.DemiBold; anchors.verticalCenter: parent.verticalCenter }
            Text { visible: win.fileName !== ""; text: "·  " + win.fileName; color: win.cDim; font.pixelSize: 13; elide: Text.ElideMiddle
                   width: Math.min(implicitWidth, win.width - 780); anchors.verticalCenter: parent.verticalCenter }
            Text { visible: win.playlist.length > 1; text: (win.plIdx + 1) + " / " + win.playlist.length; color: win.cAccent; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
            spacing: 2
            Btn { label: "열기"; onClicked: win.openDialog() }
            Btn { label: "재생목록" + (win.playlist.length > 0 ? " " + win.playlist.length : ""); on: win.plOpen; onClicked: win.plOpen = !win.plOpen }
            Btn { label: "설정"; on: win.helpOpen && win.helpTab === 2; onClicked: { win.helpOpen = !(win.helpOpen && win.helpTab === 2); win.helpTab = 2; win.capId = "" } }
            Btn { label: "도움말 · 단축키"; on: win.helpOpen && win.helpTab !== 2; onClicked: { win.helpOpen = !win.helpOpen; win.helpTab = 0; win.capId = "" } }
            Item { width: 8; height: 1 }
            Rectangle {
                height: 24; radius: 12; width: brand.implicitWidth + 24; anchors.verticalCenter: parent.verticalCenter
                color: "#1F4DA3FF"; border.color: "#554DA3FF"
                Text { id: brand; anchors.centerIn: parent; text: "개발자SKM"; color: win.cAccent; font.pixelSize: 12; font.weight: Font.DemiBold; font.letterSpacing: 0.5 }
            }
            Item { width: 10; height: 1 }
            Btn { label: "—"; visible: !win.fs; onClicked: win.showMinimized() }
            Btn { label: win.visibility === Window.Maximized ? "❐" : "☐"; visible: !win.fs; onClicked: win.toggleMax() }
            Rectangle {
                visible: !win.fs
                width: 42; height: 34; radius: 9
                color: closeMa.containsMouse ? "#E5484D" : "transparent"
                Text { anchors.centerIn: parent; text: "✕"; color: win.cInk; font.pixelSize: 13 }
                MouseArea { id: closeMa; anchors.fill: parent; hoverEnabled: true; onClicked: win.close() }
            }
        }
    }

    // ================= 하단 패널 (한 줄 · 크기/투명도 조절) =================
    readonly property real ui: cfgGet("uiScale") / 100
    readonly property real barAlpha: cfgGet("barAlpha") / 100

    // 조작 패널이 화면에서 실제로 차지하는 영역(크기 조절 반영) — 메뉴들이 이 위에 붙는다
    Item {
        id: barRef
        width: bar.width * win.ui; height: bar.height * win.ui
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
    }

    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 14
        width: Math.min((parent.width - 36) / win.ui, 1100)
        height: 70
        scale: win.ui
        transformOrigin: Item.Bottom
        radius: 14
        color: Qt.rgba(0.063, 0.071, 0.094, win.barAlpha)
        border.color: Qt.rgba(1, 1, 1, 0.15 * win.barAlpha)
        visible: win.chrome

        MouseArea { id: barArea; anchors.fill: parent; hoverEnabled: true; onPositionChanged: win.showChrome() }
        // 안쪽 버튼·탐색 막대가 마우스를 받아도 '패널 위에 있음'을 놓치지 않도록
        HoverHandler { id: barHover; onHoveredChanged: if (hovered) win.showChrome() }

        // ---- 탐색 막대 ----
        Item {
            id: seekRow
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 14; rightMargin: 14; topMargin: 6 }
            height: 20
            Text { id: tCur; width: 46; height: parent.height; verticalAlignment: Text.AlignVCenter; color: win.cDim; font.pixelSize: 11; text: win.fmt(player.position) }
            Text { id: tTot; anchors.right: parent.right; width: 46; height: parent.height; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
                   color: win.cDim; font.pixelSize: 11; text: win.fmt(player.duration) }
            Item {
                id: seekItem
                anchors { left: tCur.right; right: tTot.left; leftMargin: 6; rightMargin: 6; top: parent.top; bottom: parent.bottom }
                property real hoverX: -1
                Rectangle {
                    id: track
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width
                    height: seekMa.containsMouse || seekMa.pressed ? 6 : 4
                    radius: height / 2; color: "#2E3240"
                    Behavior on height { NumberAnimation { duration: 100 } }
                    Rectangle {
                        height: parent.height; radius: parent.radius; color: win.cAccent
                        width: player.duration > 0 ? parent.width * player.position / player.duration : 0
                    }
                    // 구간 반복 표시 (A ~ B)
                    Rectangle {
                        visible: win.loopA >= 0 && player.duration > 0
                        x: parent.width * win.loopA / Math.max(1, player.duration)
                        width: win.loopB > win.loopA ? parent.width * (win.loopB - win.loopA) / Math.max(1, player.duration) : 3
                        height: parent.height + 6; y: -3; radius: 2
                        color: win.loopB > win.loopA ? "#99FFC857" : "#FFFFC857"
                    }
                }
                Rectangle {
                    visible: seekMa.containsMouse || seekMa.pressed
                    width: 13; height: 13; radius: 6.5; color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: (player.duration > 0 ? track.width * player.position / player.duration : 0) - 6.5
                }
                Rectangle {
                    id: tipBox
                    visible: seekMa.containsMouse && player.duration > 0
                    readonly property bool hasPrev: win.previewOn && win.cfgGet("seekPreview") && win.vw > 0 && win.vh > 0
                    readonly property real ps: win.vw > 0 ? Math.min(176 / win.vw, 150 / win.vh) : 0   // 회전 반영한 비율 유지
                    readonly property real pw: hasPrev ? Math.round(win.vw * ps) : 0
                    readonly property real ph: hasPrev ? Math.round(win.vh * ps) : 0
                    x: Math.max(0, Math.min(seekItem.width - width, seekItem.hoverX - width / 2))
                    y: -height - 8
                    width: Math.max(tip.implicitWidth + 16, pw + 10)
                    height: (hasPrev ? ph + 8 : 0) + 26
                    radius: 8
                    color: "#F0181A22"; border.color: win.cLine
                    VideoOutput {
                        id: pvo
                        visible: tipBox.hasPrev
                        x: (parent.width - width) / 2; y: 5
                        width: tipBox.pw; height: tipBox.ph
                        fillMode: VideoOutput.Stretch
                    }
                    Text { id: tip; anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 5 }
                           color: win.cInk; font.pixelSize: 12
                           text: win.fmt(Math.max(0, Math.min(1, seekItem.hoverX / seekItem.width)) * player.duration) }
                }
                MouseArea {
                    id: seekMa
                    anchors.fill: parent
                    hoverEnabled: true
                    function seekTo(x) { if (player.duration > 0) player.setPosition(Math.max(0, Math.min(1, x / width)) * player.duration) }
                    onPositionChanged: function (m) {
                        seekItem.hoverX = m.x
                        win.showChrome()
                        if (player.duration > 0) {
                            win.previewPos = Math.max(0, Math.min(1, m.x / width)) * player.duration
                            if (win.cfgGet("seekPreview")) { win.previewOn = true; if (!previewTimer.running) previewTimer.start() }
                        }
                        if (pressed) seekTo(m.x)
                    }
                    onPressed: function (m) { seekTo(m.x) }
                }
            }
        }

        // ---- 왼쪽: 재생 ----
        Row {
            id: leftRow
            x: 10; y: 28; height: 36
            spacing: 1
            Btn { label: "|◀"; anchors.verticalCenter: parent.verticalCenter; enabled: win.playlist.length > 1; opacity: enabled ? 1 : 0.35; onClicked: win.prevTrack() }
            Btn { label: "⟲ 10"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.skip(-10) }
            Rectangle {
                width: 32; height: 32; radius: 16
                anchors.verticalCenter: parent.verticalCenter
                color: pma.pressed ? "#3A8EE6" : win.cAccent
                scale: pma.containsMouse ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }
                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: player.playbackState === MediaPlayer.PlayingState ? 0 : 1.5
                    text: player.playbackState === MediaPlayer.PlayingState ? "❚❚" : "▶"
                    color: "#06101C"; font.pixelSize: 12
                }
                MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: win.togglePlay() }
            }
            Btn { label: "10 ⟳"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.skip(10) }
            Btn { label: "▶|"; anchors.verticalCenter: parent.verticalCenter; enabled: win.playlist.length > 1; opacity: enabled ? 1 : 0.35; onClicked: win.nextTrack(false) }
        }

        // ---- 가운데: 보기 도구(확대 / 옆으로 보기 / 캡처) ----
        Row {
            id: midRow
            y: 28; height: 36
            x: Math.max(leftRow.x + leftRow.width + 14, Math.min((bar.width - width) / 2, rightRow.x - 14 - width))
            spacing: 1
            Btn { label: "회전"; anchors.verticalCenter: parent.verticalCenter; on: win.rot !== 0; onClicked: win.rotate() }
            Btn { label: "반전"; anchors.verticalCenter: parent.verticalCenter; on: win.flipped; onClicked: win.flip() }
            Btn { label: win.aspectIdx !== 0 ? win.aspects[win.aspectIdx][0] : "비율"; anchors.verticalCenter: parent.verticalCenter; on: win.aspectIdx !== 0; onClicked: win.cycleAspect() }
            Item { width: 6; height: 1 }
            Btn { label: "−"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.zoomBy(0.8) }
            Btn { label: Math.round(win.zoom * 100) + "%"; width: 50; anchors.verticalCenter: parent.verticalCenter; on: win.zoom !== 1
                  onClicked: { win.resetZoom(); win.osd("보기 초기화") } }
            Btn { label: "+"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.zoomBy(1.25) }
            Item { width: 6; height: 1 }
            Btn { label: "캡처"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.capture() }
        }

        // ---- 오른쪽: 속도 / 슬로우 / 구간 / 반복 / 자막 / 화질 / 볼륨 / 전체화면 ----
        Row {
            id: rightRow
            anchors { right: parent.right; rightMargin: 10 }
            y: 28; height: 36
            spacing: 1
            Btn { label: win.speeds[win.speedIdx] + "x"; width: 38; anchors.verticalCenter: parent.verticalCenter; on: win.speeds[win.speedIdx] !== 1; onClicked: win.changeSpeed(1, true) }
            Btn { label: win.speeds[win.speedIdx] < 1 ? "슬로우 " + win.speeds[win.speedIdx] : "슬로우"; anchors.verticalCenter: parent.verticalCenter
                  on: win.speeds[win.speedIdx] < 1; onClicked: win.slowMo() }
            Btn { label: win.loopOn ? "구간 중" : win.loopA >= 0 ? "A 지정" : "구간"; anchors.verticalCenter: parent.verticalCenter
                  on: win.loopA >= 0; onClicked: win.abLoop() }
            Btn { label: win.repeatMode === 0 ? "반복" : win.repeatMode === 1 ? "전체반복" : "한 곡"; anchors.verticalCenter: parent.verticalCenter
                  on: win.repeatMode !== 0; onClicked: win.cycleRepeat() }
            Btn { label: "자막"; anchors.verticalCenter: parent.verticalCenter; on: win.subSel !== -1 || win.subMenuOpen; onClicked: { win.subMenuOpen = !win.subMenuOpen; win.qualityOpen = false } }
            Btn { label: win.aiOn ? "화질·AI" : win.enhanceOn ? "화질·선명" : "화질"; anchors.verticalCenter: parent.verticalCenter
                  on: win.aiOn || win.enhanceOn || win.qualityOpen; onClicked: { win.qualityOpen = !win.qualityOpen; win.subMenuOpen = false } }
            Item {
                width: 78; height: 30; anchors.verticalCenter: parent.verticalCenter
                Rectangle { anchors.verticalCenter: parent.verticalCenter; x: 8; width: parent.width - 16; height: 4; radius: 2; color: "#2E3240" }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; x: 8; width: (parent.width - 16) * audio.volume; height: 4; radius: 2; color: win.cInk }
                Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: "white"; x: 8 + (parent.width - 16) * audio.volume - 6 }
                MouseArea {
                    anchors.fill: parent
                    onPressed: function (m) { audio.volume = Math.max(0, Math.min(1, (m.x - 8) / (width - 16))) }
                    onPositionChanged: function (m) { if (pressed) audio.volume = Math.max(0, Math.min(1, (m.x - 8) / (width - 16))) }
                }
            }
            Btn { label: win.fs ? "창 모드" : "전체화면"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.toggleFs() }
        }
    }


    // ================= 화질 개선 메뉴 =================
    component HSlider: Item {
        id: hs
        property string label: ""
        property real from: 0
        property real to: 1
        property real value: 0
        property bool active: true
        signal moved(real v)
        height: 30
        Text { width: 72; height: parent.height; verticalAlignment: Text.AlignVCenter; text: hs.label
               color: hs.active ? win.cInk : win.cDim; font.pixelSize: 13 }
        Item {
            id: area
            x: 76; width: parent.width - 76 - 52; height: parent.height
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: "#2E3240" }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; height: 4; radius: 2; color: hs.active ? win.cAccent : win.cDim
                        width: parent.width * (hs.value - hs.from) / (hs.to - hs.from) }
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: 12; height: 12; radius: 6; color: "white"
                        x: parent.width * (hs.value - hs.from) / (hs.to - hs.from) - 6 }
            MouseArea {
                anchors.fill: parent
                function setFrom(x) { hs.moved(hs.from + Math.max(0, Math.min(1, x / width)) * (hs.to - hs.from)) }
                onPressed: function (m) { setFrom(m.x) }
                onPositionChanged: function (m) { if (pressed) setFrom(m.x) }
            }
        }
        Text { anchors.right: parent.right; width: 46; height: parent.height; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter
               text: hs.value.toFixed(2); color: win.cDim; font.pixelSize: 12 }
    }

    Rectangle {
        id: qualityMenu
        visible: win.qualityOpen && win.chrome
        anchors.horizontalCenter: barRef.horizontalCenter
        anchors.bottom: barRef.top
        anchors.bottomMargin: 10
        width: 440
        height: qCol.implicitHeight + 24
        radius: 16
        color: "#F2141620"
        border.color: win.cLine
        z: 20

        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: win.showChrome(); onWheel: function (w) { w.accepted = true } }

        Column {
            id: qCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
            spacing: 6

            Row {
                width: parent.width; height: 30
                Text { height: parent.height; verticalAlignment: Text.AlignVCenter; text: "화질 개선"; color: win.cInk; font.pixelSize: 15; font.weight: Font.DemiBold }
                Item { width: parent.width - 110 - 30; height: 1 }
                Btn { label: "✕"; onClicked: win.qualityOpen = false }
            }

            // 프리셋
            Row {
                spacing: 4
                Text { width: 54; height: 34; verticalAlignment: Text.AlignVCenter; text: "프리셋"; color: win.cDim; font.pixelSize: 12 }
                Btn { label: "끔"; onClicked: win.applyPreset("off") }
                Btn { label: "선명"; onClicked: win.applyPreset("sharp") }
                Btn { label: "영화"; onClicked: win.applyPreset("movie") }
                Btn { label: "애니"; onClicked: win.applyPreset("anime") }
            }

            Rectangle { width: parent.width; height: 1; color: win.cLine }

            // GPU 선명화
            Row {
                width: parent.width; height: 34
                Column {
                    width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "GPU 선명화"; color: win.cInk; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: "즉시 적용 · 8K 에서도 끊기지 않음"; color: win.cDim; font.pixelSize: 11 }
                }
                Btn { label: win.enhanceOn ? "켜짐" : "꺼짐"; on: win.enhanceOn; onClicked: win.toggleEnhance() }
            }
            HSlider { width: parent.width; label: "선명도"; value: win.fxSharp; active: win.enhanceOn; onMoved: function (v) { win.fxSharp = v } }
            HSlider { width: parent.width; label: "노이즈 제거"; value: win.fxDenoise; active: win.enhanceOn; onMoved: function (v) { win.fxDenoise = v } }
            HSlider { width: parent.width; label: "대비"; from: 0.6; to: 1.6; value: win.fxContrast; active: win.enhanceOn; onMoved: function (v) { win.fxContrast = v } }
            HSlider { width: parent.width; label: "채도"; from: 0.0; to: 2.0; value: win.fxSaturation; active: win.enhanceOn; onMoved: function (v) { win.fxSaturation = v } }

            Rectangle { width: parent.width; height: 1; color: win.cLine }

            // AI 업스케일
            Row {
                width: parent.width; height: 34
                Column {
                    width: parent.width - 80; anchors.verticalCenter: parent.verticalCenter
                    Text { text: "AI 업스케일 (실시간)"; color: win.cInk; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text { text: "저해상도 영상(약 854x480 이하)을 재생하면서 4배 선명하게"; color: win.cDim; font.pixelSize: 11 }
                }
                Btn { label: win.aiOn ? "켜짐" : "꺼짐"; on: win.aiOn; onClicked: win.setAi(!win.aiOn) }
            }
            Row {
                spacing: 4
                Text { width: 54; height: 34; verticalAlignment: Text.AlignVCenter; text: "AI 모델"; color: win.cDim; font.pixelSize: 12 }
                Btn { label: "실사 · 영화"; on: win.aiModel === 0; onClicked: win.setAiModel(0) }
                Btn { label: "애니메이션"; on: win.aiModel === 1; onClicked: win.setAiModel(1) }
            }
            Text {
                width: parent.width; wrapMode: Text.Wrap
                text: ai.status; color: win.aiOn ? win.cAccent : win.cDim; font.pixelSize: 12
            }

            Rectangle { width: parent.width; height: 1; color: win.cLine }

            Rectangle {
                width: parent.width; height: 46; radius: 10
                color: acm.containsMouse ? "#2A4DA3FF" : "#144DA3FF"; border.color: "#334DA3FF"
                Column {
                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                    Text { text: "AI 캡처 — 현재 장면을 AI 로 키워서 저장"; color: win.cAccent; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { text: "4K 이하 영상에서 가능 · 사진\\Player64X 에 저장"; color: win.cDim; font.pixelSize: 11 }
                }
                MouseArea { id: acm; anchors.fill: parent; hoverEnabled: true; onClicked: win.aiCapture() }
            }
        }
    }

    // ================= 재생목록 패널 =================
    Rectangle {
        id: plPanel
        visible: win.plOpen && win.chrome
        anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 60; bottom: barRef.top; bottomMargin: 12 }
        width: 350
        radius: 16
        color: "#F0141620"
        border.color: win.cLine

        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: win.showChrome(); onWheel: function (w) { w.accepted = true } }

        Item {
            id: plHead
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: 48
            Text { anchors { left: parent.left; leftMargin: 18; verticalCenter: parent.verticalCenter }
                   text: "재생목록  " + win.playlist.length; color: win.cInk; font.pixelSize: 14; font.weight: Font.DemiBold }
            Row {
                anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 0
                Btn { label: "추가"; onClicked: win.addDialog() }
                Btn { label: "비우기"; onClicked: win.clearPlaylist() }
                Btn { label: "✕"; onClicked: win.plOpen = false }
            }
        }

        ListView {
            id: plList
            anchors { left: parent.left; right: parent.right; top: plHead.bottom; bottom: plFoot.top; leftMargin: 8; rightMargin: 8 }
            clip: true
            model: win.playlist
            spacing: 2
            currentIndex: win.plIdx
            onCurrentIndexChanged: positionViewAtIndex(currentIndex, ListView.Contain)
            Text {
                visible: win.playlist.length === 0
                anchors.centerIn: parent; width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter; wrapMode: Text.Wrap
                color: win.cDim; font.pixelSize: 13; lineHeight: 1.3
                text: "비어 있습니다.\n영상 여러 개(또는 폴더)를\n이 창에 끌어놓으세요."
            }
            delegate: Rectangle {
                width: plList.width; height: 40; radius: 9
                readonly property bool cur: index === win.plIdx
                color: dma.containsMouse ? win.cHover : (cur ? "#1F4DA3FF" : "transparent")
                Text { id: numT; x: 12; anchors.verticalCenter: parent.verticalCenter; width: 24
                       text: cur ? "▶" : (index + 1); color: cur ? win.cAccent : win.cDim; font.pixelSize: 12 }
                Text { anchors { left: numT.right; right: delBtn.left; verticalCenter: parent.verticalCenter; rightMargin: 6 }
                       text: win.nameOf(modelData); elide: Text.ElideMiddle
                       color: cur ? win.cAccent : win.cInk; font.pixelSize: 13 }
                MouseArea { id: dma; anchors.fill: parent; hoverEnabled: true; onClicked: win.playTo(index) }
                Rectangle {
                    id: delBtn
                    anchors { right: parent.right; rightMargin: 6; verticalCenter: parent.verticalCenter }
                    width: 28; height: 28; radius: 8
                    visible: dma.containsMouse || delMa.containsMouse
                    color: delMa.containsMouse ? "#33E5484D" : "transparent"
                    Text { anchors.centerIn: parent; text: "✕"; color: win.cDim; font.pixelSize: 11 }
                    MouseArea { id: delMa; anchors.fill: parent; hoverEnabled: true; onClicked: win.removeAt(index) }
                }
            }
        }

        Item {
            id: plFoot
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: 52
            Rectangle { anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 12; rightMargin: 12 } height: 1; color: win.cLine }
            Row {
                anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
                spacing: 2
                Btn { label: win.repeatNames[win.repeatMode]; on: win.repeatMode !== 0; onClicked: { win.repeatMode = (win.repeatMode + 1) % 3; win.osd(win.repeatNames[win.repeatMode]) } }
                Btn { label: "셔플"; on: win.shuffle; onClicked: { win.shuffle = !win.shuffle; win.osd(win.shuffle ? "셔플 켬" : "셔플 끔") } }
            }
            Text { anchors { right: parent.right; rightMargin: 16; verticalCenter: parent.verticalCenter }
                   text: win.playlist.length > 1 ? "끝나면 자동으로 다음 영상" : ""; color: win.cDim; font.pixelSize: 11 }
        }
    }

    // ================= 사용 설명서 / 단축키 설정 =================
    readonly property string helpHtml:
        "<style>h3{color:#4DA3FF;} td{padding:3px 10px 3px 0;} b{color:#ECEEF4;}</style>" +
        "<h3>시작하기</h3>" +
        "<p>• 영상 파일을 창에 <b>끌어놓거나</b> 상단 <b>열기</b> 를 누르세요. 여러 개(또는 폴더)를 한꺼번에 놓으면 <b>재생목록</b>이 만들어지고 순서대로 재생됩니다.<br>" +
        "• 8K·HEVC·AV1 영상도 별도 코덱 설치 없이 재생합니다(GPU 하드웨어 디코딩 사용).<br>" +
        "• 탐색 막대를 클릭/드래그하면 그 위치로 이동하고, 막대 위에 마우스를 올리면 해당 시간이 보입니다.</p>" +
        "<h3>확대 · 이동 · 옆으로 보기</h3>" +
        "<p>• <b>마우스 휠</b>: 커서 위치 기준으로 확대/축소 &nbsp;• <b>왼쪽 버튼 드래그</b>: 영상 이동 &nbsp;• <b>가운데 버튼</b>: 초기화<br>" +
        "• <b>회전</b>: 90°씩 돌려 옆으로 보기 &nbsp;• <b>좌우반전</b> &nbsp;• <b>비율</b>: 16:9 · 21:9 · 32:9 · 4:3 · 꽉 채우기로 옆으로 늘리기<br>" +
        "• 아래쪽 <b>−  100%  +</b> 로도 확대/축소하고, 가운데 %를 누르면 초기화됩니다.</p>" +
        "<h3>슬로우 모션 · 속도</h3>" +
        "<p>• <b>슬로우</b> 버튼(또는 단축키)을 누를 때마다 0.5x → 0.25x → 0.1x → 보통 속도로 바뀝니다.<br>" +
        "• <b>속도</b> 버튼은 0.1x ~ 4x 사이를 순서대로 바꿉니다.</p>" +
        "<h3>구간 반복 (A–B)</h3>" +
        "<p>• <b>구간반복</b> 버튼을 <b>시작 지점</b>에서 한 번, <b>끝 지점</b>에서 한 번 더 누르면 그 구간이 계속 반복됩니다. 한 번 더 누르면 해제됩니다.<br>" +
        "• 탐색 막대에 노란색으로 반복 구간이 표시됩니다.</p>" +
        "<h3>화질 개선 (AI · GPU)</h3>" +
        "<p>• 하단 <b>화질 개선</b> 버튼(또는 <b>Q</b> 키)에서 켜고 끕니다. 프리셋: 끔 · 선명 · 영화 · 애니<br>" +
        "• <b>GPU 선명화</b> (<b>E</b>): 선명도 · 노이즈 제거 · 대비 · 채도를 슬라이더로 조절합니다. 즉시 적용되고 8K 에서도 끊기지 않습니다.<br>" +
        "• <b>AI 업스케일(실시간)</b> (<b>I</b>): 저해상도 영상(약 854x480 이하)을 재생하면서 AI 로 4배 선명하게 합니다. 실사용/애니메이션 모델을 고를 수 있습니다. " +
        "더 큰 영상은 실시간으로 처리할 수 없어 안내 문구가 표시됩니다.<br>" +
        "• <b>AI 캡처</b> (<b>Shift+C</b>): 현재 장면 한 장을 AI 로 키워서 <b>사진 \\ Player64X</b> 에 저장합니다. 4K 이하 영상에서 가능합니다.<br>" +
        "• AI 는 NVIDIA 그래픽카드(CUDA)와 PyTorch 가 설치된 PC 에서 동작합니다.</p>" +
        "<h3>반복 재생 · 설정</h3>" +
        "<p>• 하단 <b>반복</b> 버튼(또는 <b>Ctrl+R</b>)을 누를 때마다 반복 끔 → 전체 반복 → 한 곡 반복으로 바뀝니다. 영상(재생목록)이 끝나면 처음부터 자동으로 다시 재생합니다.<br>" +
        "• 상단 <b>설정</b>(또는 <b>F2</b>)에서 이어보기, 열면 바로 재생, 건너뛰기 시간, 조작바 숨김 시간, 항상 위, 자막/캡처/화질 옵션을 바꿀 수 있고 자동 저장됩니다.</p>" +
        "<h3>오른쪽 버튼 메뉴</h3>" +
        "<p>• 영상 위에서 <b>마우스 오른쪽 버튼</b>을 누르면 파일 열기, 재생목록에 추가, <b>파일 위치 열기(탐색기)</b>, 재생·전체화면·반복, 자막 열기, 캡처, 화질 개선, 설정을 바로 쓸 수 있는 메뉴가 나옵니다. 오른쪽에 단축키가 같이 표시됩니다.</p>" +
        "<h3>화면 비율 · 미리보기</h3>" +
        "<p>• 영상을 열면 영상 안의 <b>회전 정보</b>(세로로 찍은 핸드폰 영상 등)를 읽어 원래 비율 그대로 자동으로 맞춰 보여줍니다.<br>" +
        "• 탐색 막대에 마우스를 올리면 그 시간의 <b>장면 미리보기</b>가 뜹니다. (설정에서 끌 수 있음)</p>" +
        "<h3>조작 패널 크기 · 투명도</h3>" +
        "<p>• <b>설정(F2)</b>에서 조작 패널 크기(70~110%)와 투명도(20~100%)를 바꿉니다. 단축키: 크기 <b>Ctrl+[ ]</b>, 투명도 <b>Alt+[ ]</b>.<br>" +
        "• 전체화면에서 <b>Esc</b>(또는 Enter)를 누르면 작은 창(1100x620)으로 돌아옵니다. 설정에서 끌 수 있습니다.</p>" +
        "<h3>캡처 · 전체화면</h3>" +
        "<p>• <b>캡처</b> 버튼(또는 <b>C</b> 키): 지금 보이는 장면을 영상 <b>원본 크기</b> 그대로 저장합니다. 저장 위치는 기본 <b>사진 \\ Player64X</b> 이고, <b>설정(F2) → 캡처 저장 위치</b>에서 바꾸거나 열 수 있습니다.<br>" +
        "• <b>Enter</b> 키(또는 더블클릭, F 키): 화면을 크게(전체화면). <b>Esc</b> 로 돌아옵니다.</p>" +
        "<h3>자막</h3>" +
        "<p>• 영상과 같은 이름의 자막 파일(SRT · SMI · VTT · ASS)이 있으면 자동으로 불러옵니다. 자막 파일을 창에 끌어놓아도 됩니다.<br>" +
        "• <b>자막</b> 메뉴에서 언어 선택, 글자 크기, 싱크(±0.5초)를 조절하세요. 영상에 내장된 자막도 고를 수 있습니다.<br>" +
        "• <b>실시간 자동 자막</b>: Windows 11 실시간 캡션을 켭니다. 언어는 캡션 창의 ⚙ 설정에서 고릅니다.</p>" +
        "<h3>재생목록</h3>" +
        "<p>• 영상을 창에 <b>끌어놓으면</b> 재생목록에 추가되고(이미 있으면 그 영상으로 이동) 재생목록 창이 열리며 첫 영상이 재생됩니다.</p>" +
        "<p>• 영상을 끌어놓거나 열면 재생목록에 <b>자동 저장</b>되어, 프로그램을 다시 켜도 그 목록이 남고 마지막 영상이 멈춘 상태로 열립니다. (설정에서 끌 수 있음)</p>" +
        "<p>• 상단 <b>재생목록</b> 에서 목록을 보고, 항목 클릭으로 재생, ✕ 로 제거, <b>추가</b> 로 파일을 더할 수 있습니다.<br>" +
        "• <b>다음/이전</b> 버튼, 반복(끔 · 전체 · 한 곡), 셔플을 지원합니다.</p>" +
        "<h3>단축키</h3>" +
        "<p>모든 단축키는 <b>‘단축키 설정’ 탭</b>에서 직접 바꿀 수 있고 자동 저장됩니다. 현재 설정은 그 탭에서 확인하세요.<br>" +
        "(고정) <b>Esc</b>: 창/전체화면 닫기 &nbsp;• 더블클릭: 전체화면 &nbsp;• 클릭: 재생/정지</p>" +
        "<h3>문의</h3><p>개발자SKM</p>"

    Rectangle {
        id: helpScrim
        visible: win.helpOpen
        anchors.fill: parent
        color: "#99000000"
        z: 50
        MouseArea { anchors.fill: parent; onClicked: { win.helpOpen = false; win.capId = "" } onWheel: function (w) { w.accepted = true } }

        Rectangle {
            id: helpBox
            anchors.centerIn: parent
            width: Math.min(parent.width - 80, 880)
            height: Math.min(parent.height - 100, 660)
            radius: 18
            color: "#F2121420"
            border.color: win.cLine
            MouseArea { anchors.fill: parent; onWheel: function (w) { w.accepted = false } }

            Row {
                id: helpTabs
                anchors { left: parent.left; top: parent.top; leftMargin: 14; topMargin: 12 }
                spacing: 4
                Btn { label: "사용 설명서"; on: win.helpTab === 0; onClicked: { win.helpTab = 0; win.capId = "" } }
                Btn { label: "단축키 설정"; on: win.helpTab === 1; onClicked: win.helpTab = 1 }
                Btn { label: "설정"; on: win.helpTab === 2; onClicked: { win.helpTab = 2; win.capId = "" } }
            }
            Btn {
                anchors { right: parent.right; top: parent.top; rightMargin: 12; topMargin: 12 }
                label: "✕"
                onClicked: { win.helpOpen = false; win.capId = "" }
            }

            // --- 사용 설명서 ---
            Flickable {
                visible: win.helpTab === 0
                anchors { left: parent.left; right: parent.right; top: helpTabs.bottom; bottom: parent.bottom; margins: 22; topMargin: 14 }
                contentWidth: width; contentHeight: helpText.implicitHeight
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Text {
                    id: helpText
                    width: parent.width - 16
                    textFormat: Text.RichText
                    wrapMode: Text.Wrap
                    color: win.cDim; font.pixelSize: 14; lineHeight: 1.35
                    text: win.helpHtml
                }
            }

            // --- 설정 ---
            Flickable {
                visible: win.helpTab === 2
                anchors { left: parent.left; right: parent.right; top: helpTabs.bottom; bottom: parent.bottom; margins: 18; topMargin: 12 }
                contentWidth: width; contentHeight: setCol.implicitHeight + 10
                clip: true
                boundsBehavior: Flickable.StopAtBounds
                Column {
                    id: setCol
                    width: parent.width - 10
                    spacing: 2
                    Repeater {
                        model: win.settingDefs
                        delegate: Item {
                            id: setRow
                            readonly property var d: modelData
                            readonly property string k: d.key !== undefined ? d.key : ""
                            width: setCol.width
                            height: d.sec !== undefined ? 38 : 54
                            // 구역 제목
                            Text { visible: setRow.d.sec !== undefined; anchors { left: parent.left; leftMargin: 6; bottom: parent.bottom; bottomMargin: 4 }
                                   text: setRow.d.sec !== undefined ? setRow.d.sec : ""; color: win.cAccent; font.pixelSize: 13; font.weight: Font.DemiBold }
                            // 설정 항목
                            Rectangle {
                                visible: setRow.d.sec === undefined
                                anchors.fill: parent; radius: 10
                                color: index % 2 === 0 ? "#0FFFFFFF" : "transparent"
                                Column {
                                    anchors { left: parent.left; leftMargin: 14; verticalCenter: parent.verticalCenter }
                                    Text { text: setRow.d.title !== undefined ? setRow.d.title : ""; color: win.cInk; font.pixelSize: 14 }
                                    Text { text: setRow.d.desc !== undefined ? setRow.d.desc : ""; color: win.cDim; font.pixelSize: 11 }
                                }
                                // 켜기/끄기
                                Btn {
                                    visible: setRow.d.type === "toggle"
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    readonly property bool cur: setRow.k !== "" ? win.cfgGet(setRow.k) === true : false
                                    label: cur ? "켜짐" : "꺼짐"; on: cur
                                    onClicked: win.setCfg(setRow.k, !cur)
                                }
                                // 고르기
                                Row {
                                    visible: setRow.d.type === "choice"
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    spacing: 2
                                    Repeater {
                                        model: setRow.d.type === "choice" ? setRow.d.choices : []
                                        delegate: Btn {
                                            readonly property var ch: modelData
                                            label: ch[1]
                                            on: win.cfgGet(setRow.k) === ch[0]
                                            onClicked: win.setCfg(setRow.k, ch[0])
                                        }
                                    }
                                }
                                // 폴더 선택
                                Row {
                                    visible: setRow.d.type === "folder"
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    spacing: 2
                                    Text { width: 250; height: 34; verticalAlignment: Text.AlignVCenter; elide: Text.ElideMiddle
                                           text: win.cfgGet("capDir") !== "" ? win.cfgGet("capDir") : "사진\\Player64X (기본)"
                                           color: win.cfgGet("capDir") !== "" ? win.cInk : win.cDim; font.pixelSize: 12 }
                                    Btn { label: "변경…"; onClicked: Qt.callLater(function () { var d = backend.pickFolder(win.cfgGet("capDir")); if (d !== "") win.setCfg("capDir", d) }) }
                                    Btn { label: "열기"; onClicked: Qt.callLater(function () { win.osd("폴더 열기 · " + backend.openCaptureFolder()) }) }
                                    Btn { label: "기본"; visible: win.cfgGet("capDir") !== ""; onClicked: win.setCfg("capDir", "") }
                                }
                                // 숫자 조절
                                Row {
                                    visible: setRow.d.type === "step"
                                    anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                                    spacing: 2
                                    Btn { label: "−"; onClicked: win.setCfg(setRow.k, Math.max(setRow.d.min, win.cfgGet(setRow.k) - setRow.d.step)) }
                                    Text { width: 64; height: 34; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                                           text: setRow.k !== "" ? win.cfgGet(setRow.k) + (setRow.d.unit !== undefined ? setRow.d.unit : "") : ""
                                           color: win.cInk; font.pixelSize: 14 }
                                    Btn { label: "+"; onClicked: win.setCfg(setRow.k, Math.min(setRow.d.max, win.cfgGet(setRow.k) + setRow.d.step)) }
                                }
                            }
                        }
                    }
                    Item { width: 1; height: 8 }
                    Btn { label: "모든 설정을 기본값으로 되돌리기"; onClicked: win.resetCfg() }
                }
            }

            // --- 단축키 설정 ---
            Item {
                visible: win.helpTab === 1
                anchors { left: parent.left; right: parent.right; top: helpTabs.bottom; bottom: parent.bottom; margins: 18; topMargin: 12 }
                Text { id: keyHint; width: parent.width; wrapMode: Text.Wrap; color: win.cDim; font.pixelSize: 12
                       text: win.capId === "" ? "바꾸려는 항목의 키 칸을 클릭한 뒤, 새로 쓸 키를 누르세요.  (Delete = 키 해제 · Esc = 취소)" : "지금 누르는 키가 새 단축키가 됩니다…  (Esc 로 취소)" }
                ListView {
                    id: keyList
                    anchors { left: parent.left; right: parent.right; top: keyHint.bottom; bottom: keyFoot.top; topMargin: 10; bottomMargin: 8 }
                    clip: true
                    model: win.actionDefs
                    boundsBehavior: Flickable.StopAtBounds
                    delegate: Rectangle {
                        width: keyList.width - 6; height: 38; radius: 8
                        color: index % 2 === 0 ? "#0FFFFFFF" : "transparent"
                        readonly property bool waiting: win.capId === modelData.id
                        Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                               text: modelData.label; color: win.cInk; font.pixelSize: 13 }
                        Rectangle {
                            anchors { right: parent.right; rightMargin: 8; verticalCenter: parent.verticalCenter }
                            width: 150; height: 28; radius: 7
                            color: waiting ? "#334DA3FF" : (kma.containsMouse ? win.cHover : "#14FFFFFF")
                            border.color: waiting ? win.cAccent : win.cLine
                            Text { anchors.centerIn: parent; font.pixelSize: 12
                                   text: waiting ? "키를 누르세요…" : win.keyLabel(modelData.id)
                                   color: waiting ? win.cAccent : (win.keymap[modelData.id] ? win.cInk : win.cDim) }
                            MouseArea { id: kma; anchors.fill: parent; hoverEnabled: true; onClicked: win.capId = modelData.id }
                        }
                    }
                }
                Row {
                    id: keyFoot
                    anchors { left: parent.left; bottom: parent.bottom }
                    Btn { label: "기본값으로 되돌리기"; onClicked: { win.capId = ""; win.resetKeys() } }
                }
            }
        }
    }

    // ================= 자막 메뉴 =================
    Rectangle {
        id: subMenu
        visible: win.subMenuOpen && win.chrome
        anchors.right: barRef.right
        anchors.rightMargin: 90
        anchors.bottom: barRef.top
        anchors.bottomMargin: 10
        width: 372
        height: menuCol.implicitHeight + 20
        radius: 14
        color: "#F0141620"
        border.color: win.cLine

        MouseArea { anchors.fill: parent; hoverEnabled: true; onPositionChanged: win.showChrome() }

        Column {
            id: menuCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 10 }
            spacing: 2

            Text { text: "자막 · 언어 선택"; color: win.cDim; font.pixelSize: 12; leftPadding: 8; bottomPadding: 4 }

            Repeater {
                model: win.subEntries
                delegate: Rectangle {
                    width: menuCol.width; height: 34; radius: 8
                    readonly property bool cur: modelData.sel === win.subSel
                    color: rma.containsMouse ? win.cHover : (cur ? "#1F4DA3FF" : "transparent")
                    Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                           text: modelData.label; color: parent.cur ? win.cAccent : win.cInk; font.pixelSize: 13 }
                    Text { anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
                           visible: parent.cur; text: "✓"; color: win.cAccent; font.pixelSize: 14 }
                    MouseArea { id: rma; anchors.fill: parent; hoverEnabled: true; onClicked: win.pickEntry(modelData) }
                }
            }

            Rectangle { width: menuCol.width; height: 1; color: win.cLine }

            Rectangle {
                width: menuCol.width; height: 34; radius: 8
                color: oma.containsMouse ? win.cHover : "transparent"
                Text { anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                       text: "자막 파일 열기…  (SRT · SMI · VTT · ASS)"; color: win.cInk; font.pixelSize: 13 }
                MouseArea { id: oma; anchors.fill: parent; hoverEnabled: true; onClicked: { win.subMenuOpen = false; Qt.callLater(win.openSubDialog) } }
            }
            Rectangle {
                width: menuCol.width; height: 52; radius: 8
                color: lma.containsMouse ? win.cHover : "#144DA3FF"
                border.color: "#334DA3FF"
                Column {
                    anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
                    spacing: 2
                    Text { text: "실시간 자동 자막 (Windows 실시간 캡션)"; color: win.cAccent; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { text: "영상 소리를 듣고 바로 자막으로 · 언어는 캡션 창 ⚙ 에서"; color: win.cDim; font.pixelSize: 11 }
                }
                MouseArea { id: lma; anchors.fill: parent; hoverEnabled: true; onClicked: win.startLive() }
            }

            Rectangle { width: menuCol.width; height: 1; color: win.cLine }

            Row {
                height: 38; spacing: 4; leftPadding: 4
                Text { width: 64; height: parent.height; verticalAlignment: Text.AlignVCenter; text: "글자 크기"; color: win.cDim; font.pixelSize: 12 }
                Btn { label: "−"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.subSize = Math.max(14, win.subSize - 2) }
                Text { width: 36; height: parent.height; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; text: win.subSize; color: win.cInk; font.pixelSize: 13 }
                Btn { label: "+"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.subSize = Math.min(80, win.subSize + 2) }
                Item { width: 14; height: 1 }
                Text { width: 34; height: parent.height; verticalAlignment: Text.AlignVCenter; text: "싱크"; color: win.cDim; font.pixelSize: 12 }
                Btn { label: "−"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.subOffset -= 500 }
                Text { width: 46; height: parent.height; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter
                       text: (win.subOffset / 1000).toFixed(1) + "s"; color: win.cInk; font.pixelSize: 13 }
                Btn { label: "+"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.subOffset += 500 }
            }
        }
    }

    Timer {
        id: hideTimer
        interval: 2800
        onTriggered: if (player.playbackState === MediaPlayer.PlayingState && !barHover.hovered && !win.subMenuOpen && !win.qualityOpen) win.chrome = false
    }

    // ================= 창 가장자리 크기 조절 =================
    component Edge: MouseArea {
        property int edges: 0
        visible: win.visibility === Window.Windowed
        hoverEnabled: true
        z: 100
        onPressed: win.startSystemResize(edges)
    }
    Edge { edges: Qt.LeftEdge;  width: 5; anchors { left: parent.left; top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 } cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.RightEdge; width: 5; anchors { right: parent.right; top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 } cursorShape: Qt.SizeHorCursor }
    Edge { edges: Qt.TopEdge;   height: 5; anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 } cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.BottomEdge; height: 5; anchors { bottom: parent.bottom; left: parent.left; right: parent.right; leftMargin: 8; rightMargin: 8 } cursorShape: Qt.SizeVerCursor }
    Edge { edges: Qt.LeftEdge | Qt.TopEdge; width: 8; height: 8; anchors { left: parent.left; top: parent.top } cursorShape: Qt.SizeFDiagCursor }
    Edge { edges: Qt.RightEdge | Qt.BottomEdge; width: 8; height: 8; anchors { right: parent.right; bottom: parent.bottom } cursorShape: Qt.SizeFDiagCursor }
    Edge { edges: Qt.RightEdge | Qt.TopEdge; width: 8; height: 8; anchors { right: parent.right; top: parent.top } cursorShape: Qt.SizeBDiagCursor }
    Edge { edges: Qt.LeftEdge | Qt.BottomEdge; width: 8; height: 8; anchors { left: parent.left; bottom: parent.bottom } cursorShape: Qt.SizeBDiagCursor }

    // ================= 오른쪽 버튼 메뉴 =================
    MouseArea {
        anchors.fill: parent
        visible: win.ctxOpen
        z: 39
        acceptedButtons: Qt.AllButtons
        onPressed: win.ctxOpen = false
    }
    Rectangle {
        id: ctxMenu
        visible: win.ctxOpen
        z: 40
        x: win.ctxX; y: win.ctxY
        width: 256
        height: ctxCol.implicitHeight + 12
        radius: 12
        color: "#F2141620"
        border.color: win.cLine
        Column {
            id: ctxCol
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }
            spacing: 1
            Repeater {
                model: win.ctxItems
                delegate: Item {
                    readonly property var it: modelData
                    width: ctxCol.width
                    height: it.sep === true ? 9 : 30
                    Rectangle { visible: it.sep === true; anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; leftMargin: 6; rightMargin: 6 }
                                height: 1; color: win.cLine }
                    Rectangle {
                        visible: it.sep !== true
                        anchors.fill: parent; radius: 7
                        color: cma.containsMouse ? win.cHover : "transparent"
                        Text { anchors { left: parent.left; leftMargin: 10; verticalCenter: parent.verticalCenter }
                               text: win.ctxLabel(it) !== undefined ? win.ctxLabel(it) : ""; color: win.cInk; font.pixelSize: 13 }
                        Text { anchors { right: parent.right; rightMargin: 10; verticalCenter: parent.verticalCenter }
                               visible: it.id !== undefined && win.keymap[it.id] !== undefined && win.keymap[it.id] !== ""
                               text: it.id !== undefined ? win.keyLabel(it.id) : ""; color: win.cDim; font.pixelSize: 11 }
                        MouseArea { id: cma; anchors.fill: parent; hoverEnabled: true; onClicked: win.ctxDo(it.id) }
                    }
                }
            }
        }
    }

    // ================= 키보드 =================
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (e) {
            e.accepted = true
            var name = win.keyName(e)
            if (name === "" && e.key !== Qt.Key_Escape) return   // Shift/Ctrl 등 단독 키 (Esc 는 아래에서 처리)

            // 단축키 입력 대기 중
            if (win.capId !== "") {
                if (e.key === Qt.Key_Escape) { win.capId = ""; return }
                win.setKey(win.capId, e.key === Qt.Key_Delete ? "" : name)
                win.capId = ""
                return
            }
            // Esc: 열려 있는 창 → 전체화면 순서로 닫기
            if (e.key === Qt.Key_Escape) {
                if (win.ctxOpen) win.ctxOpen = false
                else if (win.helpOpen) win.helpOpen = false
                else if (win.qualityOpen) win.qualityOpen = false
                else if (win.subMenuOpen) win.subMenuOpen = false
                else if (win.plOpen) win.plOpen = false
                else if (win.fs) win.toggleFs()
                return
            }
            var act = win.keyToAction[name]
            // 다른 동작에 배정되지 않았다면 F 도 전체화면 (기존 습관 유지)
            if (act === undefined && name === "F") act = "fullscreen"
            if (act === undefined) { e.accepted = false; return }
            if (win.helpOpen && act !== "help") return
            win.doAction(act)
            win.showChrome()
        }
    }

    Component.onCompleted: {
        loadCfg()
        loadKeys()
        if (cfgGet("aiAtStart")) setAi(true)
        if (backend.startFiles.length > 0) setPlaylist(backend.startFiles, 0)
        else if (cfgGet("rememberPlaylist")) restorePlaylist()
        hideTimer.restart()
    }
}
