# register_default_player.ps1 로 등록한 항목을 제거합니다 (HKCU 만).
$prog = "Player64X.Video"
$exts = ".mp4",".mkv",".avi",".mov",".wmv",".webm",".ts",".m2ts",".mts",".flv",".f4v",".m4v",".mpg",".mpeg",".3gp",".3g2",".ogv",".vob",".divx",".asf",".rm",".rmvb",".mxf"
foreach ($e in $exts) {
    Remove-ItemProperty -Path "HKCU:\Software\Classes\$e\OpenWithProgids" -Name $prog -ErrorAction SilentlyContinue
}
Remove-Item -Path "HKCU:\Software\Classes\$prog" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKCU:\Software\Classes\Applications\Player64X_8K.exe" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item -Path "HKCU:\Software\Player64X" -Recurse -Force -ErrorAction SilentlyContinue
Remove-ItemProperty -Path "HKCU:\Software\RegisteredApplications" -Name "Player64X" -ErrorAction SilentlyContinue
Write-Host "등록을 제거했습니다."
