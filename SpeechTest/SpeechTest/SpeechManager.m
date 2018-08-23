//
//  SpeechManager.m
//  SpeechTest
//
//  Created by huangjian on 2018/8/22.
//  Copyright © 2018年 huangjian. All rights reserved.
//

#import "SpeechManager.h"
#import <AVFoundation/AVFoundation.h>
#include "lame.h"
#import <Speech/Speech.h>

@interface SpeechManager ()<AVAudioRecorderDelegate,SFSpeechRecognitionTaskDelegate,AVAudioPlayerDelegate>
@property (nonatomic,copy) NSString *cafPathStr;
@property (nonatomic,copy) NSString *mp3PathStr;
@property (nonatomic,strong) AVAudioRecorder *audioRecorder;//音频录音机

@property (nonatomic ,strong) SFSpeechRecognitionTask *recognitionTask;

@property(nonatomic,strong) SFSpeechRecognizer *recognizer;

@property(nonatomic,strong) AVAudioPlayer *audioPlayer;

@property (nonatomic,copy)PlayDown playEnd;

@end

static NSString *kCafFileName=@"myRecord.caf";
static NSString *kMp3FileName=@"myRecord.mp3";
@implementation SpeechManager
+(instancetype)shareInstance
{
    static SpeechManager * singleClass = nil;
    static dispatch_once_t onceToken ;
    dispatch_once(&onceToken, ^{
        singleClass = [[SpeechManager alloc] init] ;
    }) ;
    
    return singleClass ;
}
#pragma mark - 开始录音
-(void)startRecord
{
    self.cafPathStr = [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:kCafFileName];
    self.mp3PathStr =  [[NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject] stringByAppendingPathComponent:kMp3FileName];
    //请求语音识别的权限
    [SFSpeechRecognizer requestAuthorization:^(SFSpeechRecognizerAuthorizationStatus status) {
        NSLog(@"%ld",(long)status);
        switch (status) {
            case SFSpeechRecognizerAuthorizationStatusNotDetermined:
                NSLog(@"设备不支持");// Device isn't permitted
                break;
            case SFSpeechRecognizerAuthorizationStatusDenied:
                NSLog(@"用户拒绝授权");// User said no
                break;
            case SFSpeechRecognizerAuthorizationStatusRestricted:
                NSLog(@"暂时不清楚"); // Don't know yet
                break;
            case SFSpeechRecognizerAuthorizationStatusAuthorized:
                NSLog(@"授权成功");// Good to go
                [self startRecorder];
                break;
            default:
                break;
        }
    }];
}
#pragma mark - 有权限开始录音
-(void)startRecorder
{
    if (!self.audioRecorder) {
        return;
    }
    if ([self.audioRecorder isRecording]) {
        [self.audioRecorder stop];
    }
    NSLog(@"----------开始录音----------");
    [self deleteOldRecordFile];
    
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayAndRecord error:nil];
    
    if (![self.audioRecorder isRecording]) {//0--停止、暂停，1-录制中
        [self.audioRecorder record];//首次使用应用时如果调用record方法会询问用户是否允许使用麦克风
    }
}
#pragma mark - 停止录音，caf转mp3
-(void)stopRecord
{
    if (self.audioRecorder) {
        [self.audioRecorder stop];
        [self audio_PCMtoMP3];
    }
}
#pragma mark - caf转mp3
- (void)audio_PCMtoMP3
{
    
    @try {
        int read, write;
        
        FILE *pcm = fopen([self.cafPathStr cStringUsingEncoding:1], "rb");  //source 被转换的音频文件位置
        fseek(pcm, 4*1024, SEEK_CUR);                                   //skip file header
        FILE *mp3 = fopen([self.mp3PathStr cStringUsingEncoding:1], "wb");  //output 输出生成的Mp3文件位置
        
        const int PCM_SIZE = 8192;
        const int MP3_SIZE = 8192;
        short int pcm_buffer[PCM_SIZE*2];
        unsigned char mp3_buffer[MP3_SIZE];
        
        lame_t lame = lame_init();
        lame_set_in_samplerate(lame, 11025.0);
        lame_set_VBR(lame, vbr_default);
        lame_init_params(lame);
        
        do {
            read = fread(pcm_buffer, 2*sizeof(short int), PCM_SIZE, pcm);
            if (read == 0)
                write = lame_encode_flush(lame, mp3_buffer, MP3_SIZE);
            else
                write = lame_encode_buffer_interleaved(lame, pcm_buffer, read, mp3_buffer, MP3_SIZE);
            
            fwrite(mp3_buffer, write, 1, mp3);
            
        } while (read != 0);
        
        lame_close(lame);
        fclose(mp3);
        fclose(pcm);
    }
    @catch (NSException *exception) {
        NSLog(@"%@",[exception description]);
    }
    @finally {
        NSLog(@"MP3生成成功: %@",self.mp3PathStr);
        
        //初始化一个识别器
        SFSpeechRecognizer *recognizer = [[SFSpeechRecognizer alloc] initWithLocale:[NSLocale localeWithLocaleIdentifier:@"zh_CN"]];
        self.recognizer=recognizer;
        //初始化mp3的url
        NSURL *url=[NSURL fileURLWithPath:self.mp3PathStr];
        //初始化一个识别的请求
        SFSpeechURLRecognitionRequest *request = [[SFSpeechURLRecognitionRequest alloc] initWithURL:url];
        
        self.recognitionTask=[recognizer recognitionTaskWithRequest:request delegate:self];
        
    }
}
#pragma mark - speechRecognitionTask 代理
- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishRecognition:(SFSpeechRecognitionResult *)recognitionResult
{
    NSLog(@"----%@",recognitionResult.bestTranscription.formattedString);
    if ([self.delegate respondsToSelector:@selector(didFinishRecognition:)]) {
        [self.delegate didFinishRecognition:recognitionResult.bestTranscription.formattedString];
    }
}
- (void)speechRecognitionTask:(SFSpeechRecognitionTask *)task didFinishSuccessfully:(BOOL)successfully {
    if (successfully) {
        NSLog(@"全部解析完毕");
    }else
    {
        NSLog(@"解析失败");
        if ([self.delegate respondsToSelector:@selector(didFinishRecognition:)]) {
            [self.delegate didFinishRecognition:nil];
        }
    }
}
#pragma mark - 删除录音文件
-(void)deleteOldRecordFile{
    NSFileManager* fileManager=[NSFileManager defaultManager];
    
    BOOL blHave=[[NSFileManager defaultManager] fileExistsAtPath:self.cafPathStr];
    if (!blHave) {
        NSLog(@"不存在");
        return ;
    }else {
        NSLog(@"存在");
        BOOL blDele= [fileManager removeItemAtPath:self.cafPathStr error:nil];
        if (blDele) {
            NSLog(@"删除成功");
        }else {
            NSLog(@"删除失败");
        }
    }
}
#pragma mark - 获得录音机对象

