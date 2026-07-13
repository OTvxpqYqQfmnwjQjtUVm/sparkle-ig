#import "HeaderActionButton.h"

#import <objc/message.h>
#import <objc/runtime.h>

#import "../../AssetUtils.h"
#import "../../InstagramHeaders.h"
#import "../../Shared/Account/SPKAccountManager.h"
#import "../../Shared/Downloads/SPKDownloadService.h"
#import "../../Shared/Gallery/SPKGalleryViewController.h"
#import "../../Shared/UI/SPKChrome.h"
#import "../../Utils.h"
#import "../Messages/DeletedMessagesLog/SPKDeletedMessagesViewController.h"
#import "../Profile/ProfileAnalyzer/SPKProfileAnalyzerViewController.h"

NSString *const kSPKHeaderButtonEnabledKey = @"feed_header_button";
NSString *const kSPKHeaderButtonDefaultActionKey = @"feed_header_button_default";
NSString *const kSPKHeaderButtonDefaultActionMenu = @"menu";

// Destination identifiers double as the suffix of their per-destination pref key.
static NSString *const kSPKHeaderDestSettings = @"settings";
static NSString *const kSPKHeaderDestAnalyzer = @"analyzer";
static NSString *const kSPKHeaderDestGallery = @"gallery";
static NSString *const kSPKHeaderDestDeleted = @"deleted";
static NSString *const kSPKHeaderDestDownloads = @"downloads";

// IG-bundle icon name for the button's "Open Menu" glyph (same one every other
// Sparkle action button uses for its menu default).
static NSString *const kSPKHeaderMenuIconName = @"action";

static NSString *SPKHeaderDestPrefKey(NSString *identifier) {
    return [NSString stringWithFormat:@"feed_header_button_dest_%@", identifier];
}

// Layout constants.
static const CGFloat kSPKHeaderButtonSide = 44.0;    // button footprint
static const CGFloat kSPKHeaderButtonGlyph = 24.0;   // glyph point size
static const CGFloat kSPKHeaderButtonSpacing = 8.0;
static const CGFloat kSPKHeaderButtonLeftInset = 16.0;

static const void *kSPKHeaderButtonAssocKey = &kSPKHeaderButtonAssocKey;
static const void *kSPKHeaderButtonConfigSignatureAssocKey = &kSPKHeaderButtonConfigSignatureAssocKey;
static const void *kSPKHeaderButtonLastFrameAssocKey = &kSPKHeaderButtonLastFrameAssocKey;

#pragma mark - Destination model

@interface SPKHeaderDestination ()
@property (nonatomic, copy) NSString *identifier;
@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy) NSString *iconName;   // IG-bundle icon name
@property (nonatomic, copy) NSString *prefKey;
@property (nonatomic, copy) void (^present)(UIWindow *_Nullable);
@end

@implementation SPKHeaderDestination
+ (instancetype)destinationWithIdentifier:(NSString *)identifier
                                    title:(NSString *)title
                                 iconName:(NSString *)iconName
                                  present:(void (^)(UIWindow *_Nullable))present {
    SPKHeaderDestination *destination = [SPKHeaderDestination new];
    destination.identifier = identifier;
    destination.title = title;
    destination.iconName = iconName;
    destination.prefKey = SPKHeaderDestPrefKey(identifier);
    destination.present = present;
    return destination;
}
@end

