# 顶顶 App 图标设计方案（AI 生图提示词）

软件名已从 Pinnit 改为 **顶顶**，功能是「把通知/备忘固定到通知栏顶部」。
当前品牌主色：`#6750A4`（紫）。下面 5 个方向各有侧重，挑一个让 ChatGPT 生成即可。

> 通用要求（每个提示词都建议加上）：
> - 正方形 1024×1024，主体居中、四周留安全边距
> - 主体**单独、无外围文字**（带「顶」字的方案除外）
> - 最好给一版**透明背景**的，方便我做 Android 自适应图标（前景 + 纯色背景分离）
> - 小尺寸下仍清晰、高对比

---

## 方案 A ｜ 图钉直译（Pin）
最直观：一根红色图钉扎在一张小卡片上。
> Mobile app icon: a glossy red pushpin (thumbtack) piercing a small rounded white card, flat vector style, clean and minimal, centered on a solid violet background (#6750A4), high contrast, no text, 1024x1024 square. Provide a transparent-background version with the subject only, centered with padding.

## 方案 B ｜ 「顶」字 + 向上箭头（推荐，最贴名字）
把「顶」字和向上箭头结合，辨识度最高、最独特。
> Mobile app icon: a bold stylized Chinese character "顶" where the top stroke is integrated with an upward arrow pointing to the top, flat modern vector style, white character on a rounded-square gradient from violet (#6750A4) to indigo, clean, legible at small size, no extra text, high contrast, 1024x1024 square. Provide a transparent-background version with the subject only.

## 方案 C ｜ 通知气泡被钉住（最贴功能）
铃铛/气泡被图钉固定在顶部横条，直观表达「固定到顶部」。
> Mobile app icon: a notification bell inside a rounded speech bubble, with a thumbtack pinning the bubble to a horizontal bar at the top, symbolizing "pinned to top". Flat modern vector illustration, vibrant gradient background (violet to pink), clean, no text, 1024x1024 square. Provide a transparent-background version with the subject only.

## 方案 D ｜ 山峰 / 顶点（顶 = summit）
「顶」即顶点，极简山峰，温柔耐看。
> Minimalist 3D clay-style mountain peak / triangle summit icon, suggesting "top of the list", soft pastel violet and white, friendly and rounded, centered on a light violet rounded-square background, mobile app icon, clean, no text, 1024x1024 square. Provide a transparent-background version with the subject only.

## 方案 E ｜ 卡片被向上推（活泼）
一叠通知卡片被向上箭头顶起，呼应「顶一下 / 置顶」。
> Playful flat illustration app icon: a small stack of notification cards being pushed upward by a bold upward arrow, implying "bump to top". Warm gradient background (violet to coral), clean and friendly, no text, 1024x1024 square. Provide a transparent-background version with the subject only.

---

## 回传后我会做什么
1. 把图片转成 Android 各密度 mipmap（hdpi~xxxhdpi）+ 自适应图标（前景图 + 纯色/渐变背景）。
2. 替换 `android/app/src/main/res/mipmap-*/ic_launcher.png` 与 `ic_launcher_round.png`，并配置 `mipmap-anydpi/ic_launcher`（adaptive icon）。
3. 一并把已完成的「改名 + 新图标」打包成新的 release APK 给你测。

> 配色想换风格也行（比如改成蓝绿/橙），告诉我即可；不指定的话默认沿用品牌紫 #6750A4。
