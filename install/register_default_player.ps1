# Player 64X 를 Windows '기본 앱' 목록에 등록합니다 (현재 사용자 HKCU 만 수정, 관리자 권한 불필요).
# 등록 후 열리는 설정 창에서 확장자별로 'Player 64X' 를 선택하면 기본 플레이어가 됩니다.
param(
    [string]$Exe = (Join-Path (Split-Path $PSScriptRoot -Parent) "dist8k\Player64X_8K\Player64X_8K.exe")
)

if (-not (Test-Path $Exe)) { Write-Host "exe 를 찾을 수 없습니다: $Exe"; Read-Host "엔터를 누르면 닫힙니다"; exit 1 }

$prog = "Player64X.Video"
$exts = ".mp4",".mkv",".avi",".mov",".wmv",".webm",".ts",".m2ts",".mts",".flv",".f4v",".m4v",".mpg",".mpeg",".3gp",".3g2",".ogv",".vob",".divx",".asf",".rm",".rmvb",".mxf"
$cmd  = "`"$Exe`" `"%1`""

function Set-Default($path, $value) {
    New-Item -Path $path -Force | Out-Null
    Set-ItemProperty -Path $path -Name "(default)" -Value $value
}

# 1) 프로그램 ID
Set-Default "HKCU:\Software\Classes\$prog" "Player 64X 동영상"
Set-Default "HKCU:\Software\Classes\$prog\DefaultIcon" "`"$Exe`",0"
Set-Default "HKCU:\Software\Classes\$prog\shell\open\command" $cmd

# 2) 애플리케이션 등록 ('연결 프로그램' 목록용)
$app = "HKCU:\Software\Classes\Applications\Player64X_8K.exe"
Set-Default "$app\shell\open\command" $cmd
Set-ItemProperty -Path $app -Name "FriendlyAppName" -Value "Player 64X" -ErrorAction SilentlyContinue

# 3) 기능(Capabilities) + 기본 앱 목록 등록
$cap = "HKCU:\Software\Player64X\Capabilities"
New-Item -Path "$cap\FileAssociations" -Force | Out-Null
Set-ItemProperty -Path $cap -Name "ApplicationName" -Value "Player 64X"
Set-ItemProperty -Path $cap -Name "ApplicationDescription" -Value "가벼운 8K 동영상 플레이어 (개발자SKM)"
foreach ($e in $exts) {
    Set-ItemProperty -Path "$cap\FileAssociations" -Name $e -Value $prog
    New-Item -Path "HKCU:\Software\Classes\$e\OpenWithProgids" -Force | Out-Null
    New-ItemProperty -Path "HKCU:\Software\Classes\$e\OpenWithProgids" -Name $prog -Value "" -PropertyType String -Force | Out-Null
}
New-Item -Path "HKCU:\Software\RegisteredApplications" -Force | Out-Null
Set-ItemProperty -Path "HKCU:\Software\RegisteredApplications" -Name "Player64X" -Value "Software\Player64X\Capabilities"

Write-Host "등록 완료. 이제 설정 창에서 'Player 64X' 를 기본 앱으로 선택하세요."
Start-Process "ms-settings:defaultapps"
