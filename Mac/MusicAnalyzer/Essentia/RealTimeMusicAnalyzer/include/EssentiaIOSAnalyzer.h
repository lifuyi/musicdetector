//
//  EssentiaIOSAnalyzer.h
//  iOS Essentia 音频分析器
//
//  功能: BPM 检测, 调性分析, 音频特征提取
//  支持: iOS 12.0+, arm64/x86_64
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * 音频分析结果
 */
@interface EssentiaAnalysisResult : NSObject

@property (nonatomic, readonly) float bpm;                    // 节拍 (BPM)
@property (nonatomic, readonly) NSString *key;                // 调性 (C, D, E, F, G, A, B)
@property (nonatomic, readonly) NSString *scale;              // 音阶 (major, minor)
@property (nonatomic, readonly) float confidence;             // 置信度 (0.0-1.0)
@property (nonatomic, readonly) BOOL isValid;                 // 结果是否有效

- (instancetype)initWithBPM:(float)bpm key:(NSString *)key scale:(NSString *)scale confidence:(float)confidence;
- (NSString *)description;

@end

/**
 * Essentia iOS 音频分析器
 */
@interface EssentiaIOSAnalyzer : NSObject

@property (nonatomic, readonly) BOOL isAvailable;
@property (nonatomic, readonly) NSString *version;

// 单例模式
+ (instancetype)sharedAnalyzer;

// 主要分析方法
- (nullable EssentiaAnalysisResult *)analyzeAudioFile:(NSString *)audioFilePath;
- (nullable EssentiaAnalysisResult *)analyzeAudioFile:(NSString *)audioFilePath error:(NSError **)error;

// 单独功能
- (float)detectBPMFromAudioFile:(NSString *)audioFilePath;
- (float)detectBPMFromAudioFile:(NSString *)audioFilePath error:(NSError **)error;

- (NSString *)detectKeyFromAudioFile:(NSString *)audioFilePath;
- (NSString *)detectKeyFromAudioFile:(NSString *)audioFilePath error:(NSError **)error;

// 批量分析
- (NSArray<EssentiaAnalysisResult *> *)analyzeMultipleFiles:(NSArray<NSString *> *)audioFilePaths;

// 工具方法
+ (BOOL)isAudioFileSupported:(NSString *)filePath;
+ (NSArray<NSString *> *)supportedAudioFormats;

@end

/**
 * 错误码定义
 */
typedef NS_ENUM(NSInteger, EssentiaError) {
    EssentiaErrorNone = 0,
    EssentiaErrorFileNotFound = 1001,
    EssentiaErrorUnsupportedFormat = 1002,
    EssentiaErrorAnalysisFailed = 1003,
    EssentiaErrorMemoryError = 1004,
    EssentiaErrorNotAvailable = 1005
};

NS_ASSUME_NONNULL_END
