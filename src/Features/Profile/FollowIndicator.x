// Shows whether the current profile user follows you.

#import "../../AssetUtils.h"
#import "../../InstagramHeaders.h"
#import "../../Networking/SPKInstagramAPI.h"
#import "../../Utils.h"
#import "../General/CaptureHiding.h"
#import "FollowIndicator.h"
#import <objc/runtime.h>

NSNotificationName const SPKFollowIndicatorDidChangeNotification = @"SPKFollowIndicatorDidChangeNotification";

static NSInteger const kSPKFollowBadgeTag = 99788;
static const void *kSPKFollowStatusAssocKey = &kSPKFollowStatusAssocKey;

// Mode is a string pref ("off" | "text" | "icon" | "icontext"). It is
// intentionally NOT registered with a default so that, until the user picks a
// mode, we can fall back to the legacy on/off bool (`profile_follow_indicator`)
// and preserve the look for people who enabled the indicator before the mode
// menu existed. This fallback works across every pref namespace (global +
// per-account) without a migration write.
static NSString *SPKFollowIndicatorMode(void) {
    NSString *mode = [SPKUtils getStringPref:@"profile_follow_indicator_mode"];
    if (mode.length > 0)
        return mode;
    return [SPKUtils getBoolPref:@"profile_follow_indicator"] ? @"text" : @"off";
}

static BOOL SPKFollowIndicatorEnabled(void) {
    return ![SPKFollowIndicatorMode() isEqualToString:@"off"];
}

static BOOL SPKFollowIndicatorShowsIcon(void) {
    NSString *mode = SPKFollowIndicatorMode();
    return [mode isEqualToString:@"icon"] || [mode isEqualToString:@"icontext"];
}

static BOOL SPKFollowIndicatorShowsText(void) {
    NSString *mode = SPKFollowIndicatorMode();
    return [mode isEqualToString:@"text"] || [mode isEqualToString:@"icontext"];
}

// Weak set of profile controllers that have rendered a badge, so a settings
// change (posted via SPKFollowIndicatorDidChangeNotification) can refresh them
// in place — the settings sheet doesn't re-fire viewDidAppear underneath.
static NSHashTable *SPKFollowIndicatorControllers(void) {
    static NSHashTable *controllers;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        controllers = [NSHashTable weakObjectsHashTable];
    });
    return controllers;
}

// Colorful (green/red) is off by default: the indicator is native gray unless
// the user opts in. Like the mode key, no default is registered so a never-set
// value can fall back to the legacy bool — anyone who had the indicator enabled
// before this menu existed keeps their original colored look (text + colorful).
static BOOL SPKFollowIndicatorColorful(void) {
    id value = SPKPreferenceObjectForKey(@"profile_follow_indicator_colorful");
    if (value == nil)
        return [SPKUtils getBoolPref:@"profile_follow_indicator"];
    return [value boolValue];
}

// Colored green/red when opted in; otherwise Instagram's native gray for both.
static UIColor *SPKFollowIndicatorColor(BOOL followsYou) {
    if (!SPKFollowIndicatorColorful())
        return [SPKUtils SPKColor_InstagramSecondaryText];
    return followsYou ? [UIColor colorWithRed:0.30 green:0.75 blue:0.40 alpha:1.0]
                      : [UIColor colorWithRed:0.85 green:0.30 blue:0.30 alpha:1.0];
}

static NSString *SPKPKFromUserObject(id userObject) {
    if (!userObject)
        return nil;
    Ivar pkIvar = NULL;
    for (Class cls = [userObject class]; cls && !pkIvar; cls = class_getSuperclass(cls)) {
        pkIvar = class_getInstanceVariable(cls, "_pk");
    }
    if (!pkIvar)
        return nil;
    id pk = object_getIvar(userObject, pkIvar);
    return pk ? [pk description] : nil;
}

