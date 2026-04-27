# study_colmap
colmapの勉強   
## 目的  
SLAM-viewer の代替手法として、COLMAP を試用し、ICP マッチングによる点群の位置・姿勢整合が可能かを検証することを目的とする。
## colmapとは何なのか
colmapとは画像から3次元の構造を復元するためのオープンソースのPhotogrammetryソフトウェア  
<sub>複数の2D画像から3次元の点群データやカメラの位置推定を行うことができる
### 主な機能
Structure-from-Motion（SfM）機能←複数の画像からカメラの位置と3Dの点を推定します  
Multi-View Stereo（MVS）機能←SfMで得られたカメラ位置を使って、より詳細な3Dモデルを作ることができる（密な点群）
## 使い方
### Processin編
Processing→Feature extractionは特徴点抽出。  
「どの特徴点をどうやって抽出するか」に関する設定。  
Processing→Feature matchingは特徴点マッチング。  
「どの画像ペア同士を比べてマッチさせるか」や「どうやってマッチの質を評価するか」を細かく制御する設定。  
### Reconstruction編
ReconstructionはSfMを実行。特徴点抽出→マッチング→カメラの位置推定まで。  
Structure from Motionは(SfM)処理を開始。複数画像からカメラ位置・3D点群を求める。  
Pause reconstructionは処理を一時停止。  
Reconstruction next imageは逐次的にマッチング＆位置推定を行う手動モード。  
Reset Reconstructionは再構成状態をリセット。  
Normalize reconstructionは座標系やスケールを調整して見やすくするもの。  
Reconstruction optionsは再構成の詳細設定（マッチングの制限やバンドル調整条件など)  
Bundle adjustmentはカメラ位置と3D点を最適化する処理。  
Dense Reconstructionは点群の密度を上げる。  
### Render編
Renderは3Dビューの表示を制御するためのもの。  
Disable renderingは3D表示を無効する。  
Reset viewはビューを初期状態に戻す。  
Render optionsは表示方法やスタイルの設定を変更する。
## COLMAPの非リアルタイム性
### カメラの動き  
全ての画像を先に集めてから、あとで一括で計算。
### 空間マッピング  
オフラインで特徴点を抽出・マッチング・再構成  
### 3D配置  
全体を再構成したあとでのみ確認可能。  
## colmapのproject作成
[file→new projectで保存先を指定]  
[databaseはdatabase.dbを作成or既存の.dbを選択]  
[imagesは処理対象の画像フォルダの選択]  
![スクリーンショット 2025-05-26 145645](https://github.com/user-attachments/assets/d33e7337-02b7-4ed8-9d72-4451c636d941)  
### テキストファイルの生成方法
file→一番下のExport model as textを画像の特徴点マッチングを終えてから行うと生成される  
###  １フレーム毎のマッチングについて  
colmapでのフレーム毎のマッチングでは、画像を一枚、一枚継ぎ足してく方式の流れになる。
手順としては、  
最初に1枚目の画像だけを使って特徴抽出。  
次に2枚目を追加し、1枚目とのマッチングだけを実行。  
次に3枚目を追加し、2枚目とだけマッチング … のように繰り返す。
## 座標系
## データベースについて 
・画像名やサイズ情報  
・特徴点  
・特徴記述子  
・特徴点同士のマッチング結果  
・カメラパラメータ  
といった情報を保存するのがSQLite形式データベース。つまり「SfM処理の中間キャッシュ」 
※実行時に保存される
### データベースでできること  
・feature_extractor で抽出された特徴点をDBに格納。同じ画像を使って再計算するときに再抽出の必要がない  
・exhaustive_matcher や vocab_tree_matcher の結果を保存.どの画像とどの画像が対応しているかを記録  
・カメラパラメータの管理  
・部分的な処理の追加.既存のDBに新しい画像を追加して再登録可能.  
image_registrator がこの仕組みを利用している  
・可視化・解析用のデータ取り出し.SQLiteなので、一般的なDBツールやPythonのsqlite3で開ける  
特徴点数やマッチング数を統計的に調べられる  
## image_registratorの手順  
1.初期再構成（元の5枚の画像）。まず最初に5枚の画像から通常通りSfMを行う。  
2.新しい画像を追加する準備。reconstruction_7_images/imgs/ に、もともとの5枚＋新しい1枚を入れる.  
新しい画像の名前だけを new_images.txt に書きます.  
reconstruction_7_images\final_db.dbを作成。final_db.db = 「コピーして名前を変えただけの既存DB」  
これは新しい画像を追加する準備用のDBであり、コピーして作るだけなので、この時点では追加画像の情報はまだ入っていない。  
3.新しい画像の特徴量抽出。ここで追加画像だけの特徴量がDBに追加される。下記がCLIで使うコマンドだ。  
colmap feature_extractor \  
--database_path ./reconstruction_6_images/final_db.db \  
--image_path ./reconstruction_6_images/imgs \  
--image_list_path ./reconstruction_6_images/new_images.txt  
※database_pathは特徴点・マッチングを格納する「データベースファイル」で元のreconstructに含まれていた情報を壊さず、final.dbに新しい画像の特徴量を追記する役割。続いてimage_list_pathはフォルダ全体ではなく、「リストに書かれた画像だけ」を処理対象にしてこのフォルダに入っている画像のうち、このファイルに書いた画像だけ新しく特徴量を抽出してデータベースに追加するように指定する役割。ついでに最後のimage_pathだが、初期再構成（元の5枚の画像）＋追加したい画像を含んだフォルダの指定である。  
4.マッチング（語彙木or exhaustiveなど）大量の画像があるならvocad_tree_matcherの使用が効率的。小規模ならexhaustiveで可  
5.画像を既存モデルに登録。新しい画像を既存モデルに追加する.   
6.出力の確認.  　  
## cmd操作
# ディレクトリー構成  
project/  
├─ images/          # 入力画像  
├─ database.db      # COLMAP データベース  
├─ sparse/          # 推定結果（外部パラメータ）  
└─ dense/           # （本研究では未使用）
# 特徴点  
colmap feature_extractor ^  
 --database_path database.db ^  
 --image_path images  




