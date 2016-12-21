//
//  DataManager.h
//  dribbbleViewer
//
//  Created by iMac21 on 21.12.16.
//  Copyright © 2016 jetruby. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void (^NetworkRequestCallback)(NSURLResponse *response, id responseObject, NSError *error);
extern const int maxShots;

@interface DataManager : NSObject

+ (DataManager *)sharedManager;
- (NSURLSessionDataTask *)callToEndpoint:(NSString *)endpoint method:(NSString *)method parameters:(NSDictionary *)parameters callback:(NetworkRequestCallback)callback;
- (NSURLSessionDataTask *)getShotsPage:(NSUInteger)page callback:(NetworkRequestCallback)callback;

@end
