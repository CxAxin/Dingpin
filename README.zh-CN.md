# 顶顶（Dingpin）

**顶顶**（Dingpin）是一款开源的安卓 App，可以**把笔记和通知「钉」在通知栏最上面**，让重要信息不再淹没在通知洪流里。

> 顶顶是基于开源项目 [Pinnit](https://github.com/msasikanth/pinnit)（作者 Sasikanth Miriyampalli，Apache-2.0 协议）二次开发的版本。原版 Pinnit（Kotlin）已归档；顶顶用 Flutter/Dart 重写，保留了「钉到通知栏」的核心思路，并新增了通知历史捕获等功能。署名与修改声明见 [`NOTICE`](NOTICE)，完整许可证见 [`LICENSE`](LICENSE)。

**English documentation:** [README.md](README.md)

---

## 功能特性

- **固定通知**：把通知以常驻（`ongoing`）形式钉在通知栏，通知栏里直接带「复制 / 取消固定」两个按钮。
- **新建 & 编辑**固定笔记 / 通知（标题 + 内容 + 固定开关）——就像贴在通知栏上的便利贴。
- **通知历史** 🆕——通过 `NotificationListenerService` 把**所有 App** 的通知（微信、短信、邮件等）记录成一个可搜索、按时间排序的列表。
- **从历史一键「顶」** 🆕——点一下任意一条被捕获的通知，立刻把它变成通知栏顶部的一条常驻通知（自动去重）。
- **给历史通知加备注**：给任意一条历史通知写批注。
- **导出历史**：把记录（与你自己顶出来的固定通知合并、去重）按时间范围（全部 / 一天 / 一周 / 一月）导出成文本文件，存到手机或用系统分享发出去。
- **搜索 & 过滤**：固定列表和历史列表都支持按标题或内容实时搜索。
- **多语言**：中文 / 英文 / 跟随系统。
- **亮 & 暗** Material 3 主题，可一键切换。
- **底部三栏导航**：固定 / 历史 / 关于。

> 需要 Android 8.0+，且开启**通知读取**权限（在系统设置里授权）才能使用历史功能。

---

## 下载

> 当前版本：**v2.6.7**（build 267）· 需 Android 8.0+

- 官方网站：**https://dingpin.app**
- 最新版 APK（arm64）：[百度网盘](https://pan.baidu.com/s/1JdR7dcFpXkfz_7w1TgnydA?pwd=csax)
- 通用版 APK（全架构）：[百度网盘](https://pan.baidu.com/s/1Gg2oYybI5WrUrmZ3LgdZsw?pwd=csax)

---

## 快速开始

### 环境要求

- [Flutter 3.19+](https://docs.flutter.dev/get-started/install)（stable）
- Android SDK（推荐 API 34）+ 模拟器或真机
- `flutter doctor` 不应报 Android 相关错误

### 运行 / 构建

> 本仓库已包含**完整的安卓工程**（Gradle wrapper、manifest、启动图标、通知监听注册）。你**不需要**执行 `flutter create .`——那样会覆盖自定义的 `AndroidManifest.xml` 并破坏监听配置。

```bash
# 1. 拉取依赖
flutter pub get

# 2. 在已连接的设备 / 模拟器上运行
flutter run

# 3. 构建 release APK
flutter build apk --release
# -> build/app/outputs/flutter-apk/app-release.apk
```

把 APK 传到手机安装。首次打开后，进入**历史**（顶栏图标），点**开启**，授予*通知读取*权限——这是顶顶能记录其他 App 通知的前提。

---

## 📱 把通知栏变成待办清单（使用场景与技巧）

> 以下内容整理自项目作者的两篇介绍文章，完整原文见文末「延伸阅读」。

你有没有过这种时候——微信里朋友发来一个快递取件码，想着「等会儿下楼取」，刷了两条朋友圈，那条消息就沉下去了；临时想记个待办，点开备忘录要翻好几步；通知栏里 99+ 条，想找刚才那条验证码，愣是滑了半天没翻到。

信息一多，重要的反而被淹了。顶顶能让它永远钉在通知栏。

### 它能帮你解决什么

1. **重要信息不再被冲走**：验证码、取件码、门牌号、临时密码……这些「看一眼就要用、用完就扔」的信息，固定到通知栏顶部，刷再多微信也冲不掉。
2. **懒得开备忘录时，随手记**：脑子里冒出个待办、一个购物项、一段想说的话，点开顶顶写一行保存，它就挂通知栏上了。比开备忘录快，还不用切来切去。
3. **通知栏不再找不到刚才那条**：固定通知常驻顶部，不用在通知流里翻。
4. **误删的通知能找回**：开启通知历史后，会自动记录手机收到的所有通知。哪天不小心把验证码划掉了，去历史里翻一下就能找回——相当于给通知栏加了个「回收站」。

### 三个让效率翻倍的小技巧

- **待办清单法**：把当天 3 件要事写成一条固定通知，做完一项就改一下重存，一天清清楚楚。
- **临时便签**：脑子里的事先钉上去，空了再处理，不占脑容量。
- **长文慢读**：看到想细读的内容先固定，碎片时间慢慢看，不怕被新通知盖掉。
- **通知回收站**：开启了历史功能后，重要通知误删也不慌。

---

## 📦 通知黑匣子：历史、一键顶、导出

顶顶还有个更「低调」的能力：把你手机收到的每一条通知，都悄悄存了下来。不限 App、不挑内容，微信、短信、购物、快递、日历提醒……只要你手机收到，它就在本地记一笔。相当于手机的「通知黑匣子」。

### 1. 所有 App 的通知，自动存档

开启「通知读取」后，手机收到的通知一条不落全记下来，微信、短信、购物、快递、日历提醒……全都进同一个列表，按时间排好。

### 2. 把历史里的通知，直接「顶」成固定通知

历史里某条通知，你觉得值得长期留着——比如朋友发来的地址、工作群里的会议时间——不用重新打字，在历史列表里找到它，点一下「顶」，立刻变成通知栏顶部一条固定通知（带「复制」「取消固定」两个按钮）。会自动去重：同一条内容不会重复钉两次。

### 3. 通知历史一键导出

想留个底时，顶顶支持按「全部 / 一天 / 一周 / 一月」导出成文本文件，存到手机或直接分享出去。导出的内容把「原始通知」和「你自己顶出来的固定通知」合并、自动去重。

### 进阶玩法

- **地址常驻**：朋友发来的聚餐 / 面试地址，从历史的「顶」一下钉到栏顶，到了地方不用翻聊天记录。
- **会议时间钉死**：工作群的会议时间，顶成固定通知，随时瞟一眼，不怕被新消息盖掉。
- **月度回顾**：月底导出一月的范围，看看这个月哪些 App 最吵。
- **给通知加备注**：某条历史通知还能写批注——「已处理」「待回复」「这是谁发的」，一条冷通知变成带上下文的备忘录。

---

## 🔋 后台保活设置（国产手机必看）

这是用这类工具最容易踩的坑：**小米、华为、OPPO、vivo 等国产手机，为了省电会杀后台，固定通知就可能消失。**

顶顶本身已经做了不少保活（开机自启、被杀后重新固定、前台常驻），但还差你手动开几个开关，它才能在你的手机上稳稳活着。下面以**小米 / Redmi（MIUI / HyperOS）**为例：

- **① 通知权限**：Android 13+ 首次保存时自动弹，允许即可。
- **② 自启动**：设置 → 应用设置 → 自启动管理 → 顶顶 → 开启。手机重启后它能自己起来。
- **③ 省电策略设为「无限制」**：设置 → 应用管理 → 顶顶 → 省电策略 → 无限制。不然系统会限制它后台运行。
- **④ 多任务锁定**：最近任务界面，长按顶顶的卡片 → 点「锁定」。清后台时不会把它一起清掉。
- **⑤ 锁屏清理白名单**：手机管家 → 省电优化 → 锁屏清理，把顶顶加入白名单，锁屏后不被清理。
- **⑥ 通知读取权限**（历史功能用）：在 App 里点开启，会跳到系统「通知使用权」设置，找到顶顶打开。

> 其他品牌路径类似，关键词就这几个：**自启动 / 自启管理**、**省电策略 / 电池优化 / 应用省电**、**多任务锁定 / 应用锁**。找不到就在设置里搜「顶顶」或「自启动」。

把这几步设好，固定通知基本就能长治久安了。

---

## 🔒 隐私与安全

一句大实话：

- **只存文字，不存图**：通知里的图片、头像它不碰。
- **纯本地，不上传**：所有记录只存在你手机里，没有账号、没有云同步、不会发到任何服务器。
- **随时可清**：历史页一键清空，想删就删，干干净净。

顶顶是个「黑匣子」，但钥匙只在你手里。你不放心，清空一次就什么都不剩。

---

## 延伸阅读

- 《我把通知栏变成了待办清单，效率直接翻倍！》— 潮汕阿幸（2026-07-27）：<https://mp.weixin.qq.com/s/ZavV82jLPP-FRyV6kcHFtg>
- 《通知一划就消失？我给手机装了个「通知黑匣子」》— 潮汕阿幸（2026-08-01）：<https://mp.weixin.qq.com/s/W6GZsox8K8526wZkdCYyHA>

---

## 项目结构

```
lib/
  main.dart                         # 入口：初始化 bridge + NotificationService
  app.dart                          # MaterialApp + 主题 + navigator key
  providers.dart                    # themeMode + 第三方通知导出
  data/
    notification_model.dart        # PinnitNotification（固定通知模型）
    third_party_notification.dart  # ThirdPartyNotification（历史捕获）
    app_database.dart              # sqflite 封装（v5 schema）
  repositories/
    notifications_repository.dart # Riverpod Notifier：固定列表 + 变更
    third_party_repository.dart   # Riverpod Notifier：历史列表 + 变更
  services/
    notification_service.dart      # flutter_local_notifications：固定/复制/取消固定
    notification_listener_bridge.dart # MethodChannel <-> 原生监听
    pins_bridge.dart               # 原生保活 / 重新固定 bridge
  notifications/
    notifications_screen.dart      # 首页列表 + 搜索
    notification_tile.dart         # 列表行 + 固定开关
    history_screen.dart            # 历史记录列表 + 备注 + 顶/导出
  editor/
    editor_screen.dart             # 新建/编辑 + 固定 UI
  about/
    about_screen.dart              # 关于 + 署名
  theme/theme.dart                 # M3 亮/暗
  utils/navigator_key.dart         # 通知点击深链
android/
  app/src/main/kotlin/com/pinnit/flutter/
    PinnitApplication.kt           # 缓存 FlutterEngine（后台监听）
    PinnitPins.kt                  # 原生固定/重新固定 bridge
    PinnitNotificationListenerService.kt # 捕获其他 App 的通知
  app/src/main/AndroidManifest.xml # 权限 + 监听服务注册
docs/
  NOTIFICATION_LISTENER.md         # 监听设计说明
```

---

## 许可证与署名

- 原版 **Pinnit** © 2020 Sasikanth Miriyampalli，基于 [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) 发布。
- 顶顶是衍生作品，其衍生部分同样以 **Apache-2.0** 提供。完整许可证见 [`LICENSE`](LICENSE)，署名与修改声明见 [`NOTICE`](NOTICE)。核心源文件顶部都带有「modified, derived from Pinnit」的声明。

包名：`com.pinnit.flutter`（沿用原移植版）。
