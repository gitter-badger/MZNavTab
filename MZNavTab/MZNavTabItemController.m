//
//  MZNavTabItemController.m
//  MZNavTab
//
//  Created by Jamin on 2/26/15.
//  Copyright (c) 2015 MZ. All rights reserved.
//

#import "MZNavTabItemController.h"

@interface MZNavTabItemController ()

@property (nonatomic, weak) UIViewController * lastPopViewController;
@property (nonatomic, assign) CGFloat tabBarHeight;


@end

@implementation MZNavTabItemController
@synthesize tabBar = _tabBar;



#pragma mark - UINavigationController
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        self.supportAutoLayout = NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_6_0;
    }

    return self;
}


- (void)awakeFromNib
{
    [super awakeFromNib];
    self.supportAutoLayout = NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_6_0;
}



#pragma mark - Override 

- (UIViewController *)popViewControllerAnimated:(BOOL)animated
{
    self.lastPopViewController = [super popViewControllerAnimated:animated];
    return self.lastPopViewController;
}



#pragma mark - TabBar
- (void)setTabBar:(UIView *)tabBar
{
    if (_tabBar == tabBar) {
        return;
    }

    _tabBar = tabBar;
    self.tabBarHeight = tabBar.frame.size.height;
}

- (void)attachTabbarOnViewController:(UIViewController *)viewController
{
    //push
    CGRect bounds = viewController.view.bounds;
    CGFloat tabBarHeight = self.tabBar.bounds.size.height;
    CGRect tabbarFrame = CGRectMake(0, bounds.size.height - tabBarHeight,
                                    bounds.size.width, tabBarHeight);
    UIView * containnerView = viewController.view;

    BOOL shouldAutoLayout = self.supportAutoLayout;
    //Adjust for UITableViewController
    if ([containnerView isKindOfClass:[UIScrollView class]]) {
//        [self.tabBar setTranslatesAutoresizingMaskIntoConstraints:YES];
        UIScrollView * scrollView = (UIScrollView *)containnerView;
        tabbarFrame.origin.y += scrollView.contentOffset.y;
        shouldAutoLayout = NO;

        if (NSFoundationVersionNumber >= NSFoundationVersionNumber_iOS_7_0) {
            if (nil == scrollView.superview
                && (viewController.edgesForExtendedLayout & UIRectEdgeTop)
                && viewController.automaticallyAdjustsScrollViewInsets) {
                CGRect navFrame = self.navigationBar.frame;
                tabbarFrame.origin.y -= navFrame.origin.y + navFrame.size.height;
                tabbarFrame.origin.y += scrollView.contentInset.top;
            }
        }
    }

    self.tabBar.frame = tabbarFrame;
    self.tabBar.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin;

    if (self.tabBar.superview == viewController.view) {
        return;
    }

    [containnerView addSubview:self.tabBar];
    [self.tabBar setTranslatesAutoresizingMaskIntoConstraints:!shouldAutoLayout];

    if (shouldAutoLayout) {
        NSMutableArray * tabBarLayoutConstraints = [NSMutableArray array];
        NSDictionary * views = @{@"tabBar": self.tabBar};
        NSDictionary * heightMetrics = @{@"tabBarHeight": @(self.tabBarHeight)};
        NSArray * hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[tabBar]|"
                                                                         options:0
                                                                         metrics:nil
                                                                           views:views];
        NSArray * vConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"V:[tabBar(tabBarHeight)]|"
                                                                         options:0
                                                                         metrics:heightMetrics
                                                                           views:views];
        [tabBarLayoutConstraints addObjectsFromArray:hConstraints];
        [tabBarLayoutConstraints addObjectsFromArray:vConstraints];
        [viewController.view addConstraints:tabBarLayoutConstraints];
    }
}