NSArray<SPKHeaderDestination *> *SPKHeaderButtonAllDestinations(void) {
    static NSArray<SPKHeaderDestination *> *destinations;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        destinations = @[
            [SPKHeaderDestination destinationWithIdentifier:kSPKHeaderDestGallery
                                                      title:@"Gallery"
                                                   iconName:@"sparkle_gallery"
                                                    present:^(UIWindow *window) {
                                                        [SPKGalleryViewController presentGallery];
                                                    }],
            [SPKHeaderDestination destinationWithIdentifier:kSPKHeaderDestAnalyzer
                                                      title:@"Profile Analyzer"
                                                   iconName:@"profile_analyzer"
                                                    present:^(UIWindow *window) {
                                                        [SPKProfileAnalyzerViewController presentFromTop];
                                                    }],
            [SPKHeaderDestination destinationWithIdentifier:kSPKHeaderDestDeleted
                                                      title:@"Deleted Messages"
                                                   iconName:@"channels"
                                                    present:^(UIWindow *window) {
                                                        [SPKDeletedMessagesViewController presentFromViewController:nil];
                                                    }],
            [SPKHeaderDestination destinationWithIdentifier:kSPKHeaderDestDownloads
                                                      title:@"Downloads"
                                                   iconName:@"download"
                                                    present:^(UIWindow *window) {
                                                        [SPKDownloadService presentDownloadsHistorySheet];
                                                    }],
            [SPKHeaderDestination destinationWithIdentifier:kSPKHeaderDestSettings
                                                      title:@"Sparkle Settings"
                                                   iconName:@"settings"
                                                    present:^(UIWindow *window) {
                                                        [SPKUtils showSettingsVC:window];
                                                    }],
        ];
    });
    return destinations;
}

NSArray<SPKHeaderDestination *> *SPKHeaderButtonEnabledDestinations(void) {
    NSMutableArray<SPKHeaderDestination *> *enabled = [NSMutableArray array];
    for (SPKHeaderDestination *destination in SPKHeaderButtonAllDestinations()) {
        if ([SPKUtils getBoolPref:destination.prefKey])
            [enabled addObject:destination];
    }
    return enabled;
}

static SPKHeaderDestination *SPKHeaderDestinationForIdentifier(NSString *identifier) {
    for (SPKHeaderDestination *destination in SPKHeaderButtonAllDestinations()) {
        if ([destination.identifier isEqualToString:identifier])
            return destination;
    }
    return nil;
}

NSString *SPKHeaderButtonResolvedDefaultActionIdentifier(void) {
    NSString *saved = [SPKUtils getStringPref:kSPKHeaderButtonDefaultActionKey];
    SPKHeaderDestination *destination = SPKHeaderDestinationForIdentifier(saved);
    if (destination && [SPKUtils getBoolPref:destination.prefKey])
        return destination.identifier;
    return kSPKHeaderButtonDefaultActionMenu;
}

NSString *SPKHeaderButtonDefaultActionTitle(void) {
    NSString *identifier = SPKHeaderButtonResolvedDefaultActionIdentifier();
    SPKHeaderDestination *destination = SPKHeaderDestinationForIdentifier(identifier);
    return destination ? destination.title : @"Open Menu";
}

NSString *SPKHeaderButtonDefaultActionIconName(void) {
    NSString *identifier = SPKHeaderButtonResolvedDefaultActionIdentifier();
    SPKHeaderDestination *destination = SPKHeaderDestinationForIdentifier(identifier);
    return destination ? destination.iconName : kSPKHeaderMenuIconName;
}

#pragma mark - Header button view

// SPKChromeButton hosts the glyph in a secure canvas that morphs correctly with
// the iOS 26 menu-glass animation (same base every other Sparkle action button
// uses), so the button never vanishes mid-morph.
@interface SPKFeedHeaderActionButton : SPKChromeButton
@end

@implementation SPKFeedHeaderActionButton
- (void)spk_primaryTapped {
    NSString *defaultAction = [SPKUtils getStringPref:kSPKHeaderButtonDefaultActionKey];
    SPKHeaderDestination *destination = SPKHeaderDestinationForIdentifier(defaultAction);
    if (!destination || ![SPKUtils getBoolPref:destination.prefKey]) {
        SPKLog(@"HeaderButton", @"[Sparkle] Primary tap fired with no valid destination (default=%@)", defaultAction);
        return;
    }
    SPKLog(@"HeaderButton", @"[Sparkle] Primary tap → %@", destination.identifier);
    if (destination.present)
        destination.present(self.window);
}
@end

