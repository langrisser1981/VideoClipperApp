# VideoClipperApp 開發計劃書

## 1. 專案概述

一款專注於「快速剪片」的 macOS 原生小工具。使用者可以選擇本機影片或貼上檔案連結，於畫面上預覽播放，透過鍵盤快捷鍵快速前後移動播放位置、標記剪輯的入點（In Point）與出點（Out Point）。入點與出點之間的片段會在時間軸上以灰色標示為「將被裁切」，播放時會自動跳過該區段。使用者可以重複標記多組裁切區段，最後一次性輸出成新的影片檔案。

核心價值：比起開啟 Final Cut Pro / iMovie 這類完整剪輯軟體，這款工具追求「開啟 → 看片 → 按鍵標記 → 輸出」的極簡、鍵盤優先的操作流程，適合快速去除影片中不需要的片段（例如冗長的靜默、NG片段、廣告等）。

## 2. 目標使用者與使用情境

- 需要快速剪掉影片中片段（而非做複雜剪輯特效）的一般使用者。
- 錄製教學影片、遊戲實況、會議錄影後，需要移除中間冗餘片段的人。
- 偏好鍵盤操作、追求效率，不想學習複雜剪輯軟體 UI 的使用者。

## 3. 功能需求

### 3.1 匯入影片
- 透過檔案選擇器（NSOpenPanel）選擇本機影片檔案（mp4, mov, m4v 等 AVFoundation 支援格式）。
- 支援貼上檔案路徑或 file:// 連結（貼上後自動載入）。
- V1 階段先支援本機檔案，是否支援遠端 URL（http/https 串流）列為 V2 討論項目。

### 3.2 影片預覽播放
- 使用 AVPlayer + AVPlayerView（或自訂 AVPlayerLayer）顯示影片畫面。
- 提供基本播放/暫停控制（滑鼠點擊 + 空白鍵）。
- 顯示目前播放時間 / 總長度。

### 3.3 鍵盤快速導覽
- 左右方向鍵：逐幀或固定秒數（如 1/30 秒、1 秒）前後移動。
- Shift + 方向鍵：更大幅度跳轉（如 5 秒 / 10 秒）。
- 空白鍵：播放 / 暫停。
- 可考慮 J / K / L（業界標準剪輯鍵）作為進階選項。

### 3.4 標記剪輯點
- 快捷鍵設定「入點」（例如按 `I`）與「出點」（例如按 `O`）。
- 入點與出點之間的區段即為「待裁切區段」。
- 支援連續標記多組裁切區段（重複按 I/O 建立多個區段）。
- 時間軸（Timeline / Scrubber）上，被標記的裁切區段以灰色色塊呈現。
- 播放頭經過灰色區段時自動跳過（不播放該段內容），直接跳到下一個未裁切區段的起點。

### 3.5 裁切區段管理
- 可檢視目前所有已標記的裁切區段列表（起訖時間）。
- 可刪除／復原（Undo）某個已標記的裁切區段。
- 可清除全部標記，重新開始。

### 3.6 輸出
- 使用者確認所有裁切區段後，按下輸出（例如 Cmd+E 或畫面上的輸出按鈕）。
- 使用 AVMutableComposition 組合「未被標記為裁切」的片段，產生新的影片。
- 使用 AVAssetExportSession 匯出結果（可選擇畫質 preset，如 Highest Quality / 1080p 等）。
- 顯示匯出進度與完成通知，輸出檔案預設存放於原檔案同目錄或使用者指定路徑。

### 3.7 非目標（V1 不做）
- 多軌剪輯、轉場特效、字幕、調色等進階剪輯功能。
- 雲端協作、專案分享。
- 音訊獨立剪輯。

## 4. 技術選型

| 項目 | 選擇 | 說明 |
|---|---|---|
| 開發語言 | Swift | macOS 原生開發首選 |
| UI 框架 | SwiftUI（搭配 AppKit 橋接） | 現代化、開發速度快；影片播放層使用 AppKit 的 AVPlayerView 以取得完整控制權 |
| 影片播放/處理 | AVFoundation（AVPlayer, AVPlayerItem, AVMutableComposition, AVAssetExportSession） | 系統原生框架，效能佳、格式相容性高 |
| 最低系統需求 | macOS 26 (Tahoe) 以上 | 採用最新 SwiftUI / Swift 6 API，不考慮舊系統相容性負擔 |
| 專案管理 | Xcode 專案 (.xcodeproj / Swift Package) | 標準 macOS App 開發流程 |
| 版本控制 | Git | 已於本機建立 repo |
| 測試 | Swift Testing（`@Test`） | 單元測試（時間軸邏輯、裁切區段計算）+ 基本 UI 測試 |

## 5. 系統架構設計

```
VideoClipperApp/
├── Sources/
│   ├── App/                # App 進入點、主視窗設定
│   ├── Models/              # ClipSegment, TimelineState 等資料模型
│   ├── ViewModels/          # PlayerViewModel, TimelineViewModel
│   ├── Views/                # PlayerView, TimelineView, ControlsView
│   ├── Services/             # VideoImportService, ExportService, KeyboardShortcutHandler
│   └── Utilities/            # 時間格式化、AVFoundation 輔助工具
├── Resources/                # 圖示、Asset Catalog
├── Tests/                    # 單元測試 / UI 測試
└── Docs/                     # 規劃文件、設計筆記
```