- (void)setTabBarHidden:(BOOL)hidden animated:(BOOL)animate
{
    CGRect bounds = self.tabBar.superview.bounds;
    CGRect tabBarFrame = self.tabBar.frame;
    CGFloat tabBarHeight = tabBarFrame.size.height;
    CGRect normalFrame = tabBarFrame;
    normalFrame.origin.y = bounds.size.height - tabBarHeight;

    CGRect hideFrame = tabBarFrame;
    hideFrame.origin.y = bounds.size.height;

    CGRect targetFrame = tabBarFrame;
    if (hidden) {
        targetFrame = hideFrame;
    } else {
        targetFrame = normalFrame;
    }

    if (CGRectEqualToRect(targetFrame, tabBarFrame)) {
        return;
    }

    void(^hideBlock)() = ^{
        self.tabBar.frame = targetFrame;
    };

    void(^completionBlock)(BOOL isFinished) = ^(BOOL isFinished) {
        self.tabBar.frame = targetFrame;
        self.tabBar.hidden = hidden;
    };

    if (animate) {
        self.tabBar.hidden = NO;
        [UIView animateWithDuration:0.3
                              delay:0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:hideBlock
                         completion:completionBlock];
    } else {
        hideBlock();
        completionBlock(YES);
    }

}



#pragma mark - UINavigationControllerDelegate
- (void)navigationController:(UINavigationController *)navigationController
      willShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    //无动画则无需下面的调整
    if (!animated) {
        return;
    }

    if (![navigationController isKindOfClass:[self class]]) {
        return;
    }

    MZNavTabItemController * myNavController = (MZNavTabItemController *)navigationController;

    UINavigationControllerOperation currentOperation = [myNavController latestNavOperation];
    BOOL shouldHideTabBar = (navigationController.viewControllers.count > 1);
    if ([viewController respondsToSelector:@selector(shouldHideTabBar)]) {
        shouldHideTabBar = [(id<MZNavTabItemChildViewController>)viewController shouldHideTabBar];
    }

    if (shouldHideTabBar) {

        if (!self.tabBar.isHidden) {
            UIViewController * prevViewController = nil;
            if (currentOperation == UINavigationControllerOperationPush) {
                //当前是push操作，将tabbar放在viewController上一个VC上
                //If current operation is pushing, show tabbar on preview VC
                NSArray * viewControllers = navigationController.viewControllers;
                NSUInteger count = viewControllers.count;
                if (count >= 2) {
                    prevViewController = viewControllers[count - 2];
                }
            } else if (currentOperation == UINavigationControllerOperationPop) {
                prevViewController = myNavController.lastPopViewController;
            }

            //check if prevViewController need to show tabbar
            BOOL shouldHideTabBarOnPrevVC = NO;
            if ([prevViewController respondsToSelector:@selector(shouldHideTabBar)]) {
                BOOL shouldHideTabBarOnPrevVC = [(id<MZNavTabItemChildViewController>)prevViewController shouldHideTabBar];
                self.tabBar.hidden = shouldHideTabBarOnPrevVC;
            }

            if (!shouldHideTabBarOnPrevVC) {
                [self attachTabbarOnViewController:prevViewController];
            }
        }

    } else {
        self.tabBar.hidden = NO;
        [self attachTabbarOnViewController:viewController];
    }
}

- (void)navigationController:(UINavigationController *)navigationController
       didShowViewController:(UIViewController *)viewController
                    animated:(BOOL)animated
{
    //在根页面的时候显示
    BOOL shouldHideTabBar = (navigationController.viewControllers.count > 1);
    if ([viewController respondsToSelector:@selector(shouldHideTabBar)]) {
        shouldHideTabBar = [(id<MZNavTabItemChildViewController>)viewController shouldHideTabBar];
    }

    if (nil != self.tabBarViewController) {
        [self attachTabbarOnViewController:self.tabBarViewController];
    }
//    [self setTabBarHidden:shouldHideTabBar animated:NO];
    self.tabBar.hidden = shouldHideTabBar;

    [super navigationController:navigationController
          didShowViewController:viewController
                       animated:animated];
}



@end
