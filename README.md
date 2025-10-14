# paper_loom

#### work-in-progress

Paper-Loom - 学術論文向けPDFリーダーの試作（開発初期段階） 、3つのAI機能を構想中：
```
>OCRによるPDF最適化・読みやすい形式への変換
>プロンプトベースのAI質問機能
>引用関係による論文推薦システム
```
技術構成：
```
Flutter（フロントエンド）
Python FastAPI（バックエンド）
```

#### 開発ロードマップ
```
フェーズ1： PDF OCR機能の実装、モバイル/タブレットでの論文閲覧最適化
フェーズ2： プロジェクトのリファクタリング
フェーズ3： UI日本語対応
フェーズ4： 単語長押しで中国語/日本語翻訳機能
フェーズ5： プロンプトベースのAI質問機能
フェーズ6： 引用関係による論文推薦システム
```
#### 現在の進捗
```
フェーズ1 基本機能実装完了
課題：
 Flutterでの数式表示に問題あり、
 Markdown以外のフォーマットへの切り替えを検討中
```

![screenshot](images/screenshot1.png)

## 起動方法
```bash
# バックエンド
cd backend
python -m app.main

# フロントエンド
cd mobile
flutter run
```