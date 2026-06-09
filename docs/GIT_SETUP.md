# Git + GitHub 启动指南

> 第一次把 `gas-dive-flutter` 推到 GitHub 远程，并开启 CI。

---

## 1. 本地 git init + 第一个 commit

在 PowerShell 跑：

```powershell
cd S:\GMP\gas-dive-flutter

# 初始化仓库
git init
git branch -M main

# 检查 .gitignore 是否拦住了不该进 git 的（build/.dart_tool/Pods 等）
git status

# 看看哪些会被加进来（应该是源代码 + docs + workflow，不包含 build/）
git add -n .
```

⚠️ 如果 `git status` 列出了 `**/build/**` 或 `**/.dart_tool/**` 之类的目录，先停下检查 `.gitignore`。

如果看着正常：

```powershell
git add .
git commit -m "feat: P0-P1 Flutter monorepo 骨架

- packages/dive_calc: MOD/END/EADD/NDL 算法 + 31 个单测
- packages/mixer_core: 混气分压算法 (理想气体 MVP) + 17 个单测
- apps/mixer: Flutter App 骨架 + MixCalcPage 主页
- docs/: SETUP / IOS_CONFIG / GIT_SETUP / IPAD_COMPATIBILITY 占位
- CI: GitHub Actions (Linux test + Android build)
"
```

---

## 2. 创建 GitHub 远程仓库

### 2.1 在 GitHub 网页建仓库

1. 浏览器打开 https://github.com/new
2. **Repository name**: `gas-dive-flutter`
3. **Owner**: 你的 GitHub 用户名（或 organization）
4. **Visibility**: **Private**（推荐 — 跟 gas-dive-mixer / gas-dive-plan 保持一致）
5. **不要勾** Initialize this repository with：
   - ❌ Add a README file
   - ❌ Add .gitignore
   - ❌ Choose a license

   （我们本地已经有这些）
6. 点击 **Create repository**

### 2.2 关联远程 + push

GitHub 会给你显示一个 URL，类似 `git@github.com:your-name/gas-dive-flutter.git`。本地：

```powershell
# SSH 协议（推荐，需要本地 SSH key 已挂到 GitHub）
git remote add origin git@github.com:your-name/gas-dive-flutter.git

# 或 HTTPS（每次 push 要输 GitHub token）
# git remote add origin https://github.com/your-name/gas-dive-flutter.git

git push -u origin main
```

第一次 push 成功后，GitHub 网页刷新就能看到你的代码 + CI 已经跑起来。

---

## 3. CI 第一次运行

push 完几秒钟内：

1. GitHub 仓库页 → **Actions** tab
2. 应该看到一个 `CI` workflow 跑起来
3. 两个 job 并行：
   - **Test pure Dart packages** — 跑 dive_calc + mixer_core 的 dart test，约 1 分钟
   - **Build & analyze Flutter App** — 跑 flutter analyze + build apk，约 5-10 分钟（首次缓存空）

期望两个 job 都绿。

### 3.1 build-app job 可能踩坑

- **flutter create . 在 CI 上跑**：CI 端 `android/` 目录不在 git 里（默认 flutter create 后由 git 跟踪部分文件，但全套不进），workflow 检测到没 `android/` 会自动 `flutter create . --platforms android` 补齐
- **widget_test.dart 失败**：flutter create 默认生成的 counter demo 测试跟我们的 `MixCalcPage` 不匹配，workflow 已加 `continue-on-error: true`，不阻断流程

### 3.2 看 CI 结果

绿色 ✓ = 全过；红色 ✗ = 失败。点开看哪一步出错。常见失败：

- `dart test` 失败 → 算法实现有 bug 或测试用例错
- `flutter analyze --fatal-infos` 失败 → 代码 lint 警告（dead_code、unused_import、prefer_const 之类），按提示修
- `flutter build apk` 失败 → Android SDK 版本问题，看 log 调 `gradle-wrapper.properties`

---

## 4. 把 Android 平台壳进 git（一次性）

为了让 CI 不每次都 `flutter create . --platforms android`（慢且不稳），建议把 `android/` 目录加进 git：

```powershell
cd S:\GMP\gas-dive-flutter\apps\mixer

# 如果还没 flutter create
flutter create . --org cn.diveplan --project-name mixer

cd ..\..

# 加进 git
git add apps/mixer/android apps/mixer/ios apps/mixer/web apps/mixer/windows apps/mixer/macos apps/mixer/linux
git status

# 看哪些进来了，确认没把 build/ Pods/ 之类带进来
git commit -m "chore: 加 flutter 平台壳 (android/ios/web/desktop)"
git push
```

加完之后 CI 里的 `if [ ! -d "android" ]; then ... fi` 兜底就用不到了，每次 push 都不用再 flutter create。

---

## 5. 后续日常 workflow

```powershell
# 写代码
git status                          # 看改了哪些
git diff                            # 看具体改动

# 提交
git add .                           # 或 git add <specific files>
git commit -m "feat: 加 deco.ts Dart 翻译

- packages/deco/ 新建
- 翻译 ZHL-16C Bühlmann + GF 模型
- 26 个单测，对照 mixer/tests/neon-deco-literature.test.ts 预期值
"

# 推到远程
git push

# 拉远程更新（多机协作时 Mac 端跑）
git pull
```

### 5.1 Commit 风格建议（Conventional Commits）

格式：`<type>: <subject>`

| type | 用途 | 例子 |
|---|---|---|
| feat | 新功能 | `feat: 加 Trimix 混气 picker` |
| fix | 修 bug | `fix: drain 算法浮点边界处理` |
| refactor | 重构（行为不变） | `refactor: 抽出 _summaryRow 组件` |
| test | 加测试 | `test: 补 mixer_core 边界用例` |
| docs | 文档 | `docs: 更新 SETUP.md Mac 章节` |
| chore | 杂项（依赖、配置） | `chore: 升级 Flutter 3.45` |
| ci | CI 改动 | `ci: 加 iOS macOS runner` |
| style | 格式化（不改行为） | `style: dart format` |

详细说明换行后写一段 body（保持每行 ≤ 72 字符）。

### 5.2 双机协作（Windows + Mac）

```powershell
# Windows 端
git push

# Mac 端
git pull
flutter pub get
flutter run -d ios
```

⚠️ 第一次 Mac 拉下来跑 iOS 时，可能需要 `cd ios && pod install`（如果 `.gitignore` 把 `Podfile.lock` 也忽略了，那 Mac 端要重新 install）。

---

## 6. 分支策略（团队大了再启用）

当前阶段一个 `main` 分支够用。团队 ≥ 2 人后建议：

- `main` ← 受保护，只接 PR
- `develop` ← 集成分支
- `feat/xxx` ← 功能分支，merge 到 develop
- `release/x.y.z` ← 发布分支
- `hotfix/xxx` ← 紧急修复，直接到 main

GitHub Settings → Branches → Branch protection rules 配置：

- Require pull request before merging
- Require status checks to pass before merging（勾上 CI 的 jobs）
- Require branches to be up to date before merging
