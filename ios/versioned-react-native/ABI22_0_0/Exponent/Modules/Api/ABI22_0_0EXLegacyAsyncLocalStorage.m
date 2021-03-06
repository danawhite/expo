// Copyright 2015-present 650 Industries. All rights reserved.

// This code is basically based on ReactABI22_0_0-native's built-in
// `ABI22_0_0RCTAsyncLocalStorage.{h,m}` except made to be read-only and with
// naming changes to `ABI22_0_0EXLegacyAsyncLocalStorage` for the Objective-C class
// and `ExponentLegacyAsyncLocalStorage` for the native module name

/**
 * Copyright (c) 2015-present, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the root directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 */

#import "ABI22_0_0EXLegacyAsyncLocalStorage.h"
#import "ABI22_0_0EXConstants.h"
#import "ABI22_0_0EXUnversioned.h"

#import <ReactABI22_0_0/ABI22_0_0RCTConvert.h>
#import <ReactABI22_0_0/ABI22_0_0RCTLog.h>
#import <ReactABI22_0_0/ABI22_0_0RCTUtils.h>

static NSString *const ABI22_0_0RCTStorageDirectory = @"RCTAsyncLocalStorage_V1";
static NSString *const ABI22_0_0RCTManifestFileName = @"manifest.json";

#pragma mark - Static helper functions

static void ABI22_0_0RCTAppendError(NSDictionary *error, NSMutableArray<NSDictionary *> **errors)
{
  if (error && errors) {
    if (!*errors) {
      *errors = [NSMutableArray new];
    }
    [*errors addObject:error];
  }
}

static NSString *ABI22_0_0RCTReadFile(NSString *filePath, NSString *key, NSDictionary **errorOut)
{
  if ([[NSFileManager defaultManager] fileExistsAtPath:filePath]) {
    NSError *error;
    NSStringEncoding encoding;
    NSString *entryString = [NSString stringWithContentsOfFile:filePath usedEncoding:&encoding error:&error];
    if (error) {
      *errorOut = ABI22_0_0RCTMakeError(@"Failed to read storage file.", error, @{@"key": key});
    } else if (encoding != NSUTF8StringEncoding) {
      *errorOut = ABI22_0_0RCTMakeError(@"Incorrect encoding of storage file: ", @(encoding), @{@"key": key});
    } else {
      return entryString;
    }
  }
  return nil;
}

static NSString *ABI22_0_0RCTGetStorageDirectory()
{
  static NSString *storageDirectory = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
#if TARGET_OS_TV
    storageDirectory = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES).firstObject;
#else
    storageDirectory = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES).firstObject;
#endif
    storageDirectory = [storageDirectory stringByAppendingPathComponent:ABI22_0_0RCTStorageDirectory];
  });
  return storageDirectory;
}

static NSString *ABI22_0_0RCTGetManifestFilePath()
{
  static NSString *manifestFilePath = nil;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    manifestFilePath = [ABI22_0_0RCTGetStorageDirectory() stringByAppendingPathComponent:ABI22_0_0RCTManifestFileName];
  });
  return manifestFilePath;
}

static dispatch_queue_t ABI22_0_0RCTGetMethodQueue()
{
  // We want all instances to share the same queue since they will be reading/writing the same files.
  static dispatch_queue_t queue;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    queue = dispatch_queue_create("com.facebook.ReactABI22_0_0.AsyncLocalStorageQueue", DISPATCH_QUEUE_SERIAL);
  });
  return queue;
}

static NSCache *ABI22_0_0RCTGetCache()
{
  // We want all instances to share the same cache since they will be reading/writing the same files.
  static NSCache *cache;
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    cache = [NSCache new];
    cache.totalCostLimit = 2 * 1024 * 1024; // 2MB

    // Clear cache in the event of a memory warning
    [[NSNotificationCenter defaultCenter] addObserverForName:UIApplicationDidReceiveMemoryWarningNotification object:nil queue:nil usingBlock:^(__unused NSNotification *note) {
      [cache removeAllObjects];
    }];
  });
  return cache;
}

static BOOL ABI22_0_0RCTHasCreatedStorageDirectory = NO;

#pragma mark - ABI22_0_0EXLegacyAsyncLocalStorage

@implementation ABI22_0_0EXLegacyAsyncLocalStorage
{
  BOOL _haveSetup;
  // The manifest is a dictionary of all keys with small values inlined.  Null values indicate values that are stored
  // in separate files (as opposed to nil values which don't exist).  The manifest is read off disk at startup, and
  // written to disk after all mutations.
  NSMutableDictionary<NSString *, NSString *> *_manifest;
}

@synthesize bridge = _bridge;

ABI22_0_0RCT_EXPORT_MODULE(ExponentLegacyAsyncLocalStorage)

- (dispatch_queue_t)methodQueue
{
  return ABI22_0_0RCTGetMethodQueue();
}

- (void)invalidate
{
  [_manifest removeAllObjects];
  _haveSetup = NO;
}

- (BOOL)isValid
{
  return _haveSetup;
}

- (void)dealloc
{
  [self invalidate];
}

- (NSString *)_filePathForKey:(NSString *)key
{
  NSString *safeFileName = ABI22_0_0RCTMD5Hash(key);
  return [ABI22_0_0RCTGetStorageDirectory() stringByAppendingPathComponent:safeFileName];
}

