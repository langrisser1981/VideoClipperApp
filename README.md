# VideoClipperApp

一款簡單、鍵盤優先的 macOS 影片剪輯小工具：選擇本機影片 → 預覽播放 → 用鍵盤快速標記裁切區段（時間軸上以灰色顯示，播放時自動跳過）→ 一鍵輸出裁切後的影片。

詳細開發規劃請見 [`Docs/DEVELOPMENT_PLAN.md`](Docs/DEVELOPMENT_PLAN.md)。

## 專案結構

```
VideoClipperApp/
├── Sources/     # App 原始碼（App/Models/ViewModels/Views/Services/Utilities）
├── Resources/   # 圖示與 Asset Catalog
├── Tests/       # 單元測試 / UI 測試
└── Docs/        # 規劃與設計文件
```

## 技術棧

- Swift + SwiftUI（播放層使用 AppKit 的 AVPlayerView）
- AVFoundation（AVPlayer / AVMutableComposition / AVAssetExportSession）
- 最低系統需求：macOS 13 (Ventura)+

## 開發狀態

專案剛啟動，目前為 Phase 0（專案設置）。詳見開發計劃書中的階段與里程碑。
