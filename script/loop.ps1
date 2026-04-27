# ================================================
# COLMAP 自動登録スクリプト（監視ループ版・姿勢表示付き）
# CapturedImages の新規画像を自動で登録
# final2.db に記録
# ================================================

$colmap      = "C:\Users\HT23A080\COLMAP-3.8-windows-no-cuda\COLMAP2.bat"
$base_path   = "C:\Users\HT23A080\photogrammetry\colmapdata\colmap_images"
$src_folder  = "$base_path\CapturedImages"
$new_project = "$base_path\reconstruction_7_images"
$new_imgs    = "$new_project\imgs"
$new_db      = "$new_project\final2.db"
$new_model   = "$new_project\new_model"
$prev_model  = "$base_path\reconstruction_6_images\sparse\0"
$prev_db     = "$base_path\reconstruction_6_images\database.db"

# 初期化
Write-Host "=== COLMAP Auto Registration Loop Start ==="

# DB作成
if (!(Test-Path $new_db)) { Copy-Item $prev_db $new_db }

# フォルダ作成
foreach ($folder in @($new_project, $new_imgs, $new_model, $src_folder)) {
    if (!(Test-Path $folder)) { New-Item -ItemType Directory -Path $folder | Out-Null }
}

# 登録済みファイルリスト
$registered = @{}
Get-ChildItem -Path $new_imgs -File | ForEach-Object { $registered[$_.Name] = $true }

# ================================================
# 無限ループで監視
# ================================================
while ($true) {

    # ============================================
    # Step 0: imgs → CapturedImages 自動投入
    # ============================================
    $source_imgs = "$base_path\imgs"
    $pending = Get-ChildItem -Path $source_imgs -File | Where-Object {
        $_.Extension -match '\.(jpg|jpeg|png)$' -and -not (Test-Path "$src_folder\$($_.Name)")
    }

    if ($pending.Count -gt 0) {
        $next = $pending[0]  # 1枚ずつ投入
        Write-Host "`n[Auto-Feed] Move: $($next.Name)" -ForegroundColor Cyan
        Copy-Item $next.FullName "$src_folder\$($next.Name)"
    }

    # ============================================
    # Step 1: CapturedImages 内の新しい画像をチェック
    # ============================================
    $files = Get-ChildItem -Path $src_folder -File | Where-Object { $_.Extension -match '\.(jpg|jpeg|png)$' }

    $new_detected = $false
    $new_files_added = @()

    foreach ($file in $files) {
        if ($registered.ContainsKey($file.Name)) { continue }

        Write-Host "`n=== New image detected: $($file.Name) ===" -ForegroundColor Red

        $target = Join-Path $new_imgs $file.Name
        Copy-Item $file.FullName $target
        $registered[$file.Name] = $true
        $new_detected = $true
        $new_files_added += $file.Name
    }

    # ============================================
    # Step 2: COLMAP 処理
    # ============================================
    if ($new_detected) {

        Write-Host "`n=== Feature extraction ==="
        & $colmap feature_extractor --database_path $new_db --image_path $new_imgs

        Write-Host "`n=== Image matching ==="
        & $colmap exhaustive_matcher --database_path $new_db

        Write-Host "`n=== Register new images ==="
        & $colmap image_registrator --database_path $new_db --input_path $prev_model --output_path $new_model

        # ============================================
        # Step 3: バイナリ → TXT 変換
        # ============================================
        Write-Host "`n=== Convert model to TXT ==="
        & $colmap model_converter --input_path $new_model --output_path $new_model --output_type TXT

        # ============================================
        # Step 4: 登録画像と姿勢を表示
        # ============================================
        $images_txt = Join-Path $new_model "images.txt"
        if (Test-Path $images_txt) {
            $lines = Get-Content $images_txt
            for ($i=0; $i -lt $lines.Count; $i++) {
                $line = $lines[$i].Trim()
                # 画像情報は ID, qw,qx,qy,qz, tx,ty,tz,..., name の行
                if ($line -match "^\d+") {
                    $parts = $line -split "\s+"
                    $name = $parts[-1]
                    $qw, $qx, $qy, $qz = $parts[1..4]
                    $tx, $ty, $tz = $parts[5..7]
                    if ($new_files_added -contains $name) {
                        Write-Host "$($name): Quaternion=($($qw),$($qx),$($qy),$($qz)) Translation=($($tx),$($ty),$($tz))" -ForegroundColor Red
                    } else {
                        Write-Host "$($name): Quaternion=($($qw),$($qx),$($qy),$($qz)) Translation=($($tx),$($ty),$($tz))"
                    }
                }
            }
        }

        Write-Host "`n=== Processing done ==="
    }

    Start-Sleep -Seconds 5
}