- (NSDictionary *)_ensureSetup
{
  ABI22_0_0RCTAssertThread(ABI22_0_0RCTGetMethodQueue(), @"Must be executed on storage thread");

#if TARGET_OS_TV
  ABI22_0_0RCTLogWarn(@"Persistent storage is not supported on tvOS, your data may be removed at any point.");
#endif

  NSError *error = nil;
  if (!ABI22_0_0RCTHasCreatedStorageDirectory) {
    [[NSFileManager defaultManager] createDirectoryAtPath:ABI22_0_0RCTGetStorageDirectory()
                              withIntermediateDirectories:YES
                                               attributes:nil
                                                    error:&error];
    if (error) {
      return ABI22_0_0RCTMakeError(@"Failed to create storage directory.", error, nil);
    }
    ABI22_0_0RCTHasCreatedStorageDirectory = YES;
  }
  if (!_haveSetup) {
    NSDictionary *errorOut;
    NSString *serialized = ABI22_0_0RCTReadFile(ABI22_0_0RCTGetManifestFilePath(), nil, &errorOut);
    _manifest = serialized ? ABI22_0_0RCTJSONParseMutable(serialized, &error) : [NSMutableDictionary new];
    if (error) {
      ABI22_0_0RCTLogWarn(@"Failed to parse manifest - creating new one.\n\n%@", error);
      _manifest = [NSMutableDictionary new];
    }
    _haveSetup = YES;
  }
  return nil;
}

- (NSString *)_getValueForKey:(NSString *)key errorOut:(NSDictionary **)errorOut
{
  NSString *value = _manifest[key]; // nil means missing, null means there may be a data file, else: NSString
  if (value == (id)kCFNull) {
    value = [ABI22_0_0RCTGetCache() objectForKey:key];
    if (!value) {
      NSString *filePath = [self _filePathForKey:key];
      value = ABI22_0_0RCTReadFile(filePath, key, errorOut);
      if (value) {
        [ABI22_0_0RCTGetCache() setObject:value forKey:key cost:value.length];
      } else {
        // file does not exist after all, so remove from manifest (no need to save
        // manifest immediately though, as cost of checking again next time is negligible)
        [_manifest removeObjectForKey:key];
      }
    }
  }
  return value;
}

#pragma mark - Exported JS Functions

ABI22_0_0RCT_EXPORT_METHOD(multiGet:(NSArray<NSString *> *)keys
                  callback:(ABI22_0_0RCTResponseSenderBlock)callback)
{
  NSDictionary *errorOut = [self _ensureSetup];
  if (errorOut) {
    callback(@[@[errorOut], (id)kCFNull]);
    return;
  }
  NSMutableArray<NSDictionary *> *errors;
  NSMutableArray<NSArray<NSString *> *> *result = [[NSMutableArray alloc] initWithCapacity:keys.count];
  for (NSString *key in keys) {
    id keyError;
    id value = [self _getValueForKey:key errorOut:&keyError];
    [result addObject:@[key, ABI22_0_0RCTNullIfNil(value)]];
    ABI22_0_0RCTAppendError(keyError, &errors);
  }
  callback(@[ABI22_0_0RCTNullIfNil(errors), result]);
}

ABI22_0_0RCT_EXPORT_METHOD(getAllKeys:(ABI22_0_0RCTResponseSenderBlock)callback)
{
  NSDictionary *errorOut = [self _ensureSetup];
  if (errorOut) {
    callback(@[errorOut, (id)kCFNull]);
  } else {
    callback(@[(id)kCFNull, _manifest.allKeys]);
  }
}

- (NSString *)migrationDoneKey
{
  return [_bridge.scopedModules.constants.experienceId stringByAppendingString:@".migrationDone"];
}

ABI22_0_0RCT_REMAP_METHOD(isMigrationDone,
                 isMigrationDoneWithResolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                 rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  NSDictionary *errorOut = [self _ensureSetup];
  if (errorOut) {
    reject(@"E_LEGACY_ASYNCSTORAGE", @"Error setting up LegacyAsyncStorage", nil);
  } else {
    NSString *key = [self migrationDoneKey];
    BOOL done = _manifest[key] && [_manifest[key] isEqualToString:@"YES"];
    resolve(@(done));
  }
}

ABI22_0_0RCT_REMAP_METHOD(setMigrationDone,
                 setMigrationDoneWithResolver:(ABI22_0_0RCTPromiseResolveBlock)resolve
                 rejecter:(ABI22_0_0RCTPromiseRejectBlock)reject)
{
  NSDictionary *errorOut = [self _ensureSetup];
  if (errorOut) {
    reject(@"E_LEGACY_ASYNCSTORAGE", @"Error setting up LegacyAsyncStorage", nil);
  } else {
    _manifest[[self migrationDoneKey]] = @"YES";

    NSError *error = nil;
    NSString *manifestStr = ABI22_0_0RCTJSONStringify(_manifest, &error);
    if (error) {
      reject(@"E_LEGACY_ASYNCSTORAGE", @"Error writing LegacyAsyncStorage manifest", error);
    }

    [manifestStr writeToFile:ABI22_0_0RCTGetManifestFilePath() atomically:YES encoding:NSUTF8StringEncoding error:&error];
    if (error) {
      reject(@"E_LEGACY_ASYNCSTORAGE", @"Error writing LegacyAsyncStorage manifest", error);
    }

    resolve(nil);
  }
}

@end
