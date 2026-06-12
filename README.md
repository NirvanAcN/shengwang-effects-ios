# iOS声网实时音视频接入SenseAR Effects特效引擎SDK集成Demo

本项目是**商汤科技**提供的[**特效引擎 SDK**](https://sensear.softsugar.com/) 在声网实时音视频基础上集成`SenseMe Effects`特效引擎（下称「Effects」）SDK的iOS演示工程。

> Public release pipeline test: this line verifies sanitized snapshot publishing to a temporary GitHub fork.



关于SenseAR Effects特效引擎iOS SDK详细介绍见[*仓库*](https://github.com/SoftSugar-Inc/effects-ios)。

---

## 快速运行APIExample-OC工程
1. 在`APIExample-OC`目录下执行`pod install`；
2. 将`APIExample-OC/Examples/Basic/JoinChannelVideo\(Token\)/st_mobile_sdk/license/SENSEME.lic`文件的内容更换为从商汤商务渠道获取的license文件（需要将名字改为"SENSEME.lic"）；
3. 将工程的`Bundle Identifier`修改为与上述license绑定的`Bundle Identifier`；
4. 完成工程编译及App在测试机的安装，运行Demo。
> 请[**提交免费试用申请**](https://sensear.softsugar.com/)，或**联系商务**（Tel: 181-1640-5190）获取测试license。

---

## 快速集成Effects SDK

> [详细接入文档](https://github.com/SoftSugar-Inc/effects-ios/blob/main/SenseMeEffects/st_mobile_sdk/docs/SenseAR%E9%9B%86%E6%88%90%E6%96%87%E6%A1%A3.md)

### 1. 导入SDK
将effect文件夹全部拖入工程中，Effects SDK依赖C++，在TARGETS -> Build Settings -> Linking -> Other LinkerFlags中添加 `-lc++`。
- 说明：effect文件内部Wrapper文件夹是对Effects SDK接口的OC封装，若直接调用Effects SDK提供的C接口进行开发则无需Wrapper。

### 2. 设置AgoraRtcEngineKit的AgoraVideoFrameDelegate监听以获取图像回调
1. 设置AgoraRtcEngineKit的AgoraVideoFrameDelegate监听
```objc
    [self.agoraKit setVideoFrameDelegate:self];
```
2. 在`onCaptureVideoFrame:sourceType:`中获取图像数据并通过Effects SDK为其添加特效。
```objc
#pragma mark - AgoraVideoFrameDelegate
- (BOOL)onCaptureVideoFrame:(AgoraOutputVideoFrame * _Nonnull)videoFrame sourceType:(AgoraVideoSourceType)sourceType {
    // process
    return YES;
}
```

### 3. 初始化特效引擎

1. 创建STMobileWrapper实例
2. 传入license鉴权等参数并初始化

```objc
#import "STMobileWrapper.h"
// 实例
@property (nonatomic) STMobileWrapper *stWrapper;

// 初始化并传入参数
NSString *modelPathOf106 = [[NSBundle mainBundle] pathForResource:@"M_SenseME_Face_Video_Template_p_4.0.0" ofType:@"model"]; // 所需的检测模型路径
NSString *licensePath = [[NSBundle mainBundle] pathForResource:@"SENSEME" ofType:@"lic"]; // license路径
self.stWrapper = [[STMobileWrapper alloc] initWithConfig:@{
    @"license": licensePath,
    @"config": @(STMobileWrapperConfigPreview),
    @"models": @[modelPathOf106]
} context:nil error:nil];

```
参数说明：
```
///   - config:字典，各字段如下
///   @{
///     @"license": licensePath, // license路径
///     @"config": @(STMobileWrapperConfigPreview), // STMobileWrapperConfigPreview预览、STMobileWrapperConfigImage图片、STMobileWrapperConfigVideo视频
///     @"models": @[modelPathOf106] // 模型路径
///    }
///   - context: 外部glcontext，若传nil则内部创建维护glcontext
///   - error: 错误信息
```

### 4. 设置特效以及强度
#### 设置
```objc
// 1.基础美颜功能
// 美白:zip包和mode方式各一个，美白4，mode3（默认开启美白4）
NSString *whitenPath = [[NSBundle mainBundle] pathForResource:@"whiten4" ofType:@"zip"];
[self.stWrapper setBeautyPath:EFFECT_BEAUTY_BASE_WHITTEN path:whitenPath error:nil];
[self.stWrapper setBeautyMode:EFFECT_BEAUTY_BASE_WHITTEN mode:EFFECT_WHITEN_3 error:nil];
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_BASE_WHITTEN strength:0.8 error:nil];

// 磨皮：mode4
[self.stWrapper setBeautyMode:EFFECT_BEAUTY_BASE_FACE_SMOOTH mode:EFFECT_SMOOTH_FACE_EVEN error:nil];
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_BASE_FACE_SMOOTH strength:0.8 error:nil];

// 红润
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_BASE_REDDEN strength:0.8 error:nil];

// 2.美型
// 瘦脸、小脸、窄脸、圆眼、大眼
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_RESHAPE_SHRINK_FACE strength:0.8 error:nil];
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_RESHAPE_ENLARGE_EYE strength:0.8 error:nil];
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_RESHAPE_SHRINK_JAW strength:0.8 error:nil];
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_RESHAPE_NARROW_FACE strength:0.8 error:nil];
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_RESHAPE_ROUND_EYE strength:0.8 error:nil];

// 3.微整形
// 小头，下巴
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_PLASTIC_THINNER_HEAD strength:0.8 error:nil];
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_PLASTIC_CHIN_LENGTH strength:0.8 error:nil];

// 4.滤镜（babypink）
NSString *filterPath = [[NSBundle mainBundle] pathForResource:@"filter_style_babypink" ofType:@"model"];
[self.stWrapper setBeautyPath:EFFECT_BEAUTY_FILTER path:filterPath error:nil];
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_FILTER strength:0.8 error:nil];

// 5.风格妆
NSString *stylePath = [[NSBundle mainBundle] pathForResource:@"oumei" ofType:@"zip"];
int stickerId = [self.stWrapper changePackage:stylePath error:nil];
[self.stWrapper setPackageBeautyGroup:stickerId type:EFFECT_BEAUTY_GROUP_FILTER strength:0.8 error:nil];
[self.stWrapper setPackageBeautyGroup:stickerId type:EFFECT_BEAUTY_GROUP_MAKEUP strength:0.8 error:nil];

// 6.单妆（口红）
NSString *lipstickPath = [[NSBundle mainBundle] pathForResource:@"1自然" ofType:@"zip"];
[self.stWrapper setBeautyPath:EFFECT_BEAUTY_MAKEUP_LIP path:lipstickPath error:nil];
[self.stWrapper setBeautyStrength:EFFECT_BEAUTY_MAKEUP_LIP strength:0.8 error:nil];

// 7.2D脸部贴纸
NSString *araleStickerPath = [[NSBundle mainBundle] pathForResource:@"bunny" ofType:@"zip"];
int stickerPackageId = [self.stWrapper changePackage:araleStickerPath error:nil];
```
#### 移除
```objc
[self.stWrapper removePackage:packageId error:nil];
```

### 5. 帧处理回调：在AgoraVideoFrameDelegate中为本地回调图像添加特效
buffer输入/输出
```objc
- (BOOL)onCaptureVideoFrame:(AgoraOutputVideoFrame * _Nonnull)videoFrame sourceType:(AgoraVideoSourceType)sourceType {
    if (_beautyIsOn) {
        videoFrame.pixelBuffer = [self.stWrapper processGetBufferByPixelBuffer:videoFrame.pixelBuffer rotate:0 captureDevicePosition:0 renderOrigin:NO error:nil];
    }else {
        videoFrame.pixelBuffer = videoFrame.pixelBuffer;
    }
    return YES;
}
```

参数说明：

```
//pixelBuffer：输入的原始图像数据buffer
//rotate：图像旋转角度
//position: 前后摄像头
//renderOrigin: renderPreview上渲染原始图像/sdk process后的图像（对比功能）
//error: error info
//return : 返回添加特效后的数据buffer
```


### 6. 资源销毁
由于Effects SDK的资源在STMobileWrapper中管理，保证STMobileWrapper对象正常释放即可（ARC）。

---

## 反馈

- 如果您在使用过程中有遇到什么问题，欢迎提交 [**issue**](https://github.com/SoftSugar-Inc/shengwang-effects-ios/issues)。
- 我们真诚地感谢您的贡献，欢迎通过 GitHub 的 fork 和 pull request 流程来提交代码。代码风格请参考[**Coding Guidelines for Cocoa**](https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/CodingGuidelines/CodingGuidelines.html)
