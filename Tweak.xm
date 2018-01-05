#import <UIKit/UIKit.h>
#include <substrate.h>

@interface SBApplication : NSObject
@property (nonatomic,copy) NSArray *dynamicShortcutItems;
-(NSString *)bundleIdentifier;
@end

@interface SBSApplicationShortcutIcon : NSObject
@end

@interface SBSApplicationShortcutSystemIcon : SBSApplicationShortcutIcon
-(instancetype)initWithType:(NSInteger)type;
@end

@interface SBSApplicationShortcutCustomImageIcon : SBSApplicationShortcutIcon
@property (nonatomic, readonly, retain) NSData *imagePNGData;
-(instancetype)initWithImagePNGData:(NSData *)imageData;
@end

@interface SBSApplicationShortcutItem : NSObject
@property (nonatomic,copy) NSString *type;
@property (nonatomic,copy) NSString *localizedTitle;
@property (nonatomic,copy) NSString *localizedSubtitle;
@property (nonatomic,copy) SBSApplicationShortcutIcon *icon;
@property (nonatomic,copy) NSDictionary *userInfo;
@end

@interface SBApplicationShortcutMenu : NSObject
@property(retain, nonatomic) SBApplication *application;
@end

#ifndef __LP64__

@interface UIApplicationShortcutItem : NSObject
@property (nonatomic, copy, readonly) NSString *type;
@property (nonatomic, copy, readonly) NSString *localizedTitle;
@property (nonatomic, copy, readonly) NSString *localizedSubtitle;
@end

@protocol UIViewControllerPreviewing <NSObject>
@property (nonatomic, readonly) UIView *sourceView;
@property (nonatomic) CGRect sourceRect;
@end

