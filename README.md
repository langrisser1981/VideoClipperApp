# VideoClipperApp

一款簡單、鍵盤優先的 macOS 影片剪輯小工具：選擇本機影片 → 預覽播放 → 用鍵盤快速標記裁切區段（時間軸上以灰色顯示，播放時自動跳過）→ 一鍵輸出裁切後的影片。

詳細開發規劃請見 [`Docs/DEVELOPMENT_PLAN.md`](Docs/DEVELOPMENT_PLAN.md)。

## 快速上手

1. **匯入影片**：點「Choose File…」用檔案選擇器選一部本機影片（mp4 / mov / m4v），或把檔案路徑（或 `file://` 連結）貼到下方欄位後按「Load」。
2. **預覽播放**：按 `Space` 播放/暫停；用 `←` / `→` 微調 1 秒（長按會隨按住時間加速，最多到 10 秒），`Shift+←` / `Shift+→` 固定跳轉 10 秒。
3. **標記要剪掉的片段**：播放到片段開頭按 `I` 標記入點（時間軸上出現綠色標線），播放（或跳）到片段結尾按 `O` 標記出點，完成一組標記後才會出現灰色裁切區塊。重複這個動作可以標記多組要剪的片段。
   - 若已經按過 `I`，再按一次 `I` 會用新的位置取代舊的入點。
   - 入點與出點必須是不同位置——在同一個時間點按 `O` 不會建立任何區段，且入點標記會繼續保留，讓你重新選一個位置。
   - 必須先完成一組 `I`+`O`，才能再開始標記下一組。
4. **檢查與調整**：
   - 時間軸下方會列出所有已標記的片段（起訖時間），可捲動、按每一列的「Delete」按鈕直接刪除該片段。
   - 若播放頭目前正位於某個已標記的灰色區段內，按鍵盤 `Delete` 會直接刪除該區段（不需要先選取）；若剛按了 `I` 還沒按 `O`，`Delete` 會取消這個未完成的入點標記。
   - 按 `Cmd+Z` 復原上一步標記/刪除操作。
   - 繼續播放時，播放頭經過灰色區段會自動跳過，方便你直接預覽剪完的效果。
5. **輸出成品**：確認好所有要剪的片段後，按「Export…」按鈕或 `Cmd+E`。程式會用 `AVMutableComposition` 把「沒被標記」的片段接起來，輸出成 `原檔名.clipped.mp4`，存在原影片的同一個目錄。畫面下方會顯示匯出進度與完成訊息。

### 鍵盤快捷鍵一覽

| 按鍵 | 功能 |
|---|---|
| Space | 播放 / 暫停 |
| ← / → | 倒退 / 快轉 1 秒（長按加速，最多 10 秒） |
| Shift + ← / → | 倒退 / 快轉固定 10 秒 |
| Tab | 在「Choose File…」與「Export…」按鈕之間切換焦點 |
| I | 標記入點（裁切區段起點，重複按會取代前一個） |
| O | 標記出點（須與入點不同位置，完成一組標記） |
| Delete | 刪除播放頭目前所在的裁切區段（或取消未完成的入點標記） |
| Cmd + Z | 復原上一步標記操作 |
| Cmd + O | 開啟檔案選擇器匯入影片 |
| Cmd + E | 輸出影片 |

### 測試用影片

`Samples/sample-clip.mp4` 是用 ffmpeg 產生的 20 秒測試影片（含畫面與音軌），只存在本機、已被 `.gitignore` 排除不會進版控。若需要重新產生，可執行：

```bash
ffmpeg -y -f lavfi -i "testsrc=duration=20:size=1280x720:rate=30" \
  -f lavfi -i "sine=frequency=440:duration=20" \
  -c:v libx264 -pix_fmt yuv420p -c:a aac -shortest \
  Samples/sample-clip.mp4
```

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
- 最低系統需求：macOS 26 (Tahoe)+
- 測試：Swift Testing

## 開發狀態

Phase 0～4（專案設置、影片匯入與播放、鍵盤導覽與剪輯點標記、時間軸 UI 與自動跳過、輸出功能）皆已完成，57 個單元測試全數通過。剩餘為 Phase 5 打磨項目（App 圖示、簽署/公證、大檔案效能測試），詳見開發計劃書。
