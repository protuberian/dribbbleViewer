//
//  DataManager.m
//  dribbbleViewer
//
//  Created by iMac21 on 21.12.16.
//  Copyright © 2016 jetruby. All rights reserved.
//

#import "DataManager.h"
#import <AFNetworking/AFNetworking.h>

static DataManager *_sharedManager = nil;
const NSString *apiURL = @"https://api.dribbble.com/v1/";
const NSString *accessToken = @"f07cf4ecf8cdb08ad321fe60fd2dfa34d784850fd6e33e15eda01f1f05e7ae6e";
const int pageSize = 10;
const int maxShots = 50;

@interface DataManager ()
@property (nonatomic, strong) AFHTTPSessionManager *sessionManager;
@end

@implementation DataManager

- (instancetype)init {
  self = [super init];
  if (self) {
    self.sessionManager = [AFHTTPSessionManager manager];
    self.sessionManager.requestSerializer = [AFJSONRequestSerializer serializer];
    self.sessionManager.responseSerializer = [AFJSONResponseSerializer serializer];

    [MagicalRecord setLoggingLevel:MagicalRecordLoggingLevelWarn];
    [MagicalRecord setShouldDeleteStoreOnModelMismatch:YES];
    [MagicalRecord setupCoreDataStackWithAutoMigratingSqliteStoreNamed:@"database.sqlite"];
  }
  return self;
}

+ (DataManager *)sharedManager {
  if (!_sharedManager) {
    _sharedManager = [[DataManager alloc] init];
  }
  return _sharedManager;
}

- (NSURLSessionDataTask *)callToEndpoint:(NSString *)endpoint method:(NSString *)method parameters:(NSDictionary *)parameters callback:(NetworkRequestCallback)callback {
  NSError *error = nil;
  NSMutableDictionary *fullParameters = parameters? [parameters mutableCopy] : [NSMutableDictionary dictionary];
  fullParameters[@"access_token"] = accessToken;

  NSMutableURLRequest *request = [self.sessionManager.requestSerializer requestWithMethod:method
                                                                                URLString:[apiURL stringByAppendingString:endpoint]
                                                                               parameters:fullParameters
                                                                                    error:&error];

  NSURLSessionDataTask *dataTask = [self.sessionManager dataTaskWithRequest:request completionHandler:^(NSURLResponse * _Nonnull response, id  _Nullable responseObject, NSError * _Nullable error) {
    if (callback) {
      callback(response, responseObject, error);
    }
  }];

  [dataTask resume];
  return dataTask;
}

- (NSURLSessionDataTask *)getShotsPage:(NSUInteger)page callback:(NetworkRequestCallback)callback {
  NSAssert(page > 0, @"page index must be > 0, %s",__PRETTY_FUNCTION__);
  return [self callToEndpoint:@"shots"
                       method:@"GET"
                   parameters:@{@"per_page":@(pageSize),
                                @"page":@(page),
                                @"sort":@"recent",
                                }
                     callback:^(NSURLResponse *response, id responseObject, NSError *error) {
                       if (!error) {
                         NSAssert(pageSize == [responseObject count], @"can't get %i shots (max page size is 100) %s",pageSize, __PRETTY_FUNCTION__);
                         [MagicalRecord saveWithBlock:^(NSManagedObjectContext * _Nonnull localContext) {
                           NSUInteger totalShots = [DribbbleShot MR_countOfEntitiesWithContext:localContext];

                           if (page == 1) {
                             //if database is too old delete all entities
                             NSMutableArray *ids = [NSMutableArray array];
                             for (NSDictionary *data in responseObject) {
                               [ids addObject:data[@"id"]];
                             }
                             if ([DribbbleShot MR_countOfEntitiesWithPredicate:[NSPredicate predicateWithFormat:@"uid IN %@",ids] inContext:localContext] == 0) {
                               [DribbbleShot MR_truncateAllInContext:localContext];
                             }
                           }

                           NSArray *sorted = [responseObject sortedArrayUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"id" ascending:NO]]];
                           for (NSDictionary *data in sorted) {
                             if ([data[@"animated"] boolValue]) {
                               continue;
                             }
                             DribbbleShot *shot = [DribbbleShot MR_findFirstByAttribute:@"uid" withValue:data[@"id"] inContext:localContext];
                             if (!shot) {
                               shot = [DribbbleShot MR_createEntityInContext:localContext];
                               shot.uid = data[@"id"];
                               totalShots++;
                             }
#define _(obj) [obj isEqual:[NSNull null]] ? nil:obj;
                             shot.title = _(data[@"title"]);
                             shot.about = _(data[@"description"]);
                             shot.hidpi = _(data[@"images"][@"hidpi"]);
                             shot.normal = _(data[@"images"][@"normal"]);
                             shot.teaser = _(data[@"images"][@"teaser"]);
                             shot.width = [data[@"width"] intValue];
                             shot.height = [data[@"height"] intValue];
                             shot.created = _(data[@"created_at"]);
                             if (totalShots >= maxShots) {
                               NSLog(@"%@",data);
                               break;
                             }
                           }
                         } completion:^(BOOL contextDidSave, NSError * _Nullable error) {
                           if (callback) {
                             callback(response, responseObject, error);
                           }
                         }];
                       } else {
                         NSLog(@"%@",error);
                         NSLog(@"%@",responseObject);
                         if (callback) {
                           callback(response, responseObject, error);
                         }
                       }
                     }];
}

@end