static void SPKHeaderFireShortcutHaptic(void) {
    if (![SPKUtils getBoolPref:@"tools_shortcut_haptics"])
        return;
    UISelectionFeedbackGenerator *feedback = [UISelectionFeedbackGenerator new];
    [feedback selectionChanged];
}

// Resolve one of a set of KVC-safe getters to a UIView (Swift ivars throw on KVC,
// so we go through selectors and type-check — same pattern as Navigation.xm).
static UIView *SPKHeaderSubview(id header, NSArray<NSString *> *keys) {
    for (NSString *key in keys) {
        SEL getter = NSSelectorFromString(key);
        if (![header respondsToSelector:getter])
            continue;
        id candidate = ((id (*)(id, SEL))objc_msgSend)(header, getter);
        if ([candidate isKindOfClass:[UIView class]])
            return candidate;
    }
    return nil;
}

@interface UIView (SPKHeaderButton)
- (SPKFeedHeaderActionButton *)spk_headerActionButton;
- (void)spk_installHeaderActionButtonIfNeeded;
- (void)spk_layoutHeaderActionButton;
- (void)spk_configureHeaderActionButton:(SPKFeedHeaderActionButton *)button;
@end

@implementation UIView (SPKHeaderButton)

- (SPKFeedHeaderActionButton *)spk_headerActionButton {
    return objc_getAssociatedObject(self, kSPKHeaderButtonAssocKey);
}

- (void)spk_installHeaderActionButtonIfNeeded {
    if ([self spk_headerActionButton])
        return;

    SPKFeedHeaderActionButton *button = [[SPKFeedHeaderActionButton alloc] initWithSymbol:@""
                                                                                pointSize:kSPKHeaderButtonGlyph
                                                                                 diameter:kSPKHeaderButtonSide];
    button.accessibilityIdentifier = @"spk-header-action-button";
    button.accessibilityLabel = @"Sparkle";
    button.translatesAutoresizingMaskIntoConstraints = YES;
    button.bubbleColor = UIColor.clearColor;

    UIView *heart = SPKHeaderSubview(self, @[ @"activityButton" ]);
    button.iconTint = heart.tintColor ?: [UIColor labelColor];

    __weak SPKFeedHeaderActionButton *weakButton = button;
    button.menuWillDisplayHandler = ^{
        (void)weakButton;
        SPKHeaderFireShortcutHaptic();
    };
    [button addTarget:button action:@selector(spk_primaryTapped) forControlEvents:UIControlEventTouchUpInside];

    objc_setAssociatedObject(self, kSPKHeaderButtonAssocKey, button, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self addSubview:button];
    SPKLog(@"HeaderButton", @"[Sparkle] Installed header action button into %@", NSStringFromClass(self.class));

    [self spk_configureHeaderActionButton:button];
}

// Signature of everything the button's menu / glyph depend on, so we only rebuild
// them when the user actually changes prefs — never during a layout/menu morph.
// (IG writes NSUserDefaults nearly every scroll frame, so a defaults-change
// observer is useless here — it would fire constantly; a value compare is what
// actually gates the work.)
static NSString *SPKHeaderButtonConfigSignature(NSArray<SPKHeaderDestination *> *enabled, NSString *defaultAction) {
    NSMutableArray<NSString *> *ids = [NSMutableArray array];
    for (SPKHeaderDestination *destination in enabled)
        [ids addObject:destination.identifier];
    return [NSString stringWithFormat:@"%@|%@", [ids componentsJoinedByString:@","], defaultAction ?: @""];
}

