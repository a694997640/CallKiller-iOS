//
//  Preference.m
//  statics
//
//  Created by mac on 2018/7/18.
//

#import "Preference.h"
#import "statics.h"
#import <notify.h>

#if TARGET_OS_SIMULATOR
#define kCallKillerPreferenceFolder [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/callkiller"]
#define kCallKillerPreferenceFilePathLegacy [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/callkiller-pref.json"]
#define kCallKillerPreferenceFilePath [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/callkiller/callkiller-pref.json"]
#else
#define kCallKillerPreferenceFolder @"/var/mobile/callkiller"
#define kCallKillerPreferenceFilePathLegacy @"/var/mobile/callkiller-pref.json"
#define kCallKillerPreferenceFilePath @"/var/mobile/callkiller/callkiller-pref.json"
#endif

static BOOL didMigrate = NO;

@interface LSBundleProxy
@property (nonatomic, readonly) NSURL *dataContainerURL;
+ (id)bundleProxyForIdentifier:(id)arg1;
@end

@implementation Preference

+(instancetype)sharedInstance {
    static Preference *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
        [[NSFileManager defaultManager] createDirectoryAtPath:kCallKillerPreferenceFolder 
                                  withIntermediateDirectories:YES 
                                                   attributes:nil 
                                                        error:nil];
        instance->_pref = [[Preference load] mutableDeepCopy];
        instance->_mpPref = [[Preference loadMPPref] mutableDeepCopy];
    });
    return instance;
}

-(NSMutableDictionary*)pref {
    return _pref;
}

-(void)save {
    _pref[kKeyPrefVersion] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:_pref options:kNilOptions error:&err];
    if (data) {
        [data writeToFile:kCallKillerPreferenceFilePath options:NSDataWritingAtomic error:&err];
        if (err) {
            Log("== pref json write to file failed: %@", err);
        }
        notify_post(kCallKillerPrefUpdatedNotification);
    } else {
        Log("== pref to json failed: %@", err);
    }
}

-(void)saveOnly {
    _pref[kKeyPrefVersion] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:_pref options:kNilOptions error:&err];
    if (data) {
        [data writeToFile:kCallKillerPreferenceFilePath options:NSDataWritingAtomic error:&err];
        if (err) {
            Log("== pref json write to file failed: %@", err);
        }
    } else {
        Log("== pref to json failed: %@", err);
    }
}

-(NSMutableDictionary*)mpPref {
        return _mpPref;
}

-(void)saveMPPref {
    _mpPref[kKeyPrefVersion] = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
    NSError *err = nil;
    NSData *data = [NSJSONSerialization dataWithJSONObject:_mpPref options:kNilOptions error:&err];
    if (data) {
        [data writeToFile:[Preference mpPrefFilePath] options:NSDataWritingAtomic error:&err];
        if (err) {
            Log("== mppref json write to file failed: %@", err);
        }
    } else {
        Log("== mppref to json failed: %@", err);
    }
}

+(NSString*)mpPrefFilePath {
    LSBundleProxy *mobilephone = [LSBundleProxy bundleProxyForIdentifier:@"com.apple.mobilephone"];
    return [NSString stringWithFormat:@"%@/Documents/%@", mobilephone.dataContainerURL.path, @"callkiller-pref.json"];
}

+(NSDictionary*)load {
    [Preference migrate];
    NSData *data = [NSData dataWithContentsOfFile:kCallKillerPreferenceFilePath];
    if (data) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        if (dict)
            return dict;
    }
    return @{
             kKeyBypassContacts: @(YES),
             kKeyBlockUnknown: @(YES),
             kKeyIgnoredPrefixes: @[
                     @[@"12583?", @"^12583\\d\\d+", @"中国移动和多号"]
                     ],
             kKeyBlackKeywords: @[
                     @"响一声",
                     @"广告",
                     @"推销",
                     @"骚扰",
                     @"诈骗",
                     @"保险",
                     @"理财",
                     @"房产中介",
                     ]
             };
}

+(NSDictionary*)loadMPPref {
    NSData *data = [NSData dataWithContentsOfFile:[Preference mpPrefFilePath]];
    if (data) {
        NSDictionary *dict = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        if (dict)
            return dict;
    }
    return @{
             kKeyMPInjectionEnabled: @(YES),
             };
}

/**
 /var/mobile/callkiller-pref.json --> /var/mobile/callkiller/callkiller-pref.json
 */
+(void)migrate {
    if (didMigrate) // do migrate only once for sb/app lifetime
        return;
    //Log("== migrate called from %@", [[NSBundle mainBundle] bundleIdentifier]);
    NSFileManager *mgr = [NSFileManager defaultManager];
    BOOL oldPrefExist = [mgr fileExistsAtPath:kCallKillerPreferenceFilePathLegacy];
    BOOL newPrefExist = [mgr fileExistsAtPath:kCallKillerPreferenceFilePath];
    //Log("old pref exists: %@, new pref exists: %@", oldPrefExist ? @"Y" : @"N", newPrefExist ? @"Y" : @"N");
    if (oldPrefExist && !newPrefExist) {
        //Log("== do migrate");
        [mgr createDirectoryAtPath:kCallKillerPreferenceFolder withIntermediateDirectories:YES attributes:nil error:nil];
        NSError *err = nil;
        [mgr moveItemAtPath:kCallKillerPreferenceFilePathLegacy toPath:kCallKillerPreferenceFilePath error:&err];
        if (err) {
            //Log("== move old pref file to new place failed: %@", err);
        }
    }
    didMigrate = YES;
}

@end
