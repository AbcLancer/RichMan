# PC、Android、iOS 打包

## 入口与产物

**本轮优先 PC，移动端配置仅预留，适配和真机验收待 PC 稳定后开展。**
Windows 双击根目录 `PACKAGE.bat`，选择 PC、环境检查或资源包验证。
菜单默认生成 PC Release 包；命令行不带 `--release` 时生成开发测试包。输出位于 `exports/<平台>/<时间>/`，每次独立目录：

| 目标 | 产物 | 使用方法 |
| --- | --- | --- |
| PC | `RichMan6-Windows.zip` | 解压后运行 EXE；EXE 和 PCK 必须放在一起 |
| Android | `RichMan6.apk` | 安装到 ARM64 Android 真机，允许安装本地 APK |
| iOS | Xcode 项目 ZIP | 在 Mac 上用 Xcode 签名，运行到 iPhone/iPad |
| pack | `RichMan6.pck` | 资源验证包，需要同版本 Godot；不是独立安装包 |

每次构建包含 `build.log` 和带文件大小、SHA256 的 `manifest.json`。
PC 导出后自动运行独立 EXE 的自检，结果写入 `validation.log`；只有自检全部通过才生成交付 ZIP。
现有自检框架退出时可能提示测试对象/资源尚未释放；流程只允许这一条已知的退出清理诊断，脚本、加载和断言错误仍会阻止交付。
缺依赖、导出报错、产物缺失时退出码非零，不报告成功。

## 一次性准备

1. 使用 **Godot 4.7.2 标准版**和 Python **3.9+**。通过 `GODOT_BIN` 环境变量或 `--godot` 指定引擎；Windows 会自动识别当前 `D:/Godot` 安装。
2. 在 Godot「编辑器 → 管理导出模板」中安装 **4.7.2.stable** 模板。离线模板可用 `GODOT_TEMPLATE_DIR` 指定包含平台模板文件的目录。
3. 保留完整的 `game/assets/`。该目录不进 Git，单独克隆仓库不会带素材；先在拥有原版素材的机器生成，或复制现有完整资源目录。
4. 复制 `build-config.example.json` 为 `build-config.local.json`，填写版本、版本号、自己的应用标识。iOS 再填写 Apple Team ID。私有配置和签名文件已加入忽略规则。

导出配置显式包含 `.json`、`.r6m`、`.r6v`，避免 Godot 默认过滤掉模型和玩法数据。
流程先导入素材，再导出和校验产物。构建临时填写版本与应用标识，结束或失败后恢复原导出配置。
同时打包会被锁拦截；如果进程被强制杀掉，确认没有构建进程运行后，检查并恢复 `game/export_presets.cfg`，再移除 `exports/.package.lock`。

## Windows PC

```powershell
.\PACKAGE.bat check pc --release
.\PACKAGE.bat build pc --release
```

目标为 Windows x86_64。发行 ZIP 不依赖用户安装 Godot。当前不做 Windows 代码签名。

## Android

安装 Android SDK 和 Java SDK，在 **Godot 编辑器设置 → Export → Android** 中填写两者路径。
JDK 17 是官方推荐版本；按[官方 Android 导出文档](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_android.html)准备当前 SDK 组件。
流程检查 Godot 4.7 的编辑器路径配置；自包含编辑器应使用常规用户配置模式。

```powershell
.\PACKAGE.bat check android
.\PACKAGE.bat build android
```

调试 APK 使用 Godot 的调试签名配置。若首次导出提示缺少调试密钥，先在 Godot 导出面板配置调试密钥。
USB 安装可用 SDK 的 `adb install -r <APK路径>`。

正式 APK 需准备自己的 keystore，将以下环境变量设置到构建进程：

- `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`
- `GODOT_ANDROID_KEYSTORE_RELEASE_USER`（密钥别名）
- `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD`

然后执行 `PACKAGE.bat build android --release`。密码不写入仓库，也不加入命令行或构建清单。
此流程生成直接安装的 APK。Google Play 的 AAB 需要另行启用 Gradle 构建和商店交付配置。

## iOS：在 Mac 上执行

将工程、`game/assets/`、本地配置复制到 Mac，安装同版本 Godot、导出模板、Python 和完整 Xcode。
在本地配置填写真实的 10 位 `ios_team_id`，在 Xcode 登录 Apple 开发账号。
[Godot 要求在 macOS 上使用 Xcode 导出 iOS](https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_ios.html)。

```sh
python3 tools/package_game.py check ios
python3 tools/package_game.py build ios --release
```

解压生成的 ZIP，打开 `.xcodeproj`，选择签名团队和连接的设备，执行 Run 即可真机安装。
导出配置带有局域网权限说明，第一次联机请允许 iOS 的本地网络访问。

自动导出 IPA：先通过 Xcode Organizer 手动导出一次所需分发方式，保存对应 `ExportOptions.plist` 为根目录 `ios-export-options.local.plist`，再执行：

```sh
python3 tools/package_game.py build ios --release --ios-ipa --export-options ios-export-options.local.plist
```

脚本自动找到 Xcode 项目、归档、签名并导出 `ipa/`。若项目有多个 Scheme，在本地 JSON 增加 `ios_scheme`。
证书、描述文件和目标设备授权仍需在 Mac 的开发账号中配置，Windows 无法生成可安装的 iOS 签名包。

## 验证与手机适配边界

```powershell
.\PACKAGE.bat build pack
# 替换成实际 PCK 路径：
D:\Godot\Godot_v4.7.2-stable_win64_console.exe --headless --main-pack exports\pack\<时间>\RichMan6.pck -- --selftest
```

移动端暂未适配。右键详情、拖动/旋转手势、小屏字号与按钮、系统字体、设备性能仍需真机适配测试。
每个平台至少验收：开局、买地建造、卡片/小神仙、音效、存档、后台恢复、两台设备联机。
素材量较大，先检查真机包体和内存表现；不能依据桌面验证承诺所有手机运行效果。

## 本轮验证记录

2026-10-12：已安装官方 Windows x86_64 Release 导出模板，生成 PC 独立 EXE + PCK + ZIP。
从系统临时目录启动独立 EXE，**533 项通过 / 0 失败**。打包保护逻辑另有 6 项测试。
修复两份音效扩展名大小写差异造成的打包后丢失，并让素材生成器后续自动规范文件名。
Android SDK 和移动端导出模板暂未安装；iOS 需 Mac。移动端按用户要求延后适配。
