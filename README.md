# 好好拍 · haohaopai

> 打开 App，对准拍摄目标，AI 智能分析实时取景画面，以交互提示的方式帮你拍出一张「摄影大师级」的照片。

「好好拍」是一个 **Flutter 编写的 iOS 拍照引导 App**。它把「拍照」这件靠手感的事，变成了一场有 AI 在场外指导的创作：你负责对准目标，AI 负责告诉你该怎么构图、怎么用光、怎么调角度。

核心差异：**它不是在照片拍完之后做「点评」，而是在你按下快门之前、对着取景框的那一刻，就用多模态大模型看懂你眼前的画面，并给出针对当前画面的、具体到细节的建议。**

---

## 核心功能

| 功能 | 说明 |
|------|------|
| 📷 相机拍摄 | 原生 iOS 相机，支持前后置切换、丝滑变焦、网格线、曝光、闪光灯、多种画幅（4:3 / 1:1 / 16:9） |
| 🧠 AI 实时指导（教我拍） | 捕获当前取景画面 → 多模态模型分析 → 返回 4 条可执行建议 |
| 💬 建议气泡交互 | 建议按「焦点 / 构图 / 色彩 / 光线」分布在画面四周，点开可看详细说明 |
| 🖼 专属相册 | 拍好的照片自动存入系统「好好拍」相册，支持预览、滑动浏览、删除 |
| 🔐 Apple 登录 | Sign in with Apple，本地保存登录态与个性化昵称 |

---

## 多模态模型的使用妙处

这是整个 App 的灵魂，值得单独说明。传统「拍照指导」App 靠的是**固定的规则模板**（比如永远弹一句"请把主体放在九宫格交叉点"），无论你拍的是人、是杯子还是风景，它说的都一样。好好拍换了一种思路：

### 1. 用「视觉理解」替代「规则引擎」

直接把相机取景框的实时画面丢给多模态模型（`qwen3-vl-plus`），让模型**自己"看"懂画面**，再产出建议。

它能做到规则引擎永远做不到的事——比如识别出画面里是「一个外星人电解质水瓶，旁边有鼠标、工牌、车钥匙等杂物」，然后给出：

> 将水瓶移至画面右 1/3 处，鼠标置于左下角作前景锚点，形成「瓶→牌→门」的 Z 字形视觉动线。

这就是多模态模型的价值：**它不只是"识别物体"，而是理解场景语义，并把它翻译成摄影语言。** 每张画面都是独特的，建议也是独特的。

### 2. Prompt 即产品

我们把「专业摄影师 + 摄影导师」这个角色写进提示词，让模型从 4 个维度（构图、主体与焦点、光线与曝光、色彩与对比）审视画面。**模型的输出专业度，直接决定了产品的上限**——这份提示词就是核心资产，远比代码更值钱。

### 3. 结构化输出，零 NLP 后处理

通过 `response_format: json_object` 强制模型输出严格 JSON，前端拿到后**直接解析成气泡渲染**，不需要任何文本清洗、正则抽字段之外的复杂后处理。模型的可控性被利用到了极致。

### 4. 在快门之前，而非成片之后

关键时机：分析的是**取景框里的实时预览帧**（约 260KB 的压缩帧），而不是已经拍好的成片。这让 AI 从"事后点评"变成了"事前指导"——你照着建议调整，按下快门的那一刻就是大片。

### 5. 优雅降级，不中断体验

当网络失败或模型返回格式异常时，自动降级到内置的默认建议，保证用户永远能拿到结果，不会卡在等待里。

---

## 运行原理

### 核心链路（「教我拍」）

```
用户点击「教我拍」按钮
        │
        ▼
GuideAction: 捕获相机实时预览帧（原生 iOS 侧）
        │   NativeCameraService.captureCurrentPreviewFrame()
        ▼
AiTipProvider: 状态机切到「分析中」，展示扫描动画
        │
        ▼
AiTipService → ImageAnalysisService
        │   图片字节 → base64 编码
        ▼
POST https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions
        │   model: qwen3-vl-plus
        │   response_format: {type: json_object}
        │   content: [摄影导师提示词, {image_url: data:image/jpeg;base64,...}]
        ▼
返回 JSON（4 个维度）
        │
        ▼
正则提取 + json.decode → List<ShootingTip>
        │
        ▼
AiTipAnimation: 气泡渲染在画面四周，点开查看详情
```