- (void)spk_configureHeaderActionButton:(SPKFeedHeaderActionButton *)button {
    NSArray<SPKHeaderDestination *> *enabled = SPKHeaderButtonEnabledDestinations();
    NSString *defaultAction = [SPKUtils getStringPref:kSPKHeaderButtonDefaultActionKey];

    if (enabled.count == 0) {
        button.hidden = YES;
        objc_setAssociatedObject(button, kSPKHeaderButtonConfigSignatureAssocKey,
                                 SPKHeaderButtonConfigSignature(enabled, defaultAction), OBJC_ASSOCIATION_COPY_NONATOMIC);
        SPKLog(@"HeaderButton", @"[Sparkle] No enabled destinations — hiding header button");
        return;
    }
    button.hidden = NO;

    // Build the long-press / tap-to-open menu from the enabled destinations.
    NSMutableArray<UIMenuElement *> *actions = [NSMutableArray array];
    for (SPKHeaderDestination *destination in enabled) {
        UIImage *image = [SPKAssetUtils menuIconNamed:destination.iconName];
        __weak SPKFeedHeaderActionButton *weakButton = button;
        UIAction *action = [UIAction actionWithTitle:destination.title
                                               image:image
                                          identifier:nil
                                             handler:^(__unused UIAction *unusedAction) {
                                                 SPKLog(@"HeaderButton", @"[Sparkle] Menu → %@", destination.identifier);
                                                 if (destination.present)
                                                     destination.present(weakButton.window);
                                             }];
        [actions addObject:action];
    }
    button.menu = [UIMenu menuWithChildren:actions];

    // Resolve the configured default tap action.
    SPKHeaderDestination *defaultDestination = SPKHeaderDestinationForIdentifier(defaultAction);
    BOOL defaultIsValid = defaultDestination && [enabled containsObject:defaultDestination];

    if (defaultIsValid) {
        // Tap = the chosen destination, long-press = menu. Glyph mirrors the destination.
        button.showsMenuAsPrimaryAction = NO;
        [button setIconResource:defaultDestination.iconName pointSize:kSPKHeaderButtonGlyph];
    } else {
        // Tap = open menu, glyph = the Sparkle menu icon.
        button.showsMenuAsPrimaryAction = YES;
        [button setIconResource:kSPKHeaderMenuIconName pointSize:kSPKHeaderButtonGlyph];
    }

    objc_setAssociatedObject(button, kSPKHeaderButtonConfigSignatureAssocKey,
                             SPKHeaderButtonConfigSignature(enabled, defaultAction), OBJC_ASSOCIATION_COPY_NONATOMIC);
    // Force one reposition after a reconfigure (glyph swap can change intrinsic state).
    objc_setAssociatedObject(button, kSPKHeaderButtonLastFrameAssocKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);

    SPKLog(@"HeaderButton", @"[Sparkle] Configured header button: enabled=%lu default=%@ primaryIsMenu=%@",
           (unsigned long)enabled.count, defaultAction, button.showsMenuAsPrimaryAction ? @"YES" : @"NO");
}