### 5.1 核心資料模型
- `ClipSegment`：代表一個「待裁切」區段，包含 `startTime` 與 `endTime`（CMTime）。
- `TimelineState`：管理目前所有 `ClipSegment`、目前播放頭位置、目前的 in/out 標記暫存狀態。
- `PlayerViewModel`：包裝 AVPlayer，處理播放控制、時間監聽（periodic time observer）、自動跳過裁切區段的邏輯。

### 5.2 自動跳過裁切區段邏輯
利用 AVPlayer 的 `addPeriodicTimeObserver` 持續監控目前播放時間，若偵測到播放頭進入任一 `ClipSegment` 範圍，立即呼叫 `seek(to:)` 跳到該區段的 `endTime`，達到「播放時自動跳過灰色區段」的效果。

### 5.3 輸出流程
1. 讀取原始 AVAsset 的完整時間長度。
2. 計算所有「未被標記為裁切」的區段（即完整時間軸扣除所有 ClipSegment 後剩下的部分）。
3. 使用 AVMutableComposition，依序將這些保留區段的影像與音訊軌插入新的 composition。
4. 透過 AVAssetExportSession 匯出成新檔案。

## 6. 鍵盤快捷鍵一覽（初版提案）

| 按鍵 | 功能 |
|---|---|
| Space | 播放 / 暫停 |
| ← / → | 倒退 / 快轉（單位可設定，如 1 秒） |
| Shift + ← / → | 倒退 / 快轉（大跳，如 5 秒） |
| I | 設定入點（裁切區段起點） |
| O | 設定出點（裁切區段終點，完成一組標記） |
| Delete / Backspace | 刪除目前選取的裁切區段 |
| Cmd + Z | 復原上一步標記操作 |
| Cmd + E | 輸出影片 |

（快捷鍵可於後續使用者測試階段調整，並考慮加入偏好設定頁面讓使用者自訂。）

## 7. 開發階段與里程碑

### Phase 0：專案設置（0.5 天）
- 建立 Xcode 專案、目錄結構、Git 初始化（已完成）。
- 設定基本 App 骨架（SwiftUI App + 空白主視窗）。

### Phase 1：影片匯入與播放（2-3 天）
- 實作檔案選擇（NSOpenPanel）與貼上路徑功能。
- 整合 AVPlayer，完成基本播放/暫停/拖曳時間軸功能。
- 顯示影片畫面與時間資訊。

### Phase 2：鍵盤導覽與剪輯點標記（2-3 天）
- 實作鍵盤事件監聽（NSEvent local monitor 或 SwiftUI onKeyPress）。
- 實作前後移動播放位置邏輯。
- 實作入點/出點標記，產生 ClipSegment 並存入 TimelineState。

### Phase 3：時間軸 UI 與自動跳過（2-3 天）
- 實作自訂時間軸元件，顯示播放進度與已標記的灰色裁切區段。
- 實作播放時自動跳過裁切區段邏輯。
- 支援刪除/復原已標記區段。

### Phase 4：輸出功能（2-3 天）
- 實作 AVMutableComposition 組合保留區段邏輯。
- 整合 AVAssetExportSession，加入匯出進度顯示與完成提示。
- 錯誤處理（不支援格式、匯出失敗等）。

### Phase 5：測試、打磨與封裝（2-3 天）
- 撰寫單元測試（區段計算、時間軸邏輯）。
- 手動測試多種影片格式與邊界情況（例如標記區段重疊、涵蓋全片等）。
- UI 細節打磨（快捷鍵提示、空狀態畫面等）。
- App 圖示、簽署（code signing）、打包發佈（.app / 之後可考慮 notarization）。

**預估總工時：約 10-15 個工作天（單人開發，不含美術與進階功能）。**

## 8. 風險與待確認事項

- 遠端影片連結（URL）匯入是否為必要需求？串流影片的裁切/輸出邏輯較複雜，建議 V1 先聚焦本機檔案。
- 剪輯區段重疊、涵蓋整段影片等邊界情況需要明確定義行為（例如自動合併重疊區段）。
- 大型影片檔案（如 4K、長時間錄影）的匯出效能與記憶體使用，需要在開發中期進行效能測試。
- 是否需要支援音訊獨立處理（例如維持原始音訊不變）。
- App 是否需要上架 App Store（涉及 sandbox、簽署、審查規範），或僅供個人/內部使用（可較彈性處理檔案存取權限）。

## 9. 後續（V2 展望，非本次範圍）
- 支援遠端影片連結直接匯入與剪輯。
- 快捷鍵自訂與偏好設定頁面。
- 匯出格式/畫質選項擴充。
- 簡單轉場或淡入淡出效果。
- 剪輯專案儲存/讀取（目前保留區段狀態），方便中斷後繼續編輯。
