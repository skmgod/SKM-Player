import QtQuick
import QtMultimedia

Window {
    id: win
    width: 1280; height: 760
    minimumWidth: 1000; minimumHeight: 520
    visible: true
    color: "#07080C"
    flags: Qt.Window | Qt.FramelessWindowHint
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
        { id: "back5", label: "5초 뒤로", key: "Left" },
        { id: "fwd5", label: "5초 앞으로", key: "Right" },
        { id: "back30", label: "30초 뒤로", key: "Shift+Left" },
        { id: "fwd30", label: "30초 앞으로", key: "Shift+Right" },
        { id: "volUp", label: "볼륨 올리기", key: "Up" },
        { id: "volDown", label: "볼륨 내리기", key: "Down" },
        { id: "fullscreen", label: "전체화면 (화면 크게)", key: "Enter" },
        { id: "capture", label: "현재 화면 캡처 (원본 크기)", key: "C" },
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
        { id: "help", label: "사용 설명서", key: "F1" }
    ]

    // ---- 자막 상태 ----
    property var subTracks: []          // 외부 자막 파일 [{name, cues}]
    property int subSel: -1             // -1 끔, 0.. 외부, 1000+ 내장
    property bool subMenuOpen: false
    property int subOffset: 0           // ms (+ 이면 자막이 늦게 나옴)
    property int subSize: 30

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
    function nextTrack(auto) {
        if (playlist.length === 0) return
        if (auto && repeatMode === 2) { player.setPosition(0); player.play(); return }
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
    readonly property real vw: vo.sourceRect.width
    readonly property real vh: vo.sourceRect.height
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
        errorText = ""
        subTracks = []
        subSel = -1
        subOffset = 0
        loopA = -1; loopB = -1
        player.source = u
        var s = decodeURIComponent(u.toString())
        fileName = s.substring(s.lastIndexOf("/") + 1)
        resetView()
        var found = backend.findSubtitles(u.toString())
        if (found.length > 0) { subTracks = found; subSel = 0 }
        player.playbackRate = speeds[speedIdx]
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
        var p = backend.capture(vo.videoSink, fileName, Math.round(player.position))
        osd(p !== "" ? "캡처 저장됨 · 사진\\Player64X\\" + p : "캡처에 실패했습니다")
    }
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
        if (fs) { if (prevMax) showMaximized(); else showNormal() }
        else { prevMax = (visibility === Window.Maximized); showFullScreen() }
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
        case "back5": skip(-5); break
        case "fwd5": skip(5); break
        case "back30": skip(-30); break
        case "fwd30": skip(30); break
        case "volUp": setVolume(audio.volume + 0.05); break
        case "volDown": setVolume(audio.volume - 0.05); break
        case "fullscreen": toggleFs(); break
        case "capture": capture(); break
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
        case "help": helpOpen = !helpOpen; helpTab = 0; capId = ""; break
        }
    }

    MediaPlayer {
        id: player
        videoOutput: vo
        audioOutput: AudioOutput { id: audio; volume: 0.8 }
        onErrorOccurred: function (error, errorString) { win.errorText = errorString }
        onMediaStatusChanged: if (mediaStatus === MediaPlayer.EndOfMedia && duration > 0 && position >= duration - 1500) { win.chrome = true; win.nextTrack(true) }
        onPositionChanged: if (win.loopOn && position >= win.loopB) setPosition(win.loopA)
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
                        VideoOutput {
                            id: vo
                            anchors.fill: parent
                            fillMode: VideoOutput.PreserveAspectFit
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
            acceptedButtons: Qt.LeftButton | Qt.MiddleButton
            cursorShape: win.chrome ? Qt.ArrowCursor : Qt.BlankCursor
            property real sx; property real sy; property real px0; property real py0
            property bool moved: false
            onPressed: function (m) {
                win.subMenuOpen = false
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
        anchors.bottomMargin: win.chrome ? 176 : 44
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
            if (vids.length > 0) { win.setPlaylist(vids, 0); return }
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
        implicitWidth: Math.max(t.implicitWidth + 24, 34)
        height: 34; radius: 9
        color: ma.pressed ? "#33FFFFFF" : ma.containsMouse ? win.cHover : (on ? "#244DA3FF" : "transparent")
        Text { id: t; anchors.centerIn: parent; color: parent.on ? win.cAccent : parent.tint; font.pixelSize: 13 }
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
                   width: Math.min(implicitWidth, win.width - 700); anchors.verticalCenter: parent.verticalCenter }
            Text { visible: win.playlist.length > 1; text: (win.plIdx + 1) + " / " + win.playlist.length; color: win.cAccent; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
        }
        Row {
            anchors { right: parent.right; verticalCenter: parent.verticalCenter; rightMargin: 8 }
            spacing: 2
            Btn { label: "열기"; onClicked: win.openDialog() }
            Btn { label: "재생목록" + (win.playlist.length > 0 ? " " + win.playlist.length : ""); on: win.plOpen; onClicked: win.plOpen = !win.plOpen }
            Btn { label: "도움말 · 단축키"; on: win.helpOpen; onClicked: { win.helpOpen = !win.helpOpen; win.helpTab = 0; win.capId = "" } }
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

    // ================= 하단 패널 =================
    Rectangle {
        id: bar
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 18
        width: Math.min(parent.width - 36, 1100)
        height: 140
        radius: 18
        color: win.cPanel
        border.color: win.cLine
        visible: win.chrome

        MouseArea { id: barArea; anchors.fill: parent; hoverEnabled: true; onPositionChanged: win.showChrome() }

        // ---- 탐색 막대 ----
        Row {
            id: seekRow
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 18; rightMargin: 18; topMargin: 12 }
            height: 22; spacing: 12
            Text { width: 54; height: parent.height; verticalAlignment: Text.AlignVCenter; color: win.cDim; font.pixelSize: 12; text: win.fmt(player.position) }
            Item {
                id: seekItem
                width: parent.width - 54 * 2 - 24; height: parent.height
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
                    width: 14; height: 14; radius: 7; color: "white"
                    anchors.verticalCenter: parent.verticalCenter
                    x: (player.duration > 0 ? track.width * player.position / player.duration : 0) - 7
                }
                Rectangle {
                    visible: seekMa.containsMouse && player.duration > 0
                    x: Math.max(0, Math.min(seekItem.width - width, seekItem.hoverX - width / 2))
                    y: -30
                    width: tip.implicitWidth + 16; height: 24; radius: 7
                    color: "#F0181A22"; border.color: win.cLine
                    Text { id: tip; anchors.centerIn: parent; color: win.cInk; font.pixelSize: 12
                           text: win.fmt(Math.max(0, Math.min(1, seekItem.hoverX / seekItem.width)) * player.duration) }
                }
                MouseArea {
                    id: seekMa
                    anchors.fill: parent
                    hoverEnabled: true
                    function seekTo(x) { if (player.duration > 0) player.setPosition(Math.max(0, Math.min(1, x / width)) * player.duration) }
                    onPositionChanged: function (m) { seekItem.hoverX = m.x; if (pressed) seekTo(m.x) }
                    onPressed: function (m) { seekTo(m.x) }
                }
            }
            Text { width: 54; height: parent.height; horizontalAlignment: Text.AlignRight; verticalAlignment: Text.AlignVCenter; color: win.cDim; font.pixelSize: 12; text: win.fmt(player.duration) }
        }

        // ---- 왼쪽: 재생 ----
        Row {
            anchors { left: parent.left; top: seekRow.bottom; leftMargin: 14; topMargin: 8 }
            spacing: 2
            height: 44
            Btn { label: "|◀"; anchors.verticalCenter: parent.verticalCenter; enabled: win.playlist.length > 1; opacity: enabled ? 1 : 0.35; onClicked: win.prevTrack() }
            Btn { label: "⟲ 10"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.skip(-10) }
            Rectangle {
                width: 42; height: 42; radius: 21
                anchors.verticalCenter: parent.verticalCenter
                color: pma.pressed ? "#3A8EE6" : win.cAccent
                scale: pma.containsMouse ? 1.06 : 1
                Behavior on scale { NumberAnimation { duration: 90 } }
                Text {
                    anchors.centerIn: parent
                    anchors.horizontalCenterOffset: player.playbackState === MediaPlayer.PlayingState ? 0 : 2
                    text: player.playbackState === MediaPlayer.PlayingState ? "❚❚" : "▶"
                    color: "#06101C"; font.pixelSize: 15
                }
                MouseArea { id: pma; anchors.fill: parent; hoverEnabled: true; onClicked: win.togglePlay() }
            }
            Btn { label: "10 ⟳"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.skip(10) }
            Btn { label: "▶|"; anchors.verticalCenter: parent.verticalCenter; enabled: win.playlist.length > 1; opacity: enabled ? 1 : 0.35; onClicked: win.nextTrack(false) }
        }

        // ---- 가운데: 보기 도구(확대 / 옆으로 보기) ----
        Row {
            anchors { horizontalCenter: parent.horizontalCenter; top: seekRow.bottom; topMargin: 58 }
            spacing: 2
            height: 36
            Btn { label: "회전"; anchors.verticalCenter: parent.verticalCenter; on: win.rot !== 0; onClicked: win.rotate() }
            Btn { label: "좌우반전"; anchors.verticalCenter: parent.verticalCenter; on: win.flipped; onClicked: win.flip() }
            Btn { label: "비율 " + win.aspects[win.aspectIdx][0]; anchors.verticalCenter: parent.verticalCenter; on: win.aspectIdx !== 0; onClicked: win.cycleAspect() }
            Item { width: 8; height: 1 }
            Btn { label: "−"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.zoomBy(0.8) }
            Btn { label: Math.round(win.zoom * 100) + "%"; width: 62; anchors.verticalCenter: parent.verticalCenter; on: win.zoom !== 1
                  onClicked: { win.resetZoom(); win.osd("보기 초기화") } }
            Btn { label: "+"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.zoomBy(1.25) }
            Item { width: 8; height: 1 }
            Btn { label: "캡처"; anchors.verticalCenter: parent.verticalCenter; onClicked: win.capture() }
        }

        // ---- 오른쪽: 속도 / 자막 / 볼륨 / 전체화면 ----
        Row {
            anchors { right: parent.right; top: seekRow.bottom; rightMargin: 14; topMargin: 8 }
            spacing: 2
            height: 44
            Btn { label: win.speeds[win.speedIdx] + "x"; width: 52; anchors.verticalCenter: parent.verticalCenter; on: win.speeds[win.speedIdx] !== 1; onClicked: win.changeSpeed(1, true) }
            Btn { label: win.speeds[win.speedIdx] < 1 ? "슬로우 " + win.speeds[win.speedIdx] + "x" : "슬로우"; anchors.verticalCenter: parent.verticalCenter
                  on: win.speeds[win.speedIdx] < 1; onClicked: win.slowMo() }
            Btn { label: win.loopOn ? "구간반복 중" : win.loopA >= 0 ? "A 지정됨" : "구간반복"; anchors.verticalCenter: parent.verticalCenter
                  on: win.loopA >= 0; onClicked: win.abLoop() }
            Btn { label: "자막"; anchors.verticalCenter: parent.verticalCenter; on: win.subSel !== -1 || win.subMenuOpen; onClicked: win.subMenuOpen = !win.subMenuOpen }
            Item { width: 8; height: 1 }
            Text { anchors.verticalCenter: parent.verticalCenter; color: win.cDim; font.pixelSize: 12; text: "볼륨" }
            Item {
                width: 84; height: 34; anchors.verticalCenter: parent.verticalCenter
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

    // ================= 재생목록 패널 =================
    Rectangle {
        id: plPanel
        visible: win.plOpen && win.chrome
        anchors { right: parent.right; rightMargin: 18; top: parent.top; topMargin: 60; bottom: bar.top; bottomMargin: 12 }
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
        "<h3>캡처 · 전체화면</h3>" +
        "<p>• <b>캡처</b> 버튼(또는 <b>C</b> 키): 지금 보이는 장면을 영상 <b>원본 크기</b> 그대로 PNG 로 저장합니다. 저장 위치: <b>사진 \\ Player64X</b> 폴더<br>" +
        "• <b>Enter</b> 키(또는 더블클릭, F 키): 화면을 크게(전체화면). <b>Esc</b> 로 돌아옵니다.</p>" +
        "<h3>자막</h3>" +
        "<p>• 영상과 같은 이름의 자막 파일(SRT · SMI · VTT · ASS)이 있으면 자동으로 불러옵니다. 자막 파일을 창에 끌어놓아도 됩니다.<br>" +
        "• <b>자막</b> 메뉴에서 언어 선택, 글자 크기, 싱크(±0.5초)를 조절하세요. 영상에 내장된 자막도 고를 수 있습니다.<br>" +
        "• <b>실시간 자동 자막</b>: Windows 11 실시간 캡션을 켭니다. 언어는 캡션 창의 ⚙ 설정에서 고릅니다.</p>" +
        "<h3>재생목록</h3>" +
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
        anchors.right: bar.right
        anchors.rightMargin: 90
        anchors.bottom: bar.top
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
                MouseArea { id: oma; anchors.fill: parent; hoverEnabled: true; onClicked: win.openSubDialog() }
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
        onTriggered: if (player.playbackState === MediaPlayer.PlayingState && !barArea.containsMouse && !win.subMenuOpen) win.chrome = false
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

    // ================= 키보드 =================
    Item {
        anchors.fill: parent
        focus: true
        Keys.onPressed: function (e) {
            e.accepted = true
            var name = win.keyName(e)
            if (name === "") return                       // Shift/Ctrl 등 단독 키

            // 단축키 입력 대기 중
            if (win.capId !== "") {
                if (e.key === Qt.Key_Escape) { win.capId = ""; return }
                win.setKey(win.capId, e.key === Qt.Key_Delete ? "" : name)
                win.capId = ""
                return
            }
            // Esc: 열려 있는 창 → 전체화면 순서로 닫기
            if (e.key === Qt.Key_Escape) {
                if (win.helpOpen) win.helpOpen = false
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
        loadKeys()
        if (backend.startFiles.length > 0) setPlaylist(backend.startFiles, 0)
        hideTimer.restart()
    }
}
