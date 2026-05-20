param(
    [Parameter(Mandatory=$true)]
    [string]$Module
)

Set-Location $PSScriptRoot  # 设置工作目录为脚本所在目录

$BASE_PATH  = $PSScriptRoot
$FL_DIR     = Join-Path $BASE_PATH "fl"
$TB_DIR     = Join-Path $BASE_PATH "tb"
$BUILD_DIR  = Join-Path $BASE_PATH "build"

$FL_FILE    = Join-Path $FL_DIR "sim_${Module}.f"
$TB_FILE    = Join-Path $TB_DIR "tb_${Module}.v"
$OUT_FILE   = Join-Path $BUILD_DIR "sim_${Module}.out"
$VCD_FILE   = Join-Path $BUILD_DIR "tb_${Module}.vcd"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "Start Simulation Flow: $Module" -ForegroundColor Cyan
Write-Host "============================================================"

# 检查必要文件
if (-not (Test-Path $TB_FILE)) { Write-Error "TB not found: $TB_FILE"; exit 1 }
if (-not (Test-Path $FL_FILE)) { Write-Error "File List not found: $FL_FILE"; exit 1 }

# 确保 build 目录存在
if (-not (Test-Path $BUILD_DIR)) { New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null }

# 编译
Write-Host "[1/3] Compiling..." -ForegroundColor Green
# -f 读取文件列表，自动处理其中列出的所有文件
& "iverilog" -g2012 -o $OUT_FILE -f $FL_FILE $TB_FILE

if ($LASTEXITCODE -ne 0) { Write-Error "Compilation FAILED."; exit 1 }
Write-Host "Compilation SUCCESS: $OUT_FILE" -ForegroundColor Green

# 仿真
Write-Host "[2/3] Running Simulation..." -ForegroundColor Green
& "vvp" $OUT_FILE

# 波形
if ($LASTEXITCODE -ne 0) { Write-Error "Simulation FAILED."; exit 1 }

if (Test-Path $VCD_FILE) {
    Write-Host "[3/3] Launching GTKWave..." -ForegroundColor Green
    Start-Process "gtkwave" -ArgumentList $VCD_FILE
}
Write-Host "============================================================" -ForegroundColor Cyan
