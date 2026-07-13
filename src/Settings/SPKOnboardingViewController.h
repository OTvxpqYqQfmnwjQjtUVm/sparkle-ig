#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Multi-step first-run introduction shown the first time the user opens Sparkle
/// settings. Presented modally over the settings screen; call `-presentFromViewController:`
/// and pass a completion block that persists the first-run flag.
@interface SPKOnboardingViewController : UIViewController

/// Invoked once, when the user finishes or skips onboarding (after the sheet has
/// dismissed). Use it to stamp the first-run default.
@property (nonatomic, copy, nullable) void (^onFinish)(void);

/// Presents the onboarding modally as a page sheet from `presenter` (or the
/// top-most view controller when `presenter` is nil). `onFinish` runs after the
/// sheet dismisses — pass nil for a manual replay that must not change first-run
/// state. No-ops if a presentation is already in flight on the presenter.
+ (void)presentFromViewController:(nullable UIViewController *)presenter
                         onFinish:(nullable void (^)(void))onFinish;

@end

NS_ASSUME_NONNULL_END