-(AVAudioRecorder *)audioRecorder{
    if (!_audioRecorder) {
        //创建录音文件保存路径
        NSURL *url=[NSURL URLWithString:self.cafPathStr];
        //创建录音格式设置
        NSDictionary *setting=[self getAudioSetting];
        //创建录音机
        NSError *error=nil;
        if (!url) {
            NSLog(@"url 不存在");
            return nil;
        }
        _audioRecorder=[[AVAudioRecorder alloc]initWithURL:url settings:setting error:&error];
        _audioRecorder.delegate=self;
        _audioRecorder.meteringEnabled=YES;//如果要监控声波则必须设置为YES
        if (error) {
            NSLog(@"创建录音机对象时发生错误，错误信息：%@",error.localizedDescription);
            return nil;
        }
    }
    return _audioRecorder;
}
#pragma mark - 取得录音文件设置
-(NSDictionary *)getAudioSetting{
    //LinearPCM 是iOS的一种无损编码格式,但是体积较为庞大
    //录音设置
    NSMutableDictionary *recordSettings = [[NSMutableDictionary alloc] init];
    //录音格式 无法使用
    [recordSettings setValue :[NSNumber numberWithInt:kAudioFormatLinearPCM] forKey: AVFormatIDKey];
    //采样率
    [recordSettings setValue :[NSNumber numberWithFloat:11025.0] forKey: AVSampleRateKey];//44100.0
    //通道数
    [recordSettings setValue :[NSNumber numberWithInt:2] forKey: AVNumberOfChannelsKey];
    //线性采样位数
    //[recordSettings setValue :[NSNumber numberWithInt:16] forKey: AVLinearPCMBitDepthKey];
    //音频质量,采样质量
    [recordSettings setValue:[NSNumber numberWithInt:AVAudioQualityMin] forKey:AVEncoderAudioQualityKey];
    
    return recordSettings;
}
#pragma mark - 播放
-(void)playCafRecord:(PlayDown)playDown
{
    self.playEnd = playDown;
    AVAudioSession *audioSession=[AVAudioSession sharedInstance];
    [audioSession setCategory:AVAudioSessionCategoryPlayback error:nil];  //此处需要恢复设置回放标志，否则会导致其它播放声音也会变小
    [audioSession setActive:YES error:nil];
    NSURL *playUrl=[NSURL URLWithString:self.cafPathStr];
    if (!playUrl) {
        if (playDown) {
            playDown(NO);
        }
        return;
    }
    if (self.audioPlayer) {
        [self.audioPlayer stop];
    }else
    {
        self.audioPlayer=[[AVAudioPlayer alloc]initWithContentsOfURL:playUrl error:nil];
        self.audioPlayer.delegate=self;
    }
    if ([self.audioPlayer prepareToPlay]) {
        [self.audioPlayer play];
    }else
    {
        if (playDown) {
            playDown(NO);
        }
    }
}
#pragma mark - 停止播放
-(void)stopCafRecord
{
    if (self.audioPlayer&&[self.audioPlayer isPlaying]) {
        [self.audioPlayer stop];
    }
}
-(void)audioPlayerDidFinishPlaying:(AVAudioPlayer *)player successfully:(BOOL)flag
{
    NSLog(@"delegate--播放完毕----------------------");
    if (self.playEnd) {
        self.playEnd(flag);
    }
}


