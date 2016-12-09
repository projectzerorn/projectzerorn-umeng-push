//
//  RCTUmengPush.m
//  RCTUmengPush
//
//  Created by user on 16/4/24.
//  Copyright © 2016年 react-native-umeng-push. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "RCTUmengPush.h"
#import "UMessage.h"
#import "RCTEventDispatcher.h"

#define UMSYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define _IPHONE80_ 80000

static NSString * const DidReceiveMessage = @"DidReceiveMessage";
static NSString * const DidOpenMessage = @"DidOpenMessage";
static RCTUmengPush *_instance = nil;

@interface RCTUmengPush ()
@property (nonatomic, copy) NSString *deviceToken;
@end
@implementation RCTUmengPush

@synthesize bridge = _bridge;
RCT_EXPORT_MODULE()

+ (instancetype)sharedInstance {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(_instance == nil) {
            _instance = [[self alloc] init];
        }
    });
    return _instance;
}

+ (instancetype)allocWithZone:(struct _NSZone *)zone {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(_instance == nil) {
            _instance = [super allocWithZone:zone];
            [_instance setupUMessage];
        }
    });
    return _instance;
}

+ (dispatch_queue_t)sharedMethodQueue {
    static dispatch_queue_t methodQueue;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        methodQueue = dispatch_queue_create("com.liuchungui.react-native-umeng-push", DISPATCH_QUEUE_SERIAL);
    });
    return methodQueue;
}

- (dispatch_queue_t)methodQueue {
    return [RCTUmengPush sharedMethodQueue];
}

- (NSDictionary<NSString *, id> *)constantsToExport {
    return @{
             DidReceiveMessage: DidReceiveMessage,
             DidOpenMessage: DidOpenMessage,
             };
}

- (void)didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [self.bridge.eventDispatcher sendAppEventWithName:DidReceiveMessage body:userInfo];
}

- (void)didOpenRemoteNotification:(NSDictionary *)userInfo {
    [self.bridge.eventDispatcher sendAppEventWithName:DidOpenMessage body:userInfo];
}

RCT_EXPORT_METHOD(setAutoAlert:(BOOL)value) {
    [UMessage setAutoAlert:value];
}

RCT_EXPORT_METHOD(getDeviceToken:(RCTResponseSenderBlock)callback) {
    NSString *deviceToken = self.deviceToken;
    if(deviceToken == nil) {
        deviceToken = @"";
    }
    callback(@[deviceToken]);
}

RCT_EXPORT_METHOD(enable) {
    [self jumpToSetting];
}

RCT_EXPORT_METHOD(disable) {
    [self jumpToSetting];
}

- (void)jumpToSetting{
    //http://my.oschina.net/u/2340880/blog/619224
    NSString * bundleId = [[NSBundle mainBundle]bundleIdentifier];
    NSURL * url = [NSURL URLWithString:[NSString stringWithFormat:@"prefs:root=NOTIFICATIONS_ID&path=%@",bundleId]];
    [[UIApplication sharedApplication]openURL:url];
}



RCT_EXPORT_METHOD(isEnabled:(RCTResponseSenderBlock)callback) {
    BOOL isEnable;
    if ([[UIApplication sharedApplication] respondsToSelector:@selector(isRegisteredForRemoteNotifications)]) {
        BOOL isRegisteredForRemoteNotifications = [[UIApplication sharedApplication] isRegisteredForRemoteNotifications];
        if (isRegisteredForRemoteNotifications) {
            isEnable = true;
        }else{
            isEnable = false;
        }
    } else {
        UIRemoteNotificationType types = [[UIApplication sharedApplication] enabledRemoteNotificationTypes];
        if (types == UIRemoteNotificationTypeNone) {
            isEnable = false;
        }else{
            isEnable = true;
        }
    }
    callback(@[@(isEnable)]);
}

/**
 *  初始化UM的一些配置
 */
- (void)setupUMessage {
    [UMessage setAutoAlert:NO];
}

+ (void)registerWithAppkey:(NSString *)appkey launchOptions:(NSDictionary *)launchOptions delegate:(UIResponder <UIApplicationDelegate> *)delegate{
    //set AppKey and LaunchOptions
    [UMessage startWithAppkey:appkey launchOptions:launchOptions httpsenable:true];
    
    //注册通知
    [UMessage registerForRemoteNotifications];
    
    //iOS10必须加下面这段代码。
    UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
    center.delegate = delegate;
    UNAuthorizationOptions types10=UNAuthorizationOptionBadge|UNAuthorizationOptionAlert|UNAuthorizationOptionSound;
    [center requestAuthorizationWithOptions:types10 completionHandler:^(BOOL granted, NSError * _Nullable error) {
        if (granted) {
            //点击允许
            
        } else {
            //点击不允许
            
        }
    }];
    
    //由推送第一次打开应用时
    if(launchOptions[@"UIApplicationLaunchOptionsRemoteNotificationKey"]) {
        [self didReceiveRemoteNotificationWhenFirstLaunchApp:launchOptions[@"UIApplicationLaunchOptionsRemoteNotificationKey"]];
    }
    
    #ifdef DEBUG
        [UMessage setLogEnabled:YES];
    #endif
}

+ (void)application:(UIApplication *)application didRegisterDeviceToken:(NSData *)deviceToken {
    [RCTUmengPush sharedInstance].deviceToken = [[[[deviceToken description] stringByReplacingOccurrencesOfString: @"<" withString: @""]
                                                  stringByReplacingOccurrencesOfString: @">" withString: @""]
                                                 stringByReplacingOccurrencesOfString: @" " withString: @""];
    [UMessage registerDeviceToken:deviceToken];
}

+ (void)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo {
    [UMessage didReceiveRemoteNotification:userInfo];
    //send event
    if (application.applicationState == UIApplicationStateInactive) {
        [[RCTUmengPush sharedInstance] didOpenRemoteNotification:userInfo];
    }
    else {
        [[RCTUmengPush sharedInstance] didReceiveRemoteNotification:userInfo];
    }
}

+ (void)didReceiveRemoteNotificationWhenFirstLaunchApp:(NSDictionary *)launchOptions {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), [self sharedMethodQueue], ^{
        //判断当前模块是否正在加载，已经加载成功，则发送事件
        if(![RCTUmengPush sharedInstance].bridge.isLoading) {
            [UMessage didReceiveRemoteNotification:launchOptions];
            [[RCTUmengPush sharedInstance] didOpenRemoteNotification:launchOptions];
        }
        else {
            [self didReceiveRemoteNotificationWhenFirstLaunchApp:launchOptions];
        }
    });
}

@end
