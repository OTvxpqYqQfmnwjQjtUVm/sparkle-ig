#import <Foundation/Foundation.h>

// * Tweak version *
extern NSString *SPKVersionString;

// A milestone release (a redesign worth showing everyone) whose intro should replay
// the onboarding sheet for *all* users — fresh installs and updaters alike — and
// then chain into What's New, once. Only takes effect while it equals
// SPKVersionString; later releases fall back to normal gating (onboarding on true
// first-run only, What's New on upgrade). Bump it again only for the next milestone.
extern NSString *SPKForcedOnboardingVersion;

// Variables that work across features
extern __weak id SPKPendingDirectVisualMessageToMarkSeen;
extern NSString *SPKForcedStorySeenMediaPK;
extern BOOL SPKForceMarkStoryAsSeen;
extern BOOL SPKForceStoryAutoAdvance;

NSString *SPKStoryMediaIdentifier(id media);
