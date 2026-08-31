# 喵喵棒球 · 2D Baseball Lab

以可愛貓咪為主角的 Godot 4 2D 棒球遊戲原型，對應瀏覽器版與桌面／行動匯出。核心循環是「選球路 → 投球 → 抓時機揮棒 → 推進跑者 → 三局結算」。

## 操作

- `1`–`4`：選擇快速球、曲球、滑球或變速球
- `← ↑ → ↓` 或點擊 3×3 格：瞄準落點
- `Enter`／`T`：投球
- `Space`：揮棒
- `R`：重新開始

## 開發與驗證

需要 Godot 4.7.2 或更新版本。命令列檢查：

```sh
node --check game.js
godot --headless --path . --editor --quit --rendering-method gl_compatibility
godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --quit-after 180
```

瀏覽器版可直接以靜態伺服器開啟 `index.html`；`public/assets/generated/` 與 Godot 版共用同一批生成美術素材。

## 匯出

`export_presets.cfg` 包含 Windows Desktop、macOS Universal、Android arm64 與 iOS arm64 預設。Windows／macOS／Android 產物會放在 `build/`。Android debug APK 需要 JDK 17 與 debug keystore；iOS 仍需填入自己的 10 碼 Apple Team ID、憑證與 provisioning profile 才能產生可安裝或 TestFlight 用 IPA。

## 美術素材

角色、球場、徽章、球路教學與角色卡均放在 `assets/generated/`，並由 ImageGen 依照本專案的明亮動漫棒球方向生成，再以透明 PNG 整合至 Godot 與瀏覽器介面。
