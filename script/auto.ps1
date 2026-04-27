# ================================================
# COLMAP 自動登録スクリプト
# Hiroshi さん環境専用設定
# ================================================

# COLMAP 実行ファイルのパス
$colmap = "C:\Users\HT23A080\COLMAP-3.8-windows-no-cuda\COLMAP2.bat"

# 各フォルダパス設定
$base_path = "C:\Users\HT23A080\photogrammetry\colmapdata\colmap_images"
$prev_model = "$base_path\reconstruction_6_images\sparse\0"
$prev_db = "$base_path\reconstruction_6_images\database.db"
$new_project = "$base_path\reconstruction_7_images"
$new_imgs = "$new_project\imgs"
$new_db = "$new_project\final.db"
$new_model = "$new_project\new_model"

# ================================================
# 1. 既存DBをコピーして新規DBを作成
# ================================================
Write-Host "=== Step 1: Copy existing database ==="
if (Test-Path $new_db) {
    Remove-Item $new_db
}
Copy-Item $prev_db $new_db
Write-Host "Database copied to:" $new_db
Write-Host ""

# ================================================
# 2. 特徴量抽出
# ================================================
Write-Host "=== Step 2: Feature extraction ==="
& $colmap feature_extractor `
    --database_path $new_db `
    --image_path $new_imgs
Write-Host ""

# ================================================
# 3. 画像マッチング
# ================================================
Write-Host "=== Step 3: Image matching ==="
& $colmap exhaustive_matcher `
    --database_path $new_db
Write-Host ""

# ================================================
# 4. 既存モデルに新しい画像を登録
# ================================================
Write-Host "=== Step 4: Register new images ==="
if (!(Test-Path $new_model)) {
    New-Item -ItemType Directory -Path $new_model | Out-Null
}
& $colmap image_registrator `
    --database_path $new_db `
    --input_path $prev_model `
    --output_path $new_model
Write-Host ""

# ================================================
# 5. 完了メッセージ
# ================================================
Write-Host "=== Step 5: Done! ==="
Write-Host "新しいモデルが以下に保存されました："
Write-Host "→ $new_model"
Write-Host ""
Write-Host "出力フォルダ内に cameras.bin / images.bin / points3D.bin が生成されていれば成功です。"
Write-Host "========================================="





# SQLite コマンドで COLMAP データベース内の画像一覧を表示
$database = "C:\Users\HT23A080\photogrammetry\colmapdata\colmap_images\reconstruction_7_images\final.db"
sqlite3 $database "SELECT image_id, name FROM images;"