static NSString *SPKCurrentUserPK(void) {
    @try {
        for (UIWindowScene *scene in [UIApplication sharedApplication].connectedScenes) {
            if (![scene isKindOfClass:[UIWindowScene class]])
                continue;
            for (UIWindow *window in scene.windows) {
                id session = [window valueForKey:@"userSession"];
                if (!session)
                    continue;
                id user = [session valueForKey:@"user"];
                if (!user)
                    continue;
                NSString *pk = SPKPKFromUserObject(user);
                if (pk.length > 0)
                    return pk;
            }
        }
    } @catch (__unused NSException *exception) {
    }
    return nil;
}

static NSNumber *SPKGetFollowStatusForController(id controller) {
    return objc_getAssociatedObject(controller, kSPKFollowStatusAssocKey);
}

static void SPKSetFollowStatusForController(id controller, NSNumber *status) {
    objc_setAssociatedObject(controller, kSPKFollowStatusAssocKey, status, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static UIView *SPKProfileStatContainer(UIViewController *controller) {
    if (!controller.view)
        return nil;

    NSMutableArray<UIView *> *stack = [NSMutableArray arrayWithObject:controller.view];
    while (stack.count > 0) {
        UIView *view = stack.lastObject;
        [stack removeLastObject];

        if ([NSStringFromClass([view class]) containsString:@"StatButtonContainerView"]) {
            return view;
        }

        [stack addObjectsFromArray:view.subviews];
    }
    return nil;
}

static void SPKRenderFollowBadge(UIViewController *controller) {
    NSNumber *status = SPKGetFollowStatusForController(controller);
    if (!status)
        return;

    UIView *container = SPKProfileStatContainer(controller);
    if (!container)
        return;

    // Remove our previous wrapper (direct child only; the capture canvas may
    // have re-parented the inner label, so match on the wrapper's tag).
    for (UIView *sub in [container.subviews copy]) {
        if (sub.tag == kSPKCaptureFollowIndicatorTag)
            [sub removeFromSuperview];
    }

    // Re-check after clearing so a live settings change to "Off" (via the
    // refresh notification) removes the badge instead of redrawing it.
    if (!SPKFollowIndicatorEnabled())
        return;

    // Track this controller so a settings change can refresh it in place.
    [SPKFollowIndicatorControllers() addObject:controller];

    BOOL followsYou = status.boolValue;
    UIColor *accent = SPKFollowIndicatorColor(followsYou);
    BOOL showIcon = SPKFollowIndicatorShowsIcon();
    BOOL showText = SPKFollowIndicatorShowsText();

    UIImageView *iconView = nil;
    if (showIcon) {
        NSString *iconName = followsYou ? @"circle_check" : @"circle_xmark";
        UIImage *icon = [SPKAssetUtils instagramIconNamed:iconName
                                                pointSize:12.0
                                            renderingMode:UIImageRenderingModeAlwaysTemplate];
        iconView = [[UIImageView alloc] initWithImage:icon];
        iconView.contentMode = UIViewContentModeScaleAspectFit;
        iconView.tintColor = accent;
        [iconView sizeToFit];
    }

    UILabel *label = nil;
    if (showText) {
        label = [[UILabel alloc] init];
        label.text = followsYou ? @"FOLLOWING YOU" : @"NOT FOLLOWING YOU";
        label.font = [UIFont systemFontOfSize:11.0 weight:UIFontWeightMedium];
        label.textColor = accent;
        [label sizeToFit];
    }

    // Icon-only, text-only, or both laid out horizontally with a small gap.
    UIView *badge = nil;
    if (iconView && label) {
        CGFloat gap = 4.0;
        CGFloat iconW = CGRectGetWidth(iconView.bounds);
        CGFloat iconH = CGRectGetHeight(iconView.bounds);
        CGFloat labelW = CGRectGetWidth(label.bounds);
        CGFloat labelH = CGRectGetHeight(label.bounds);
        CGFloat totalH = MAX(iconH, labelH);
        badge = [[UIView alloc] initWithFrame:CGRectMake(0.0, 0.0, iconW + gap + labelW, totalH)];
        iconView.frame = CGRectMake(0.0, (totalH - iconH) / 2.0, iconW, iconH);
        label.frame = CGRectMake(iconW + gap, (totalH - labelH) / 2.0, labelW, labelH);
        [badge addSubview:iconView];
        [badge addSubview:label];
    } else {
        badge = iconView ?: label;
    }
    badge.tag = kSPKFollowBadgeTag;

    // Pin to the leftmost stat, not the first subview in array order: the stat
    // buttons aren't ordered left-to-right in `subviews`, so taking the first
    // one landed the badge under the middle stat and made it look centered. Take
    // the minimum minX (excluding our own wrapper) for a true left alignment.
    CGFloat xOrigin = CGFLOAT_MAX;
    for (UIView *subview in container.subviews) {
        if (subview.tag == kSPKCaptureFollowIndicatorTag)
            continue;
        if (!subview.isHidden && CGRectGetWidth(subview.frame) > 0.0) {
            xOrigin = MIN(xOrigin, CGRectGetMinX(subview.frame));
        }
    }
    if (xOrigin == CGFLOAT_MAX)
        xOrigin = 0.0;

    CGFloat badgeWidth = CGRectGetWidth(badge.bounds);
    CGFloat badgeHeight = CGRectGetHeight(badge.bounds);
    badge.frame = CGRectMake(0.0, 0.0, badgeWidth, badgeHeight);

    // Wrap the label in a capture-hidden container so it disappears from
    // screenshots/recordings when "Hide UI on Capture" is enabled. The capture
    // hooks redirect the wrapper's subviews into a secure canvas; a bare
    // UILabel's own text can't be hidden that way. When the pref is off the
    // wrapper is a plain passthrough.
    // Small bottom margin so the badge doesn't sit flush against the edge.
    CGFloat bottomMargin = 8.0;
    UIView *wrapper = [[UIView alloc] initWithFrame:CGRectMake(xOrigin,
                                                               CGRectGetHeight(container.bounds) - badgeHeight - bottomMargin,
                                                               badgeWidth,
                                                               badgeHeight)];
    wrapper.tag = kSPKCaptureFollowIndicatorTag;
    [wrapper addSubview:badge];
    [container addSubview:wrapper];
}

%group SPKFollowIndicatorHooks

%hook IGProfileViewController

- (void)viewDidAppear:(BOOL)animated {
    %orig;
    if (!SPKFollowIndicatorEnabled())
        return;

    NSNumber *cachedStatus = SPKGetFollowStatusForController(self);
    if (cachedStatus) {
        SPKRenderFollowBadge((UIViewController *)self);
        return;
    }

    id profileUser = nil;
    @try {
        profileUser = [(id)self valueForKey:@"user"];
    } @catch (__unused NSException *exception) {
    }
    if (!profileUser)
        return;

    NSString *profilePK = SPKPKFromUserObject(profileUser);
    NSString *currentUserPK = SPKCurrentUserPK();
    if (profilePK.length == 0 || currentUserPK.length == 0 || [profilePK isEqualToString:currentUserPK]) {
        return;
    }

    NSString *path = [NSString stringWithFormat:@"friendships/show/%@/", profilePK];
    __weak UIViewController *weakController = (UIViewController *)self;
    [SPKInstagramAPI sendRequestWithMethod:@"GET"
                                      path:path
                                      body:nil
                                completion:^(NSDictionary *response, NSError *error) {
                                    if (error || !response)
                                        return;
                                    BOOL followsYou = [response[@"followed_by"] boolValue];
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        UIViewController *strongController = weakController;
                                        if (!strongController)
                                            return;
                                        SPKSetFollowStatusForController(strongController, @(followsYou));
                                        SPKRenderFollowBadge(strongController);
                                    });
                                }];
}

- (void)viewDidLayoutSubviews {
    %orig;
    if (SPKFollowIndicatorEnabled()) {
        SPKRenderFollowBadge((UIViewController *)self);
    }
}

%end

%end

void SPKInstallFollowIndicatorHooksIfEnabled(void) {
    if (!SPKFollowIndicatorEnabled())
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKFollowIndicatorHooks);

        // Refresh visible profiles in place when the look changes from settings.
        [[NSNotificationCenter defaultCenter] addObserverForName:SPKFollowIndicatorDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
            for (UIViewController *controller in [SPKFollowIndicatorControllers() allObjects]) {
                SPKRenderFollowBadge(controller);
            }
        }];
    });
}