### 状态机

`AiTipProvider` 用简单的状态机驱动整个交互：

```
initial ──点击教我拍──▶ analyzing ──成功──▶ showingTips
                          │
                          └──失败/异常──▶ error（降级默认建议）
```

---

## 技术栈

- **Flutter** 3.16+ / Dart 3.2+
- **相机**：原生 iOS AVFoundation，通过 MethodChannel / EventChannel 与 Flutter 通信；支持双摄虚拟设备丝滑变焦
- **多模态模型**：通义千问 `qwen3-vl-plus`（阿里云 DashScope，OpenAI 兼容协议）
- **状态管理**：`provider` + `ChangeNotifier`
- **网络**：`dio`
- **相册**：`photo_manager` + 原生相册 MethodChannel
- **登录**：`sign_in_with_apple`

---

## 目录结构

```
lib/
├── main.dart                     # 入口、Provider 注册、路由、SplashScreen
├── login/                        # Apple 登录（auth_provider / login_page）
├── home/                         # 主页（个人资料 + 相册）、消息、设置
├── camera/
│   ├── screens/                  # 相机主界面 / 相册 / 照片预览
│   ├── services/                 # 相机服务、原生相机、相册服务
│   ├── state/                    # 全局相机状态管理器（单例）
│   ├── controls/                 # 闪光/曝光/变焦/网格/画幅/切换等控件
│   ├── actions/                  # 拍照 / 相册 / 教我拍 动作组件
│   └── layout/                   # 相机界面布局参数计算
└── aitips/                       # ★ AI 拍摄建议核心
    ├── models/                   # AiTip / ShootingTip 数据模型
    ├── providers/                # AiTipProvider 状态机
    ├── services/                 # AiTipService / ImageAnalysisService（调模型）
    └── widgets/                  # 建议气泡动画、分析扫描动画
```

---

## 快速开始

### 环境要求

- macOS + Xcode（iOS 真机/模拟器）
- Flutter SDK ≥ 3.16

### 运行

```bash
# 1. 安装依赖
flutter pub get

# 2. 查看已连接设备
flutter devices

# 3. 运行到真机（相机功能需真机，模拟器无摄像头）
flutter run -d <device-id>

# 或运行到 iOS 模拟器（仅能看 UI，无法测相机）
flutter run
```

> ⚠️ **真机签名**：首次真机构建需要 iOS 开发证书与已同意的开发者协议。
> 在 Xcode → Settings → Accounts → Manage Certificates 中生成「iOS Development」证书。
> 同时需在 Runner target 的 Signing & Capabilities 中启用 **Sign in with Apple** 能力（登录页只有 Apple 登录入口）。

---

## AI 接入说明

分析服务实现在 `lib/aitips/services/image_analysis_api.dart`，调用通义千问多模态模型：

- **Endpoint**：`https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`
- **Model**：`qwen3-vl-plus`
- **认证**：`Authorization: Bearer <DashScope API Key>`
- **输入**：摄影导师提示词 + base64 编码的取景画面
- **输出**：`json_object`，4 个维度字段：
  ```json
  {
    "构图与画面布局": "...",
    "主体与焦点": "...",
    "光线与曝光": "...",
    "色彩与对比": "..."
  }
  ```

---

## 注意事项

- 🔑 **API Key 安全**：目前 DashScope API Key 直接写在源码中，正式发布前应迁移到服务端或安全存储（Keychain），避免泄露。
- ⏱️ **响应延迟**：`qwen3-vl-plus` + 详细四维输出的响应时间约 20–30s，与「实时指导」的体验目标（≤1.5s）还有差距，是当前首要优化点。
- 📸 **图片压缩**：取景帧目前原图 base64 上传，`flutter_image_compress` 依赖已就位但尚未接入，后续应压缩到 1MB 内以降低成本与延迟。

---

## License

Private project, not published.
