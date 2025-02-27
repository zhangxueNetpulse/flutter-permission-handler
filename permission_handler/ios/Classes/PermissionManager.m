//
// Created by Razvan Lung(long1eu) on 2019-02-15.
// Copyright (c) 2019 The Chromium Authors. All rights reserved.
//

#import "PermissionManager.h"

@implementation PermissionManager {
    NSMutableArray <id <PermissionStrategy>> *_strategyInstances;
}

- (instancetype)initWithStrategyInstances {
    self = [super init];
    if (self) {
        _strategyInstances = _strategyInstances = [[NSMutableArray alloc] init];
    }
    
    return self;
}

+ (void)checkPermissionStatus:(enum PermissionGroup)permission result:(FlutterResult)result {
    id <PermissionStrategy> permissionStrategy = [PermissionManager createPermissionStrategy:permission];
    PermissionStatus status = [permissionStrategy checkPermissionStatus:permission];
    
    result([Codec encodePermissionStatus:status]);
}

+ (void)checkServiceStatus:(enum PermissionGroup)permission result:(FlutterResult)result {
    id <PermissionStrategy> permissionStrategy = [PermissionManager createPermissionStrategy:permission];
    ServiceStatus status = [permissionStrategy checkServiceStatus:permission];
    result([Codec encodeServiceStatus:status]);
}

- (void)requestPermissions:(NSArray *)permissions completion:(PermissionRequestCompletion)completion {
    NSMutableDictionary *permissionStatusResult = [[NSMutableDictionary alloc] init];

    if (permissions.count == 0) {
        completion(permissionStatusResult);
        return;
    }
    
    NSMutableSet *requestQueue = [[NSMutableSet alloc] initWithArray:permissions];
        
    for (int i = 0; i < permissions.count; ++i) {
        NSNumber *rawNumberValue = permissions[i];
        int rawValue = rawNumberValue.intValue;
        PermissionGroup permission = (PermissionGroup) rawValue;
        
        id <PermissionStrategy> permissionStrategy = [PermissionManager createPermissionStrategy:permission];
        [_strategyInstances addObject:permissionStrategy];
        
        
        [permissionStrategy requestPermission:permission completionHandler:^(PermissionStatus permissionStatus) {
            permissionStatusResult[@(permission)] = @(permissionStatus);
            [requestQueue removeObject:@(permission)];
            
            [self->_strategyInstances removeObject:permissionStrategy];
            
            if (requestQueue.count == 0) {
                completion(permissionStatusResult);
                return;
            }
        }];
    }
}

+ (void)openAppSettings:(FlutterResult)result {
    if (@available(iOS 10, *)) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]
                                           options:[[NSDictionary alloc] init]
                                 completionHandler:^(BOOL success) {
                                     result([[NSNumber alloc] initWithBool:success]);
                                 }];
    } else if (@available(iOS 8.0, *)) {
        BOOL success = [[UIApplication sharedApplication] openURL:[NSURL URLWithString:UIApplicationOpenSettingsURLString]];
        result([[NSNumber alloc] initWithBool:success]);
    } else {
        result(@false);    
    }
}

+ (id)createPermissionStrategy:(PermissionGroup)permission {
    switch (permission) {
        case PermissionGroupLocation:
        case PermissionGroupLocationAlways:
        case PermissionGroupLocationWhenInUse:
            #if PERMISSION_LOCATION
            return [[LocationPermissionStrategy alloc] initWithLocationManager];
            #else
            return [LocationPermissionStrategy new];
            #endif
        case PermissionGroupPhotos:
            #if PERMISSION_PHOTOS
            return [[PhotoPermissionStrategy alloc] initWithAccessAddOnly:false];
            #else
            return [PhotoPermissionStrategy new];
            #endif
        case PermissionGroupPhotosAddOnly:
            #if PERMISSION_PHOTOS
            return [[PhotoPermissionStrategy alloc] initWithAccessAddOnly:true];
            #else
            return [PhotoPermissionStrategy new];
            #endif
        case PermissionGroupReminders:
            return [EventPermissionStrategy new];
        case PermissionGroupNotification:
            return [NotificationPermissionStrategy new];
        case PermissionGroupStorage:
            return [StoragePermissionStrategy new];
        case PermissionGroupBluetooth:
            return [BluetoothPermissionStrategy new];
        case PermissionGroupAppTrackingTransparency:
            return [AppTrackingTransparencyPermissionStrategy new];
        case PermissionGroupCriticalAlerts:
            return [CriticalAlertsPermissionStrategy new];
        default:
            return [UnknownPermissionStrategy new];
    }
}

@end
