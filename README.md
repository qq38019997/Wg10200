# CryptoTrader - AI 量化交易 App

Flutter 移动端应用，配套 AI 量化交易后端服务。

## 🚀 自动构建 APK

GitHub Actions 会在每次推送 main 分支时自动构建 debug APK。

下载步骤：
1. 进入仓库 Actions 标签
2. 点击最新的 `Build APK` workflow
3. 底部 Artifacts 下载 `debug-apk`
4. 解压得到 `app-debug.apk` 安装到手机

## 📱 服务器配置

- 后端地址：`http://47.82.76.6:8000`
- App 默认配置：`lib/services/api_service.dart` 中的 `baseUrl`
- 默认开启模拟盘模式

## 🎯 使用流程

1. 安装 APK，打开后填写服务器地址
2. 注册账号登录
3. 进入设置页 → 填写 OKX API Key
4. AI 工作台：自然语言生成策略
5. 策略详情：启动/停止/回测
6. 实时盈亏在策略卡片查看

## 🔧 技术栈

- Flutter 3.x + Dart
- dio (HTTP)
- fl_chart (图表)
- shared_preferences (本地存储)