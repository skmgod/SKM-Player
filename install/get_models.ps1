# AI 화질개선 모델(Real-ESRGAN compact, BSD-3-Clause)을 player8k\models 에 내려받습니다.
# 출처: https://github.com/xinntao/Real-ESRGAN/releases/tag/v0.2.5.0
$dir = Join-Path (Split-Path $PSScriptRoot -Parent) "player8k\models"
New-Item -ItemType Directory -Force $dir | Out-Null
$base = "https://github.com/xinntao/Real-ESRGAN/releases/download/v0.2.5.0"
foreach ($n in "realesr-general-x4v3.pth", "realesr-animevideov3.pth") {
    if (Test-Path (Join-Path $dir $n)) { Write-Host "이미 있음: $n"; continue }
    Write-Host "내려받는 중: $n"
    Invoke-WebRequest -Uri "$base/$n" -OutFile (Join-Path $dir $n) -UseBasicParsing
}
Write-Host "완료: $dir"