@protocol UIViewControllerPreviewingDelegate <NSObject>
- (UIViewController *)previewingContext:(id <UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location;
- (void)previewingContext:(id <UIViewControllerPreviewing>)previewingContext commitViewController:(UIViewController *)viewControllerToCommit;
@end

@interface UITraitCollection : NSObject
@property (nonatomic, readonly) NSInteger forceTouchCapability;
@end

@interface UIViewController (iOS9)
@property (nonatomic,readonly) UITraitCollection * traitCollection;
-(void)showViewController:(UIViewController *)viewController sender:(id)sender;
-(void)registerForPreviewingWithDelegate:(id)delegate sourceView:(UIView *)view;
@end

@interface UIPreviewAction
+ (instancetype)actionWithTitle:(NSString *)title style:(NSInteger)style handler:(void (^)(UIPreviewAction *action, UIViewController *previewViewController))handler;
@end

#endif

@interface CydiaTabBarController : UITabBarController
@end

@interface CYPackageController : UIViewController
-(void)setDelegate:(id)arg1 ;
-(id)initWithDatabase:(id)arg1 forPackage:(id)arg2 withReferrer:(id)arg3 ;
-(void)reloadData;
@end

@interface PackageListController : UIViewController <UIViewControllerPreviewingDelegate>
-(NSURL *)referrerURL;
@end

@interface Package : NSObject
-(id)id;
-(BOOL)uninstalled;
-(BOOL)isCommercial;
-(void)install;
-(void)remove;
@end

@interface Database : NSObject
+(id)sharedInstance;
@end

@interface Cydia : UIApplication
-(void)queue;
-(BOOL)requestUpdate;
-(void)handleShortcutItem:(UIApplicationShortcutItem *)item;
@end

%group Cydia
%hook PackageListController

-(void)viewDidLoad {
  %orig;
  UITableView *tableView = MSHookIvar<UITableView *>(self,"list_");
  if (tableView) {
    [self registerForPreviewingWithDelegate:self sourceView:tableView];
  }
}

#pragma mark - UIViewControllerPreviewingDelegate
%new
- (UIViewController *)previewingContext:(id <UIViewControllerPreviewing>)previewingContext viewControllerForLocation:(CGPoint)location {
    if ([self.presentedViewController isKindOfClass:%c(CYPackageController)]) {
        return nil;
    }
    UITableView *tableView = MSHookIvar<UITableView *>(self,"list_");
    if (!tableView) {
      return nil;
    }
    NSIndexPath *indexPath = [tableView indexPathForRowAtPoint:location];
    if (indexPath) {
        UITableViewCell *cell = [tableView cellForRowAtIndexPath:indexPath];
        [previewingContext setSourceRect:cell.frame];
        if (cell) {
          NSInteger index = 0;
          for (int i = 0; i < indexPath.section; i++) {
              index += [tableView numberOfRowsInSection:i];
          }
          index += indexPath.row;
          NSArray *packages = MSHookIvar<NSArray *>(self,"packages_");
          if (packages && packages.count > index) {
            Package *package = [packages objectAtIndex:index];
            if (package) {
              CYPackageController *packageController = [[%c(CYPackageController) alloc] initWithDatabase:[%c(Database) sharedInstance] forPackage:[package id] withReferrer:[self referrerURL].absoluteString];
              [packageController setDelegate:[UIApplication sharedApplication]];
              return packageController;
            }
          }
        }
    }
    return nil;
}
%new
- (void)previewingContext:(id <UIViewControllerPreviewing>)previewingContext commitViewController:(CYPackageController *)viewControllerToCommit {
    [viewControllerToCommit reloadData];
    [self showViewController:viewControllerToCommit sender:self];
}

%end
%hook CYPackageController

%new
-(NSArray *)previewActionItems {
  Package *package = MSHookIvar<Package *>(self,"package_");
  if (package == nil) {
    return @[];
  }
  UIPreviewAction *packageAction = [%c(UIPreviewAction) actionWithTitle:([package uninstalled] ? ([package isCommercial] ? @"Purchase" : @"Install") : @"Remove") style:0 handler:^(UIPreviewAction *action, UIViewController *viewController) {
    if ([package uninstalled]) {
      [package install];
    } else if ([package isCommercial]) {

    } else {
      [package remove];
    }
    [(Cydia *)[UIApplication sharedApplication] queue];
  }];
  return @[packageAction];
}

%end

%hook Cydia

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  BOOL x = %orig;
  if ([launchOptions objectForKey:@"UIApplicationLaunchOptionsShortcutItemKey"]) {
      [self handleShortcutItem:[launchOptions objectForKey:@"UIApplicationLaunchOptionsShortcutItemKey"]];
  }
  return x;
}

%new
-(void)application:(UIApplication *)application performActionForShortcutItem:(UIApplicationShortcutItem *)shortcutItem completionHandler:(void (^)(BOOL))completionHandler {
    [self handleShortcutItem:shortcutItem];
}

%new
-(void)handleShortcutItem:(UIApplicationShortcutItem *)item {
  __block BOOL loaded = MSHookIvar<BOOL>(self,"loaded_");
  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0),^{
    while (!loaded) {
      loaded = MSHookIvar<BOOL>(self,"loaded_");
    }
    dispatch_async(dispatch_get_main_queue(),^{
      CydiaTabBarController *tabBarController = MSHookIvar<CydiaTabBarController *>(self,"tabbar_");
      if ([item.type isEqualToString:@"tactful_search"]) {
        UINavigationController *searchViewController = [tabBarController.viewControllers lastObject];
        [tabBarController setSelectedIndex:[tabBarController.viewControllers indexOfObject:searchViewController]];
        if (searchViewController.view.subviews.count > 1) {
          UIView *subview = [searchViewController.view.subviews objectAtIndex:1];
          if ([subview isKindOfClass:[UINavigationBar class]]) {
            [((UINavigationBar *)subview).topItem.titleView becomeFirstResponder];
          }
        }
      } else if ([item.type isEqualToString:@"tactful_recent"]) {
        UINavigationController *installedViewController = [tabBarController.viewControllers objectAtIndex:3];
        [tabBarController setSelectedIndex:3];
        if (installedViewController.view.subviews.count > 1) {
          UIView *subview = [installedViewController.view.subviews objectAtIndex:1];
          if ([subview isKindOfClass:[UINavigationBar class]]) {
            UIView *titleView = ((UINavigationBar *)subview).topItem.titleView;
            if ([titleView isKindOfClass:[UISegmentedControl class]]) {
              [((UISegmentedControl *)titleView) setSelectedSegmentIndex:((UISegmentedControl *)titleView).numberOfSegments-1];
              [((UISegmentedControl *)titleView) sendActionsForControlEvents:UIControlEventValueChanged];
            }
          }
        }
      } else if ([item.type isEqualToString:@"tactful_addrepo"]) {
        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"cydia://sources/add"]];
      } else if ([item.type isEqualToString:@"tactful_refreshrepo"]) {
        [tabBarController setSelectedIndex:2];
        [self requestUpdate];
      }
    });
  });
}

