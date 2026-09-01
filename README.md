# 喵喵棒球 · 2D Baseball Lab

以可愛貓咪為主角的 Godot 4 2D 棒球遊戲原型，對應瀏覽器版與桌面／行動匯出。核心循環是「選球路 → 投球 → 抓時機揮棒 → 推進跑者 → 三局結算」。

目前版本是 **1.1.0**：規則層從 UI 抽出，Godot 與瀏覽器共用同一套球路／時機／跑者判定。開賽前先選角色與球隊；客隊先攻、主隊後攻，三出局後攻守轉換。

## 操作

- 開賽前先選角色與球隊（喵白白隊主場後攻，喵布布隊客場先攻）
- 打擊半局：投手會在 3–15 秒內自動投球，`Space` 揮棒
- 守備半局：`Enter`／`T` 投球，對手自動揮棒
- `1`–`4`：選擇快速球、曲球、滑球或變速球
- `← ↑ → ↓` 或點擊 3×3 格：瞄準落點
- `R`：回到選角畫面重新開始

## 架構

- `game_rules.gd` / `game-rules.js`：球路表、時機視窗、擊球分布、跑者推進與保送
- `game_session.gd`：Godot 比賽狀態機
- `main.gd`：介面與輸入
- `stadium_view.gd`：球場繪製（閒置時停止每幀重繪）
- `game.js`：瀏覽器操作層，直接呼叫 `MeowRules`

## 開發與驗證

需要 Godot 4.7.2 或更新版本。命令列檢查：

```sh
node --check game.js game-rules.js
node tests/game-rules.test.js
godot --headless --path . --script tests/test_game_rules.gd --quit
godot --headless --path . --editor --quit --rendering-method gl_compatibility
godot --headless --path . --rendering-method gl_compatibility --audio-driver Dummy --quit-after 180
```

瀏覽器版可直接以靜態伺服器開啟 `index.html`；`public/assets/generated/` 與 Godot 版共用同一批生成美術素材。

## 匯出

`export_presets.cfg` 包含 Windows Desktop、macOS Universal、Android arm64 與 iOS arm64 預設。Windows／macOS／Android 產物會放在 `build/`。Android debug APK 需要 JDK 17 與 debug keystore；iOS 仍需填入自己的 10 碼 Apple Team ID、憑證與 provisioning profile 才能產生可安裝或 TestFlight 用 IPA。

## 美術素材

角色、球場、徽章、球路教學與角色卡均放在 `assets/generated/`，並由 ImageGen 依照本專案的明亮動漫棒球方向生成，再以透明 PNG 整合至 Godot 與瀏覽器介面。
