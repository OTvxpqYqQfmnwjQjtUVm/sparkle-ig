#import "../../InstagramHeaders.h"
#import "../../Utils.h"

// "Story Preview" (peek a story from the long-press menu without appearing on
// the viewer list) is an Instagram Plus feature. The real story media is already
// prefetched and IG renders it for real — for non-subscribers it just builds the
// peek in "upsell" mode (blur + "Instagram Plus / Upgrade now" overlay, no video
// playback / auto-advance), and the separate "See preview" menu item opens the
// subscribe page (a dead end when sideloaded).
//
// The upsell-vs-real decision is made by IGConsumerSubsStoryPeekEligibility:
// isPeekEligible → real peek mode, isUpsellPeekEligible → upsell. Both the feed
// story-tray and DM-inbox entry points funnel through it (confirmed on-device:
// forcing isPeekEligible to YES makes the coordinator hand the peek its real
// "media" peekMode=0, and video/auto-advance/no-seen all work). The service-level
// isStoryPeeksBenefitEnabled flag is NOT consulted here, so we gate above it.
//
// Behind stories_unlock_preview we force the eligibility gate to real peek, and
// redirect the DM manager's presentPeekUpsell… to presentPeek… as a belt-and-
// suspenders for the DM entry.
//
// These classes are Swift; their runtime names are the mangled _TtC form and do
// not exist on IG 410 (iOS 15) where Instagram Plus is absent, so %hook binds
// nothing there.

static inline BOOL SPKUnlockStoryPreviewEnabled(void) {
    return [SPKUtils getBoolPref:@"stories_unlock_preview"];
}

%group SPKUnlockStoryPreviewHooks

// Demangled: IGConsumerSubsStoryPeekEligibility.IGConsumerSubsStoryPeekEligibility
%hook _TtC34IGConsumerSubsStoryPeekEligibility34IGConsumerSubsStoryPeekEligibility

+ (BOOL)isPeekEligibleForEntryPoint:(long long)point viewModelType:(long long)type consumerSubsService:(id)service launcherSet:(id)set {
    if (SPKUnlockStoryPreviewEnabled()) {
        return YES;
    }
    return %orig;
}

+ (BOOL)isUpsellPeekEligibleForEntryPoint:(long long)point viewModelType:(long long)type consumerSubsService:(id)service launcherSet:(id)set {
    if (SPKUnlockStoryPreviewEnabled()) {
        return NO;
    }
    return %orig;
}

+ (BOOL)isAnyPeekEligibleForEntryPoint:(long long)point viewModelType:(long long)type consumerSubsService:(id)service launcherSet:(id)set {
    if (SPKUnlockStoryPreviewEnabled()) {
        return YES;
    }
    return %orig;
}

%end

// Belt-and-suspenders for the DM-inbox entry: if IG ever still routes through
// the upsell presenter, hand it the real one instead.
// Demangled: IGConsumerSubsStoryPeekDirectPlugin.IGConsumerSubsStoryPeekDirectManager
%hook _TtC35IGConsumerSubsStoryPeekDirectPlugin36IGConsumerSubsStoryPeekDirectManager
- (void)presentPeekUpsellWithSourceView:(id)view reelPK:(id)pk presenting:(id)presenting onSubscribeToInstagramPlus:(id)onSubscribe onViewProfile:(id)onViewProfile {
    if (SPKUnlockStoryPreviewEnabled()) {
        SPKLog(@"Peek", @"[Sparkle] DM peek upsell intercepted, showing real preview");
        [self presentPeekWithSourceView:view reelPK:pk presenting:presenting onTapToOpenStory:nil onViewProfile:onViewProfile];
        return;
    }
    %orig(view, pk, presenting, onSubscribe, onViewProfile);
}
%end

%end

void SPKInstallUnlockStoryPreviewHooksIfEnabled(void) {
    if (!SPKUnlockStoryPreviewEnabled())
        return;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        %init(SPKUnlockStoryPreviewHooks);
    });
}