%end
%end

%group SpringBoard
%hook SBApplicationShortcutMenu

-(NSArray *)_shortcutItemsToDisplay {
  NSMutableArray *items = [%orig mutableCopy] ?: [NSMutableArray array];
  if ([[self.application bundleIdentifier] isEqualToString:@"com.saurik.Cydia"]) {
    SBSApplicationShortcutItem *searchItem = [[%c(SBSApplicationShortcutItem) alloc] init];
    [searchItem setType:@"tactful_search"];
    [searchItem setLocalizedTitle:@"Search Cydia"];
    SBSApplicationShortcutSystemIcon *searchIcon = [%c(SBSApplicationShortcutSystemIcon) alloc];
    searchIcon = [searchIcon initWithType:5]; //UIApplicationShortcutIconTypeSearch
    [searchItem setIcon:searchIcon];
    [items addObject:searchItem];

    SBSApplicationShortcutItem *recentInstallationItem = [[%c(SBSApplicationShortcutItem) alloc] init];
    [recentInstallationItem setType:@"tactful_recent"];
    [recentInstallationItem setLocalizedTitle:@"Recent Installations"];
    SBSApplicationShortcutSystemIcon *installIcon = [%c(SBSApplicationShortcutSystemIcon) alloc];
    installIcon = [installIcon initWithType:0]; //UIApplicationShortcutIconTypeCompose
    [recentInstallationItem setIcon:installIcon];
    [items addObject:recentInstallationItem];

    SBSApplicationShortcutItem *addRepoItem = [[%c(SBSApplicationShortcutItem) alloc] init];
    [addRepoItem setType:@"tactful_addrepo"];
    [addRepoItem setLocalizedTitle:@"Add Repo"];
    SBSApplicationShortcutSystemIcon *addRepoIcon = [%c(SBSApplicationShortcutSystemIcon) alloc];
    addRepoIcon = [addRepoIcon initWithType:3]; //UIApplicationShortcutIconTypeAdd
    [addRepoItem setIcon:addRepoIcon];
    [items addObject:addRepoItem];

    SBSApplicationShortcutItem *refreshReposItem = [[%c(SBSApplicationShortcutItem) alloc] init];
    [refreshReposItem setType:@"tactful_refreshrepo"];
    [refreshReposItem setLocalizedTitle:@"Refresh Repos"];
    SBSApplicationShortcutSystemIcon *refreshReposIcon = [%c(SBSApplicationShortcutSystemIcon) alloc];
    refreshReposIcon = [refreshReposIcon initWithType:6]; //UIApplicationShortcutIconTypeAdd
    [refreshReposItem setIcon:refreshReposIcon];
    [items addObject:refreshReposItem];

  }
  return [items copy];
}

%end
%end

%ctor {
  NSString *processName = [[NSProcessInfo processInfo] processName];
  if ([processName isEqualToString:@"SpringBoard"]) {
    %init(SpringBoard);
  } else if ([processName isEqualToString:@"Cydia"]) {
    %init(Cydia);
  }
}
