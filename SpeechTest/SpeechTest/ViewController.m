//
//  ViewController.m
//  SpeechTest
//
//  Created by huangjian on 2018/8/22.
//  Copyright © 2018年 huangjian. All rights reserved.
//

#import "ViewController.h"
#import "SpeechManager.h"
@interface ViewController ()<UIGestureRecognizerDelegate,SpeechManagerDelegate>
@property (weak, nonatomic) IBOutlet UILabel *timerLabel;
@property (weak, nonatomic) IBOutlet UIImageView *rotateImgView;
@property (weak, nonatomic) IBOutlet UIButton *recordBtn;

@property (nonatomic,strong)NSTimer *myTimer;

@property (nonatomic,assign) NSInteger countNum;

@property (nonatomic,strong) UIImageView *voiceView;

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    [SpeechManager shareInstance].delegate=self;
    [self setUpUI];
}
-(void)setUpUI
{
    UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPressed:)];
    longPress.delegate = self;
    longPress.minimumPressDuration = 0.5;
    [self.recordBtn addGestureRecognizer:longPress];
    
    UIImageView *voiceView=[[UIImageView alloc]init];
    voiceView.hidden=YES;
    [self.view addSubview:voiceView];
    voiceView.frame=CGRectMake(self.view.bounds.size.width/2-15, 150, 30, 30);
    self.voiceView=voiceView;
    
    UIButton *btn=[UIButton buttonWithType:UIButtonTypeCustom];
    [btn setTitle:@"播放" forState: UIControlStateNormal];
    [btn setTitle:@"停止" forState:UIControlStateSelected];
    [btn setTitleColor:[UIColor blueColor] forState:UIControlStateNormal];
    [btn setTitleColor:[UIColor blueColor] forState:UIControlStateSelected];
    [btn addTarget:self action:@selector(play:) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:btn];
    btn.frame=CGRectMake(20, 100, 60, 30);
}
-(void)play:(UIButton *)btn
{
    btn.selected=!btn.selected;
    if (btn.selected) {
        [self pictureChangeAnimationSetting];
        [[SpeechManager shareInstance]playCafRecord:^(BOOL successfully) {
            [self pictureChangeAnimationStop];
            btn.selected=NO;
        }];
    }else
    {
        [[SpeechManager shareInstance]stopCafRecord];
        [self pictureChangeAnimationStop];
    }
    
}
-(void)handleLongPressed:(UIGestureRecognizer *)ges
{
    if (ges.state==UIGestureRecognizerStateBegan) {
        [[SpeechManager shareInstance]startRecord];
        [self.myTimer fire];
        [self startAnimationWithTime:2];
    }else if (ges.state==UIGestureRecognizerStateEnded)
    {
        [[SpeechManager shareInstance]stopRecord];
        self.timerLabel.text=@"00:00";
        self.countNum=0;
        [self removeTimer];
        [self stopAnimation];
    }
}

-(void)didFinishRecognition:(NSString *)speechString
{
    if (speechString) {
        NSLog(@"解析成功-%@",speechString);
    }else
    {
        NSLog(@"解析失败");
    }
}
// 执行动画
- (void)startAnimationWithTime:(CFTimeInterval)time
{
    self.rotateImgView.image = [UIImage imageNamed:@"rcirle_high"];
    CABasicAnimation *rotationAnimation=[CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation = [CABasicAnimation animationWithKeyPath:@"transform.rotation.z"];
    rotationAnimation.toValue = [NSNumber numberWithFloat: M_PI * 2.0 ];
    rotationAnimation.duration = time;
    rotationAnimation.cumulative = YES;
    rotationAnimation.repeatCount = HUGE_VALF;
    
    [self.rotateImgView.layer addAnimation:rotationAnimation forKey:@"rotationAnimation"];
}
// 停止动画
- (void)stopAnimation;
{
    self.rotateImgView.image = [UIImage imageNamed:@"rcirle_norm"];
    [self.rotateImgView.layer removeAllAnimations];
}
-(void)timerRun
{
    self.countNum += 1;
    NSInteger min = self.countNum/60;
    NSInteger sec = self.countNum - min * 60;
    self.timerLabel.text = [NSString stringWithFormat:@"%02d:%02d",min,sec];
}
#pragma mark - TIMER

-(NSTimer *)myTimer {
    if (!_myTimer) {
        _myTimer = [NSTimer timerWithTimeInterval:1.0f target:self selector:@selector(timerRun) userInfo:nil repeats:YES];
        [[NSRunLoop currentRunLoop] addTimer:_myTimer forMode:NSRunLoopCommonModes];
        
    }
    return _myTimer;
}
//取消定时器
-(void)removeTimer {
    if (_myTimer) {
        [_myTimer invalidate];
        _myTimer=nil;
    }
}
#pragma mark - 播放动画效果
- (void)pictureChangeAnimationSetting
{
    self.voiceView.hidden=NO;
    NSArray *picArray = @[[UIImage imageNamed:@"voice1"],
                          [UIImage imageNamed:@"voice2"],
                          [UIImage imageNamed:@"voice3"]];
    //imageView的动画图片是数组images
    self.voiceView.animationImages = picArray;
    //按照原始比例缩放图片，保持纵横比
    self.voiceView.contentMode = UIViewContentModeScaleAspectFit;
    //切换动作的时间3秒，来控制图像显示的速度有多快，
    self.voiceView.animationDuration = 1;
    //动画的重复次数，想让它无限循环就赋成0
    self.voiceView.animationRepeatCount = 0;
    
    [self.voiceView startAnimating];
}
-(void)pictureChangeAnimationStop
{
    self.voiceView.hidden=YES;
    [self.voiceView stopAnimating];
}
@end
