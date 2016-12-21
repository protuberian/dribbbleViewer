//
//  AppDelegate.h
//  dribbbleViewer
//
//  Created by iMac21 on 21.12.16.
//  Copyright © 2016 jetruby. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

