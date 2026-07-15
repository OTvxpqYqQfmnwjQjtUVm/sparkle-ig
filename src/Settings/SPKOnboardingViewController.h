#import "../Shared/UI/SPKPagedSheetViewController.h"

NS_ASSUME_NONNULL_BEGIN

/// Multi-step first-run introduction shown the first time the user opens Sparkle
/// settings. A thin subclass of `SPKPagedSheetViewController` supplying the intro
/// pages; present it with `+presentFromViewController:onFinish:` and stamp the
/// first-run default from the `onFinish` block.
@interface SPKOnboardingViewController : SPKPagedSheetViewController
@end

NS_ASSUME_NONNULL_END