#pragma mark - 文件转换
// 二进制文件转为base64的字符串
- (NSString *)Base64StrWithMp3Data:(NSData *)data{
    if (!data) {
        NSLog(@"Mp3Data 不能为空");
        return nil;
    }
    //    NSString *str = [data base64EncodedStringWithOptions:NSDataBase64Encoding64CharacterLineLength];
    NSString *str = [data base64EncodedStringWithOptions:NSDataBase64EncodingEndLineWithLineFeed];
    return str;
}
// base64的字符串转化为二进制文件
- (NSData *)Mp3DataWithBase64Str:(NSString *)str{
    if (str.length ==0) {
        NSLog(@"Mp3DataWithBase64Str:Base64Str 不能为空");
        return nil;
    }
    NSData *data = [[NSData alloc] initWithBase64EncodedString:str options:NSDataBase64DecodingIgnoreUnknownCharacters];
    NSLog(@"Mp3DataWithBase64Str:转换成功");
    return data;
}

//单个文件的大小
- (long long) fileSizeAtPath:(NSString*)filePath{
    
    NSFileManager* manager = [NSFileManager defaultManager];
    
    if ([manager fileExistsAtPath:filePath]){
        
        return [[manager attributesOfItemAtPath:filePath error:nil] fileSize];
        
    }else{
        NSLog(@"计算文件大小：文件不存在");
    }
    
    return 0;
}

- (void)commitVoiceNotice
{
    [self audio_PCMtoMP3];
    
    NSData *data = [NSData dataWithContentsOfFile:self.mp3PathStr];
    NSString *base64Str = [self Base64StrWithMp3Data:data];
    if ([self isBlankString:base64Str]) {
        return;
    }
    NSData *mp3Data = [self Mp3DataWithBase64Str:base64Str];
    
}
- (BOOL)isBlankString:(NSString *)string {
    if (string == nil || string == NULL) {
        return YES;
    }
    if ([string isKindOfClass:[NSNull class]]) {
        return YES;
    }
    if ([[string stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length]==0) {
        return YES;
    }
    return NO;
}
@end
