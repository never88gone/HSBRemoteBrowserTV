//
//  AppDelegate.h
//  HSBWatchCompanion
//
//  Created by never88gone on 2026/4/1.
//

#import <UIKit/UIKit.h>
#import <CoreData/CoreData.h>

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (readonly, strong) NSPersistentContainer *persistentContainer;

- (void)saveContext;


@end