- (void)spk_layoutHeaderActionButton {
    SPKFeedHeaderActionButton *button = [self spk_headerActionButton];
    if (!button)
        return;

    // Respect the per-account master toggle at layout time (not just at install):
    // after a live account switch the hooks stay installed, so re-read the toggle
    // for the current account and hide the button on accounts that disabled it.
    if (![SPKUtils getBoolPref:kSPKHeaderButtonEnabledKey]) {
        button.hidden = YES;
        return;
    }

    // Reconfigure the menu/glyph ONLY when the config signature actually changes —
    // a cheap value compare, not a rebuild. This is what keeps the expensive menu
    // rebuild off the per-frame path (and out of the menu morph). The pref reads
    // for the signature are trivial next to what layoutSubviews already does.
    NSArray<SPKHeaderDestination *> *enabled = SPKHeaderButtonEnabledDestinations();
    NSString *defaultAction = [SPKUtils getStringPref:kSPKHeaderButtonDefaultActionKey];
    NSString *signature = SPKHeaderButtonConfigSignature(enabled, defaultAction);
    NSString *storedSignature = objc_getAssociatedObject(button, kSPKHeaderButtonConfigSignatureAssocKey);
    if (![signature isEqualToString:storedSignature]) {
        [self spk_configureHeaderActionButton:button];
    }
    // No destinations enabled at all → stay hidden regardless of layout.
    if (enabled.count == 0) {
        button.hidden = YES;
        return;
    }

    UIView *heart = SPKHeaderSubview(self, @[ @"activityButton" ]);
    UIView *messages = SPKHeaderSubview(self, @[ @"directButton" ]);

    // Convert an anchor's bounds into this header's coordinate space so the math
    // holds whether IG parents these buttons directly on the header or nests them
    // in a cluster container. Returns CGRectNull for a missing/detached anchor.
    CGRect (^frameInHeader)(UIView *) = ^CGRect(UIView *anchor) {
        if (!anchor || !anchor.window)
            return CGRectNull;
        return [self convertRect:anchor.bounds fromView:anchor];
    };

    CGRect heartFrame = frameInHeader(heart);
    BOOL haveHeart = !CGRectIsNull(heartFrame) && heartFrame.size.width > 1.0;
    CGRect messagesFrame = frameInHeader(messages);
    BOOL haveMessages = !CGRectIsNull(messagesFrame) && messagesFrame.size.width > 1.0;

    // Tie our button's lifecycle to IG's own nav buttons. When the header collapses
    // on scroll — or uses an immersive/transparent variant — IG fades those buttons
    // out. It does this by animating an ANCESTOR accessory container's alpha (the
    // heart's own alpha stays 1), so reading heart.alpha alone never sees the fade
    // and we'd linger in the status-bar sliver the collapsed header leaves behind.
    // Compute the anchor's effective opacity relative to the header by walking up
    // the superview chain multiplying alphas / honouring hidden, and mirror it.
    UIView *visAnchor = haveHeart ? heart : (haveMessages ? messages : nil);
    if (!visAnchor || !visAnchor.window) {
        button.hidden = YES;
        return;
    }
    CGFloat effectiveAlpha = 1.0;
    BOOL anyHidden = NO;
    for (UIView *v = visAnchor; v && v != self; v = v.superview) {
        effectiveAlpha *= v.alpha;
        if (v.hidden)
            anyHidden = YES;
    }
    if (anyHidden || effectiveAlpha <= 0.01) {
        button.hidden = YES;
        return;
    }
    button.hidden = NO;
    button.alpha = effectiveAlpha;

    CGFloat side = kSPKHeaderButtonSide;
    CGFloat centerY = haveHeart ? CGRectGetMidY(heartFrame) : CGRectGetMidY(messagesFrame);

    // The create ("add to story") + button sits on the LEFT of the header, so it's
    // not our anchor. What distinguishes the two layouts is the messages button:
    // standard order keeps messages as a bottom tab (right cluster = heart only),
    // classic order moves create to the bottom bar and puts messages next to the
    // heart. When the right side is that crowded, dock on the far left — and use a
    // FIXED inset there, never the logo (the logo morphs between the wordmark and
    // the "For you" picker, which used to drag the button around, including to the
    // center when the menu opened).
    CGFloat x = haveMessages ? (self.safeAreaInsets.left + kSPKHeaderButtonLeftInset)
                             : (CGRectGetMinX(heartFrame) - kSPKHeaderButtonSpacing - side);

    CGRect expectedFrame = CGRectMake(floor(x), floor(centerY - side / 2.0), side, side);

    // Frame-equality guard: if we're already parented here at the right frame, do
    // nothing. This is what stops the layout churn / mid-animation reset that makes
    // injected buttons blink out during the iOS 26 menu morph.
    NSValue *lastVal = objc_getAssociatedObject(button, kSPKHeaderButtonLastFrameAssocKey);
    CGRect lastFrame = lastVal ? [lastVal CGRectValue] : CGRectNull;
    if (button.superview == self && !CGRectIsNull(lastFrame) && CGRectEqualToRect(expectedFrame, lastFrame)) {
        return;
    }

    button.frame = expectedFrame;
    objc_setAssociatedObject(button, kSPKHeaderButtonLastFrameAssocKey, [NSValue valueWithCGRect:expectedFrame], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    [self bringSubviewToFront:button];
    SPKLog(@"HeaderButton", @"[Sparkle] Laid out header button haveHeart=%@ haveMessages=%@ alpha=%.2f heart=%@ frame=%@",
           haveHeart ? @"YES" : @"NO", haveMessages ? @"YES" : @"NO", effectiveAlpha,
           NSStringFromCGRect(heartFrame), NSStringFromCGRect(expectedFrame));
}

@end

#pragma mark - Hooks

%group SPKHeaderActionButtonHooks

%hook IGHomeFeedHeaderView

- (void)didMoveToWindow {
    %orig;
    if ([(UIView *)self window])
        [self spk_installHeaderActionButtonIfNeeded];
}

- (void)layoutSubviews {
    %orig;
    // Install here too: the feed header is usually created before our delayed
    // Feed-surface hooks land, so its first didMoveToWindow already fired. Every
    // relayout gives us a reliable, idempotent chance to inject the button.
    if ([(UIView *)self window])
        [self spk_installHeaderActionButtonIfNeeded];
    [self spk_layoutHeaderActionButton];
}

%end

%end

// Depth-first search for the first live view of `cls` under `root`.
static UIView *SPKFindViewOfClass(UIView *root, Class cls) {
    if (!root)
        return nil;
    if ([root isKindOfClass:cls])
        return root;
    for (UIView *subview in root.subviews) {
        UIView *match = SPKFindViewOfClass(subview, cls);
        if (match)
            return match;
    }
    return nil;
}

// Kick any header that's already on screen when the hooks install, so the button
// appears without waiting for the next relayout / tab switch.
static void SPKKickExistingHeader(Class headerClass) {
    dispatch_async(dispatch_get_main_queue(), ^{
        for (UIWindow *window in UIApplication.sharedApplication.windows) {
            UIView *header = SPKFindViewOfClass(window, headerClass);
            if (!header)
                continue;
            SPKLog(@"HeaderButton", @"[Sparkle] Kicking existing header %@", NSStringFromClass(header.class));
            [header spk_installHeaderActionButtonIfNeeded];
            [header setNeedsLayout];
            [header spk_layoutHeaderActionButton];
            return;
        }
        SPKLog(@"HeaderButton", @"[Sparkle] No existing header on screen to kick");
    });
}

void SPKInstallHeaderActionButtonHooksIfEnabled(void) {
    // Register the account-change observer once, BEFORE the master-toggle gate, so
    // it fires even when the launch account had the button disabled. On a live
    // account switch it (a) re-runs this installer — installing the hooks if the
    // new account has the button enabled — and (b) kicks the on-screen header so it
    // re-reads the new account's per-account prefs (enabled/destinations/default).
    static dispatch_once_t observerOnce;
    dispatch_once(&observerOnce, ^{
        [[NSNotificationCenter defaultCenter] addObserverForName:SPKAccountDidChangeNotification
                                                          object:nil
                                                           queue:[NSOperationQueue mainQueue]
                                                      usingBlock:^(__unused NSNotification *note) {
                                                          SPKInstallHeaderActionButtonHooksIfEnabled();
                                                          Class headerClass = SPKResolveIGClass(@"IGHomeFeedHeader.IGHomeFeedHeaderView", @"IGHomeFeedHeaderView");
                                                          if (headerClass)
                                                              SPKKickExistingHeader(headerClass);
                                                      }];
    });

    if (![SPKUtils getBoolPref:kSPKHeaderButtonEnabledKey]) {
        SPKLog(@"HeaderButton", @"[Sparkle] Header action button disabled — skipping install");
        return;
    }

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class headerClass = SPKResolveIGClass(@"IGHomeFeedHeader.IGHomeFeedHeaderView", @"IGHomeFeedHeaderView");
        if (!headerClass) {
            SPKLog(@"HeaderButton", @"[Sparkle] Could not resolve IGHomeFeedHeaderView — header button unavailable");
            return;
        }
        %init(SPKHeaderActionButtonHooks, IGHomeFeedHeaderView = headerClass);
        SPKLog(@"HeaderButton", @"[Sparkle] Installed header action button hooks class=%@", NSStringFromClass(headerClass));
        SPKKickExistingHeader(headerClass);
    });
}
