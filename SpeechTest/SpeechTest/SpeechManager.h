//
//  SpeechManager.h
//  SpeechTest
//
//  Created by huangjian on 2018/8/22.
//  Copyright © 2018年 huangjian. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^PlayDown)(BOOL successfully);

@protocol SpeechManagerDelegate <NSObject>
-(void)didFinishRecognition:(NSString *)speechString;
@end
@interface SpeechManager : NSObject
+(instancetype)shareInstance;
@property(nonatomic,weak)id<SpeechManagerDelegate> delegate;

-(void)startRecord;

-(void)stopRecord;

-(void)playCafRecord:(PlayDown)playDown;

-(void)stopCafRecord;
@end
