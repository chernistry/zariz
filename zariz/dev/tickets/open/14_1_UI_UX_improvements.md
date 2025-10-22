Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

When you finish this ticket, mark it in the roadmap: /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/roadmap.md (if step is missed, add it)

UI/UX Redesign of SwiftUI Courier App with Modern Design System and SDKs

1. Task Summary

Objective: Elevate the app’s UI/UX to a modern, polished standard comparable to Wolt/Uber/Bolt. This involves implementing a comprehensive SwiftUI-based Design System and integrating well-maintained UI component libraries (bottom sheets, popovers, toasts, skeletons, animations, image caching) to refresh the visual design without altering backend APIs.

Expected Outcome: A consistent, high-quality interface with reusable design tokens and components. All screens (Auth, Orders List, Order Detail, Profile) will have improved layouts, modern controls (e.g. segmented tabs, cards, badges), and subtle animations/haptics, while preserving existing functionality. The app will support light/dark themes, multiple languages (including RTL), and Dynamic Type, ensuring accessibility.

Success Criteria: The app UI looks cohesive and up-to-date; interactions (e.g. claiming an order) provide immediate visual feedback (animated state changes, toasts) and tactile response (haptics). Orders list scrolling is smooth with skeleton loaders in place. No regressions in functionality, and all acceptance criteria (section 11) are met.

Go/No-Go Preconditions: iOS 16+ deployment target (to leverage modern SwiftUI APIs) is confirmed. No backend changes required (the UI overhaul must function with current API responses). Design assets (brand colors, icons, any Lottie files for micro-animations) are prepared. Only proceed if third-party UI libraries chosen are compatible with app licensing and have recent support for Swift 5.9+/iOS 16.

2. Assumptions & Scope

Assumptions: The app uses SwiftUI (MVVM) for all UI; existing logic and network calls remain unchanged. We assume that increasing the app’s binary size moderately (for adding UI libraries or animation assets) is acceptable. The user base runs iOS 16 or later, so new SwiftUI capabilities can be used freely. The design tokens will be defined for both light and dark mode.

In Scope: Visual and interaction improvements to all frontend screens and components. Introduction of new UI libraries (via SPM) to support advanced UI elements (sheets, toasts, etc.). Establishing a design token system (colors, typography, spacing, etc.) and updating existing views to use them. Enhancing accessibility (Dynamic Type scaling, VoiceOver labels) and internationalization (RTL layout flips, locale-based strings) as part of the UI polish.

Out of Scope: Changes to network layer, data models, or backend APIs (all integration points remain as is). New app features (e.g. live geolocation, new order types) are not included. We will not redesign the app’s navigation flow or add entirely new screens. Server-side modifications and push notification handling logic remain untouched.

Constraints: Maintain performance – e.g., p95 frame render time under 16ms (60 FPS) for scrolls and animations. Memory overhead of new libraries must be modest. Ensure privacy/security – no sensitive data is logged in new UI events, and no new data storage beyond user preferences. Accessibility compliance is required (WCAG contrast for text, tappable control size ≥44px, etc.). The design system should be easy for developers to maintain (clear token naming and usage patterns) and should not introduce significant tech debt.

Non-Goals: This project is not a complete rebrand or overhaul of business logic – it specifically targets UI/UX consistency and modern aesthetics. We are not changing how data is fetched or stored, nor altering user flows beyond UI polish. Also, we won’t introduce custom gesture-heavy interactions beyond what the new UI components provide (to avoid scope creep).

Performance Budgets: Keep view transitions smooth (e.g., Order Detail presentation within 300ms, skeleton-to-content swap with minimal lag). Cold launch time should not regress significantly (target < 2s to first screen; lazy-load heavy assets like Lottie files). Any heavy animations or image decoding should be done off the main thread where possible.

3. Architecture Overview

Layered UI Architecture: We introduce a Design System layer that defines visual tokens (colors, fonts, etc.) and base components. On top of this, a UI Components layer provides ready-to-use SwiftUI views (buttons, cards, etc.) styled with those tokens. Screens (Auth, OrdersList, OrderDetail, Profile) will compose these UI components. We integrate 3rd-party SwiftUI UI libraries for complex elements (e.g. sheets, popovers) – these are wrapped or used within our UI Components for consistency. The existing Networking layer (REST API via URLSession) and Push Notification handling remain unchanged and continue to feed data/state into the Views. The flow is: App (SwiftUI) → Design System (tokens & styles) → UI Components → Screens/Views → Networking (which communicates with backend). Push notifications go directly to the app state and update screens as before, unaffected by UI changes.

flowchart TD
    App[Courier App (SwiftUI)] --> DesignSystem[[Design System<br/>(Tokens & Styles)]]
    DesignSystem --> UIComponents[[Reusable UI Components]]
    UIComponents --> AuthScreen
    UIComponents --> OrdersListScreen
    UIComponents --> OrderDetailScreen
    UIComponents --> ProfileScreen
    subgraph " "
      AuthScreen[Auth Screen]
      OrdersListScreen[Orders List Screen]
      OrderDetailScreen[Order Detail Screen]
      ProfileScreen[Profile Screen]
    end
    OrdersListScreen -- calls --> Networking
    OrderDetailScreen -- calls --> Networking
    AuthScreen -- calls --> Networking
    ProfileScreen -- calls --> Networking
    Networking --> Backend[(REST API Backend)]
    Backend -.unchanged APIs.-> Networking
    PushService[(APNs Push Service)] -. pushes .-> App
    classDef ext fill:#f0f0f0,stroke:#333,stroke-width:1,color:#000;
    PushService,Backend class ext


Library Choices & Justification: We evaluated modern SwiftUI libraries for each required capability, focusing on performance, maintenance, and compatibility:

Bottom Sheets: Considered using iOS16’s native partial sheets (.presentationDetents) versus community packages. Option 1: Lucaszischka/BottomSheet – pure SwiftUI, supports multiple custom detents (states) and dynamic height
github.com
github.com
. Pros: MIT licensed, ~1.2k stars, last release 3.1.1 (mid-2023)
github.com
, highly customizable (e.g., any number of states, built-in header) and works on iOS13+
github.com
. Option 2: fatbobman/SheetKit – SwiftUI extensions for UISheetPresentationController (iOS15+ half-modal)
github.com
. Pros: lightweight, uses Apple’s API under the hood; Cons: smaller community (124 stars
github.com
), focuses more on central sheet management than custom UI. Option 3: SCENEE/FloatingPanel (popular for UIKit). Pros: very polished, 12k+ stars; Cons: UIKit-based (needs representable bridging) and larger dependency. Decision: Chosen Lucaszischka’s BottomSheet for a native SwiftUI solution that closely mimics Apple Maps-style panels (multiple heights)
github.com
. It’s actively maintained and easy to integrate via SwiftPM
github.com
. We’ll wrap our Order Detail actions in this component for a slick sliding panel experience. SheetKit is an alternative if we face issues, but BottomSheet’s flexibility and pure SwiftUI approach make it the best fit.

Popovers & Tooltips: Option 1: aheze/Popovers – a popular SwiftUI library for presenting popovers, tooltips, menus, even notifications
github.com
. Pros: MIT license, ~2.2k stars
github.com
, supports multiple simultaneous popovers with smooth transitions and iPad multitasking, no dependencies, highly customizable API (just add .popover modifier)
swiftpackageregistry.com
. Option 2: Apple TipKit (iOS 17) – new framework for tooltips. Pros: native Apple solution; Cons: requires iOS17 (not in our deployment scope) and limited to educational tips. Option 3: PopOverMenu (tichise) – older library primarily for menu popovers. Pros: long-developed; Cons: UIKit-based, less SwiftUI-friendly. Decision: Popovers by aheze is selected for its simplicity and breadth: it covers popover tips, contextual menus, and even in-app notification banners with one unified package
swiftpackageregistry.com
. It works on iOS13+, fitting our iOS16 baseline, and is purely SwiftUI with no additional dependencies, which keeps our bundle lean. This will let us implement things like a language menu or tooltip help prompts with minimal effort.

Toasts & Non-blocking Notifications: Option 1: elai950/AlertToast – a SwiftUI library for Apple-like toasts/alerts (drop-in view modifier). Pros: Pure SwiftUI, multiple styles (center alert, HUD from top, banner from bottom)
github.com
, supports configurable icons (checkmark, error xmark, custom image) and auto-dismiss timers. It’s MIT-licensed, ~2.4k stars
swiftpackageindex.com
, with latest tag 1.3.9, and no dependencies
swiftpackageindex.com
. Option 2: sanzaru/SimpleToast – lightweight toast library (Apache 2.0, ~460 stars) focusing on flexible placement
github.com
. Cons: fewer built-in styles (requires more custom content). Option 3: SwiftMessages – popular for UIKit banners. Pros: highly customizable banners; Cons: not SwiftUI-native (would need a bridging wrapper). Decision: AlertToast is chosen for its ease of use and rich feature set: we can present non-blocking popups in SwiftUI with one modifier and it offers built-in “complete” (checkmark) and “error” animations for success/failure feedback
elai950.github.io
. This covers our toast and banner needs (e.g., “Profile updated” message or network error warning) with minimal code. It’s well-maintained (4 years, 40 releases
swiftpackageindex.com
) and performance overhead is negligible (just a transient view).

Skeleton Loading Shimmers: Option 1: markiv/SwiftUI-Shimmer – a very lightweight modifier for shimmering skeletons (MIT, ~1.5k stars)
github.com
. Pros: Super small (23 commits) but effective; works on all Apple platforms and handles light/dark and RTL by default
github.com
github.com
. It piggybacks on SwiftUI’s .redacted(reason: .placeholder) for shapes and then animates a gradient shimmer effect
github.com
. Option 2: CSolanaM/SkeletonUI – a more feature-rich skeleton framework (MIT, ~947 stars) that provides declarative placeholders for lists and views
github.com
github.com
. Pros: easy .skeleton(with: isLoading) syntax, can auto-generate multiple placeholder rows
github.com
; Cons: last update ~9 months ago, requires adding another dependency (and it internally uses Combine). Option 3: Rely on SwiftUI .redacted + custom animation manually. Pros: no dependency; Cons: more manual work to implement a shimmering overlay. Decision: We will use SwiftUI-Shimmer in combination with SwiftUI’s built-in redaction. It’s minimal and actively kept up (v1.5.1 in Aug 2024
github.com
github.com
) and supports our needs (e.g. skeleton cards in Orders List) with one line .shimmering() modifier
github.com
. SkeletonUI was considered, but given our relatively simple skeletons (mostly text and rectangular blocks), the lighter Shimmer approach is sufficient and adds near-zero maintainability burden
github.com
.

Micro-animations (Lottie): Option 1: Airbnb Lottie 4.5.2 – the standard for vector animations. Pros: cross-platform, 26k stars, now with official SwiftUI support as of v4.3 (introduced LottieView for declarative use)
github.com
github.com
. We can load a JSON .lottie file and control it with modifiers like .looping() or .playbackMode() in SwiftUI
github.com
. License is Apache 2.0 (permissive). Cons: adding ~8–10 MB to app (includes an XCFramework)
github.com
. Option 2: Rive – an alternative animation platform with a Swift runtime. Pros: interactive animations; Cons: requires using Rive’s design tool and additional learning, and the SwiftUI integration is less mature. Option 3: Rely on SwiftUI built-in animations for small effects. Pros: no dependency; Cons: not suitable for complex illustrations (like a fancy success checkmark animation). Decision: We choose Lottie via SPM (using Airbnb’s optimized SPM package)
github.com
. Lottie’s ubiquity and the new SwiftUI LottieView component (no more UIViewRepresentable needed) make it a robust choice. For example, we can easily play a fun animated checkmark when an order is delivered to delight users. The library is actively updated (v4.5 in 2025) and widely used, which mitigates risk. Rive is powerful but outside our team’s current asset pipeline. Small SwiftUI animations (e.g. button tap scales) will complement Lottie but not replace it.

Image Loading & Caching: Option 1: Kingfisher – well-known Swift image caching library (MIT, ~24k stars, 10+ years dev)
swiftpackageindex.com
. Pros: Supports SwiftUI via KFImage for async loading, with disk/memory cache, progressive loading, and configurable downsampling. Very actively maintained (v8.6.0 released Oct 2025
swiftpackageindex.com
) with no extra dependencies
swiftpackageindex.com
. Option 2: Nuke (+ NukeUI) – modern, async/await friendly (MIT, ~8.4k stars)
swiftpackageindex.com
. Pros: lightweight and uses Swift concurrency; NukeUI’s LazyImage offers a SwiftUI view. Cons: NukeUI was archived in 2022, though core Nuke is still updated. Option 3: SDWebImageSwiftUI – another UIKit-based option with a SwiftUI wrapper. Cons: heavier and slightly less idiomatic in SwiftUI. Decision: Kingfisher is selected for its reliability and integration simplicity. We’ll use KFImage(url) in our views for loading courier avatars or merchant logos. It handles caching transparently and even has SwiftUI-specific improvements (e.g. native transition support for KFImage)
swiftpackageindex.com
. Kingfisher’s performance and thread-safety are battle-tested, and it supports our deployment (iOS16+, Swift 5.9). The MIT license and recent support for SwiftUI transitions
swiftpackageindex.com
 align well with our needs. Nuke is a close alternative; we stick with Kingfisher due to its recent updates and larger community support.

Other UI Helpers (Typography, Segmented control, Chips): Rather than adding libraries for these, we will leverage SwiftUI’s capabilities and our design system. Apple’s built-in segmented control (via Picker with .segmented style) will be customized using our color tokens (tint color). For tags/chips and badges, we’ll create small custom views (capsule backgrounds with text) using our token styling – these are straightforward to implement in SwiftUI. Typography scaling will use SwiftUI’s dynamic type and custom Font extension (no separate kit needed). Our Design System will define text styles (e.g. largeTitle, body, caption equivalents) and we will map them to Font modifiers so that Dynamic Type is supported out of the box.

Design System Integration Pattern: The design tokens (colors, spacing, etc.) will be defined in one place (as structs or enums), and SwiftUI views will refer to them (e.g., using AppTheme.Colors.primary for a button background). We will use SwiftUI’s environment when appropriate (for example, setting a global font or accent color if needed), but primarily keep tokens in a centralized struct for easy update. Custom view modifiers and extensions will enforce consistency (e.g. a .primaryButtonStyle() that applies common styling). Third-party libraries are introduced as SwiftPM packages and used via SwiftUI modifiers or wrapper views; our UI Components will encapsulate these so that screens don’t directly depend on library calls. For instance, we might wrap the AlertToast call in a ToastView component or a ViewModifier for clarity. We minimize UIKit bridges – the chosen libraries are either pure SwiftUI or provide SwiftUI adapters (Lottie’s LottieView, Kingfisher’s KFImage). This ensures the architecture remains SwiftUI-first. Each screen ViewModel will continue to supply data; the Views are now just more decoupled by using design system components instead of ad-hoc SwiftUI code.

4. Affected Modules/Components

New Components to Create:

Design System Tokens – Define collections for ColorPalette, Typography, Spacing, Radii, Elevation (shadows), etc. e.g. a struct AppTheme.Colors with static constants for primary/secondary colors (light and dark variants). This provides a single source of truth for all styling values.

Design System Components – Implement reusable SwiftUI views/styles:

PrimaryButton (and Secondary/Tonal variants): A stylized Button that applies our primary color, font, corner radius, and a pressed-state animation.

CardView: A container view (maybe a RoundedRectangle background with shadow) to present content like order info. It will use our elevation and corner radius tokens.

StatusBadge: A small capsule view for statuses (New/Active/Done), with background color derived from status (using tokenized colors for success, warning, etc.) and a text label.

BottomActionBar: A view for Order Detail’s persistent action bar (if we use that instead of a sheet) – basically a horizontal container for one or two buttons, styled with a background blur or color.

ToastModifier/ToastView: Possibly an abstraction over AlertToast – e.g., an extension on View to easily show toasts with standard styling (so ViewModels can trigger a toast via a binding).

SkeletonPlaceholder: A view representing a loading placeholder (could be an extension that applies .redacted and .shimmering() to any view, and perhaps pre-built row placeholders). For example, an OrderRowSkeleton view that mimics an order card with gray bars.

EmptyStateView: A standardized view for empty lists/states, with an icon (SF Symbol) and text, using our typography and colors (this wasn’t explicitly listed but is a common component to include for UX improvements).

SegmentedControlStyle: If needed, a custom SegmentedPickerStyle or simply configuration of SwiftUI’s Picker with our colors (since SwiftUI doesn’t allow deep styling of UISegmentedControl directly, we might set .tint(AppTheme.Colors.primary) for accent). Alternatively, implement a custom segmented control with toggles if design demands something fancy.

LanguageToggle: A small component (perhaps a menu or segmented control) for language switching, ensuring proper display of language codes and possibly using the Popovers library for the selection menu.

These components encapsulate the new UI behaviors (e.g., PrimaryButton will handle its own hover/press effect and trigger haptics if needed, ToastModifier will hold the AlertToast logic). They improve maintainability by centralizing style logic.

Existing Views to Refactor:

Auth Screen View: Update to use new components – e.g., replace the old login button with PrimaryButton, use a new text field style (if we wrap TextField in a styled container), add a title using design system fonts. Insert any micro-animation (perhaps a subtle logo fade-in or a Lottie animation at the top). Also reposition the language picker (maybe incorporate it into this screen’s UI in a more visually appealing way, e.g., as a menu icon).

Orders List View: Refactor each list row to use CardView with consistent padding and our typography. Embed status text in a StatusBadge. Use SkeletonPlaceholder for loading state (e.g., show 3–5 skeleton cards while data is fetching). Replace the segmented control with either a styled Picker or possibly a TabView if we decide on a tabbed interface – whichever provides a more modern UX. Ensure pull-to-refresh uses our accent color (UIKit’s UIRefreshControl can be tinted via appearance or we use SwiftUI .refreshable).

Order Detail View: Redesign using maybe a scrollable VStack of information sections, each could be in a CardView if appropriate (e.g., address info card, items list card). Implement a sticky bottom section: either a BottomSheet (if more complex actions/confirmation needed) or a simpler BottomActionBar with the primary action (Claim/Picked Up/Delivered). Use our PrimaryButton on that bar. Integrate state-based enabling/disabling (the button style will visually indicate disabled state via tokens, e.g., lowered opacity and no haptic). Trigger a toast on successful action (e.g., “Order marked as Delivered”) and a haptic. Possibly play a Lottie animation (confetti or checkmark) on success as a micro-interaction.

Profile View: Apply consistent styling – e.g., screen background, section headers if any, and use design tokens for spacing around elements. The logout button becomes a PrimaryButton or a SecondaryButton (if we want a less emphasized style for logout to avoid accidents). The “demo mode” toggle can be styled within a card or clearly separated section. Use an alert dialog (SwiftUI .alert) or a popover confirmation for logout. Also incorporate a better language/RTL toggle UI if it lives here (e.g., a list row that triggers a Popover with language options, instead of a plain picker).

Configuration to Add/Adjust:

Global Theme Settings: We will update the app’s App struct or SceneDelegate to apply a global tint if needed (e.g., UIColor.appearance().tintColor for some UIKit components to match our primary color, though most will be directly styled in SwiftUI). If using any Info.plist keys for new libraries (none expected for these UI libs), add those (e.g., if Lottie or image caching required specific config, but likely not).

Asset Catalog: Add color assets for our palette (with light/dark variants) named appropriately so they can be used via SwiftUI Color("Name"). These underpin our Color tokens. For example, “PrimaryColor” asset for brand blue, “PrimaryColorDark” for dark mode if distinct.

Localization: Ensure new user-facing strings (toast messages, button titles if changed, etc.) are added to Localizable.strings for each supported language (HE, AR, EN, RU).

Haptics & Motion Settings: Possibly introduce a utility for haptics (e.g., a small HapticFeedback class that can be called from view models or views). No external config needed, but we might enable the UIImpactFeedbackGenerator.FeedbackStyle usage in key places. If any animations should respect “Reduce Motion” accessibility, use SwiftUI’s .accessibilityReduceMotion environment to conditionalize them (Lottie 4.3+ supports reduced motion by pausing animations if the user has that setting
github.com
github.com
).

Testing Flags: If we implement a feature flag for the new UI (to allow rollback), we might use a Launch Argument or UserDefault (e.g., AppStorage("useNewUI")) – defaulting true – to wrap our new UI components. That way, turning the flag off could revert to old UI (if we temporarily keep old views for safety). This would be a short-term configuration for rollout only.

5. Implementation Steps

Add SPM Dependencies: Integrate the chosen libraries via Swift Package Manager. In the project’s SwiftPM settings (or Package.swift), add packages with minimal required versions:

.package(url: "https://github.com/lucaszischka/BottomSheet", from: "3.1.1"),
.package(url: "https://github.com/aheze/Popovers.git", from: "1.0.4"),
.package(url: "https://github.com/elai950/AlertToast.git", from: "1.3.9"),
.package(url: "https://github.com/markiv/SwiftUI-Shimmer.git", from: "1.5.1"),
.package(url: "https://github.com/airbnb/lottie-spm.git", from: "4.5.2"),
.package(url: "https://github.com/onevcat/Kingfisher.git", from: "8.6.0"),


After adding, import the relevant modules in code (e.g., import BottomSheet, import Popovers, import AlertToast, import Shimmer, import Lottie, import Kingfisher) where needed. Verify the packages fetched and built successfully. Setup notes: No special Info.plist entries are required for these libraries. (Kingfisher and Lottie handle disk writes internally without extra permissions; Lottie’s data is bundled in-app; our use of biometrics/Keychain is unchanged by UI changes.)

Define Design Tokens: Create a new SwiftUI file (e.g., DesignSystem.swift) containing structs/enums for tokens:

Color Tokens: Define a Color palette struct mapping semantic names to Color. For example, AppTheme.Colors.primary = Color("PrimaryColor") (with "PrimaryColor" defined in Assets for light/dark) and similar for secondary, background, surface, error, success, etc. Include “on” colors for contrast (e.g., onPrimary for text on primary background).

Typography: Define font styles that wrap SwiftUI Font with our chosen font family and sizes. E.g., AppTheme.Typography.h1 = Font.system(size: 34, weight: .bold, design: .default) (or use .largeTitle if sticking to system text styles). Provide a range (perhaps based on Apple’s Text Styles) from large titles down to caption, customizing as needed. Ensure to enable Dynamic Type scaling by using .preferredFont when possible or .font(.title) etc., and set .dynamicTypeSize(..., ...) if needed to test.

Spacing & Layout: Define constants for spacing increments (e.g., 4, 8, 16, 24 points for XS, S, M, L, etc.). Also define standard corner radii (e.g., 8 or 12 pts for small components, maybe 20 for cards). If needed, define an elevation scale – could be simple shadows: e.g., level1 = Shadow with radius 2, level2 = radius 4, etc., or use SwiftUI .shadow modifiers in components directly.

Timing & Easing: If the design calls for consistent animation curves, define something like AppTheme.Timing.fast = 0.2 (200ms) and .curve = Animation.easeOut(duration: 0.3) etc. Also, prepare a simple haptic trigger mapping, e.g., HapticFeedback.selection = UISelectionFeedbackGenerator() or a function like AppTheme.Haptics.play(.success) that wraps UINotificationFeedbackGenerator for success, warning, error types.

Document these tokens for developers. This step is verified by checking that tokens map correctly to actual UI (e.g., preview a color in light/dark to confirm asset linkage).

Implement Base Components: Develop the reusable UI components using the tokens:

Buttons: Create PrimaryButton as a View that internally uses a SwiftUI Button. Apply styles: use AppTheme.Colors.primary as background, AppTheme.Colors.onPrimary for foreground text, padding from AppTheme.Spacing, corner radius from tokens, and perhaps a slight shadow if called for. Do similarly for SecondaryButton (maybe outlined or different color) and any tonal/tertiary button if needed. Use .font(AppTheme.Typography.button) for the label. Also add an .disabled state handling: e.g., if disabled, use a muted background color token or reduce opacity, and disable the button’s interaction. Each button can be a separate view or a style via ViewModifier; we choose view for clarity (with a custom initializer). Include accessibility labels (the text itself usually suffices) and maybe .accessibilityAddTraits(.isButton).

CardView: Implement a container view (could be a ViewModifier as well). For simplicity, define a CardView that wraps content in a RoundedRectangle(cornerRadius: AppTheme.Radius.m) filled with AppTheme.Colors.surface (background) and applies .shadow(color: .black.opacity(0.1), radius: 4) or use the elevation token. Use this for order cells and possibly profile sections. This ensures consistent card styling.

Badges: Create a StatusBadge view that takes a status enum/value and displays a Capsule with a colored background and a label. For example, New = blue background, Active = orange, Done = green, defined in color tokens. Use a small font from Typography (caption). This badge should enforce minimum size for accessibility (padding around text). Test that it flips horizontally correctly in RTL (likely fine since it’s just text inside).

Segmented Control Replacement (if needed): If the default Picker with .segmented style is too limiting for design, implement a custom control: possibly an HStack of buttons for each segment with a background capsule for the selected one. This could be complex, so prefer using the system control but adjust its tint: set .accentColor(AppTheme.Colors.primary) on the Picker to recolor the selected segment indicator. We will verify it meets design (e.g., on iOS 16 the segmented control inherits tint). If more customization needed (like different shape or multi-line segment labels), then implement from scratch.

Toast Presenter: We may not need a custom view for toasts since AlertToast provides a modifier. But for convenience, implement an extension View.showToast(...) or simply use the library’s .toast(isPresenting:binding) { AlertToast(...) } in screens. We’ll standardize the style of toasts: e.g., success uses .complete with our brand color, error uses .error with red, etc., so it’s consistent. Possibly wrap these in functions like Toast.success("Order delivered") that returns an AlertToast configured with icon and color.

Skeleton Placeholder Views: Using the Shimmer library, we don’t need a full new component for skeleton, but we can create placeholders matching each major view. For instance, OrderRowSkeleton: a View with fixed height and using RoundedRectangle and Rectangle shapes with .redacted(reason:.placeholder) to mimic an order card (gray bars for text lines). Then apply .shimmering() on the entire view. Similarly, maybe an AuthFormSkeleton if needed (though auth is fast). The key is to easily toggle between skeleton and real content via a state boolean. We’ll add convenience: e.g., an extension View.skeletonify(if: isLoading) that either applies redacted+shimmer to self or hides self in favor of a given placeholder view. This step is done when at least the Orders List uses skeletons on pull-to-refresh or initial load.

EmptyStateView: (If in scope) Create a view with an SF Symbol (configurable) and a text message, styled with neutral color and padding. Use it in places like OrdersList when a section has no orders (“No active orders”). Not explicitly required, but it’s a UX improvement we can include if time allows.

Integrate Third-Party Components in UI Layer: For each library, create small adapters if necessary:

BottomSheet: Import BottomSheet library and test a simple sheet in a preview. Likely, we will use the provided .bottomSheet() view modifier directly on a top-level container (e.g., on OrderDetail view). We don’t need a wrapper since it attaches via modifier to any View. Implement the sheet content (e.g. a view listing action buttons or confirmation). Ensure to manage the @State var bottomSheetPosition: BottomSheetPosition in the view. Decide where to use: possibly when tapping “Mark Delivered” we set sheetPosition = .top to show a confirmation sheet (“Slide to confirm delivered” or additional info) – but if not needed, we might not use the sheet and instead rely on a simple action bar. Another use: maybe in Auth for a role picker (if that was on a separate screen, but it might be on Auth screen as a picker already). We’ll implement at least one BottomSheet usage to justify including it – for example, turning the Order Detail action area into a draggable panel containing action buttons. This step is done when the bottom sheet appears and transitions smoothly on user interaction; verify it doesn’t conflict with navigation (may require attaching .bottomSheet at NavigationView level per library docs).

Popovers: Use the .popover(present:attributes:view:) modifier from Popovers library for a context where needed. For example, implement a help tooltip on the Auth screen’s demo mode switch (when tapped, show a small popover explaining demo mode). Or use it for the language selector: have a “Language” button that, when tapped, triggers a Popover menu listing languages. Configure Popover attributes if needed (e.g., arrow position, etc., likely using defaults is fine). Ensure on iPad the popover doesn’t appear off-screen (the library handles source frames, we just attach to the view). We might create a small ViewModel binding for showing a certain popover. Test on both phone and iPad simulators.

AlertToast: Globally, ensure import AlertToast in necessary views. Then for events like successful order update, set a state var showToast = true and use .toast(isPresenting:$showToast, alert: { AlertToast(...) }) on the view. Do this for at least: after claiming an order, after marking picked-up/delivered, after toggling demo mode or logout (for feedback). Possibly also for error messages (e.g., if network fails, show a toast “Failed to update, please retry”). We standardize durations (default 2s) and allow tap to dismiss. This step is verified by running the app and triggering these actions – a transient toast should appear with correct style (check mark or X icon) and disappear automatically.

Shimmer (Skeleton): Integrate by applying .shimmering() to our skeleton views. For example, in OrdersListView, do: if viewModel.isLoading { OrderRowSkeleton().shimmering() } else { actual list }. The Shimmer package requires import Shimmer and then using either the modifier or .modifier(Shimmer()) – we’ll use the .shimmering() convenience
github.com
. Verify in runtime that the skeleton shimmers (and respects dark mode – the lib by default uses a gradient that works on both backgrounds
github.com
). Also test that when layout direction is RTL, shimmer animates correctly (the lib auto-adjusts for RTL
github.com
).

Lottie Animations: Add at least one Lottie animation file (JSON or .lottie) to the project (e.g., a checkmark or fun graphic for success). Use LottieView(animation: .named("YourAnimation")) in a relevant place. For instance, on the Auth screen, after successful login, play a quick “success” animation (or perhaps a subtle loop on the login button icon). Or on OrderDetail, when the final delivery is done, overlay a checkmark animation. Using Lottie 4.3’s SwiftUI API, we can do .looping() or .playing as needed
github.com
. For first integration, perhaps put a LottieView in the background of Auth (like an animating logo) or as a decorative element on an empty state. Ensure to call LottieView(animation:.named("X")).playbackMode(.pause) etc., as per usage. Verify the animation plays as expected. (If including Lottie, also ensure to handle reduceMotion – the new version respects it automatically by halting animations
github.com
, which is good for accessibility.)

Refactor Auth Screen: Implement the new design:

Replace any old Button for “Login” with PrimaryButton("Login") { ... }. Use the PrimaryButton component to get the consistent style (big, filled, corners rounded). Position it prominently.

Style the text fields: use SwiftUI’s .textFieldStyle if a suitable one (rounded border) is okay, or create a custom UnderlinedTextField style. For instance, we can wrap each TextField in a RoundedRectangle border with padding and background color from tokens. Use .font(AppTheme.Typography.body) on inputs for better text appearance. Also add an SF Symbol in the text field if desired (like a phone icon in the phone field) – SwiftUI allows prefix icons inside TextField via overlay or using Label. Ensure the placeholder and text have good contrast (especially in dark mode).

Add a title/subtitle text at the top: e.g., a Text("Welcome") with .font(AppTheme.Typography.h1) and maybe a smaller subtitle Text("Sign in or register") with .font(.subheadline) to set a friendly tone (matching modern app trends). These should use our color tokens (e.g., primary or on background color). Possibly animate their appearance: e.g., a slight slide or fade on view appear to enhance delight.

The role picker (if present on this screen) could be improved by using a Picker with segmented style or a better UI (maybe each role as a card to select). However, given MVP scope, a simple segmented control or menu is fine. Use our color for the selected segment.

Place the language switcher control: Instead of a raw toggle for RTL, provide a globe icon or “EN” label that opens a Popover menu of languages. Possibly put this at top-right of the screen. It will demonstrate the use of Popovers library. Confirm that selecting a language triggers whatever mechanism the app uses (likely updates localization and flips direction).

Ensure safe-area usage: the content should not be obscured by notch or home indicator – likely by using padding(.horizontal) and perhaps .padding(.bottom) for the bottom content if needed. The language popover should also be safe-area aware (the library handles positioning in window coords).

Add inline error states for invalid input (if the app has those): e.g., if login fails, show an AlertToast with .error type or simply highlight the text field border in red and show a Text underneath. Use color token for error (which should meet contrast on light/dark).

This step is complete when the Auth screen visually matches a modern login: properly spaced, with a clear primary CTA, and tested in both LTR and RTL (e.g., Hebrew: ensure the layout flips and the text alignment of input placeholders follows locale). Also test with larger font settings (Dynamic Type) – the design should not break (ScrollView might be needed if content gets large).

Refactor Orders List Screen: Update the list and surrounding UI:

Implement the segmented control at the top using either SwiftUI’s Picker. For example:

Picker("Status Filter", selection: $viewModel.selectedSegment) {
    Text("New").tag(OrderStatusFilter.new)
    Text("Active").tag(OrderStatusFilter.active)
    Text("Done").tag(OrderStatusFilter.done)
}
.pickerStyle(.segmented)
.padding(.horizontal, AppTheme.Spacing.m)
.tint(AppTheme.Colors.primary)


This will give us a modern segment control tinted with our brand color. (If design requires a different look, we might create a custom control with buttons, but likely this suffices.) Make sure the text fits even when localized (e.g., “פעיל” for Active in Hebrew might be longer – the segmented control should scroll or the words can be slightly abbreviated if necessary).

Each order row: Use our CardView as the container. For example:

CardView {
    VStack(alignment: .leading) {
        HStack {
            Text(order.id).font(AppTheme.Typography.bodyBold)
            StatusBadge(status: order.status)
        }
        Text(order.summary).font(AppTheme.Typography.body)
        Text(order.time).font(AppTheme.Typography.caption).foregroundColor(AppTheme.Colors.textSecondary)
    }
    .padding(AppTheme.Spacing.m)
}
.onTapGesture { viewModel.selectedOrder = order }


The CardView will provide consistent styling (rounded corners, shadow). The StatusBadge will be colored, giving immediate visual status. The textual hierarchy (maybe order ID or customer name in bold, details regular, timestamp in secondary color) improves scan-ability. Use spacing tokens for padding/margins rather than magic numbers. Ensure this looks good in dark mode (the CardView background might use system background or a slightly elevated color).

Loading state: when viewModel.isLoading (on first open or during pull-to-refresh), show skeleton rows. For instance:

if viewModel.isLoading {
    ForEach(0..<3) { _ in 
        OrderRowSkeleton() 
            .padding(.horizontal, AppTheme.Spacing.m)
            .padding(.vertical, AppTheme.Spacing.s)
    }
} else {
    // Normal list ForEach orders
}


The OrderRowSkeleton can be a rectangle with smaller gray rectangles inside to mimic text lines, all with .redacted. After data loads, these are replaced by real content. Test that during a pull-to-refresh (drag list down), we show either the iOS spinner or maybe immediately show skeletons while new data fetch occurs. The combination of skeleton + pull-to-refresh spinner is okay; if redundant, we might just rely on skeleton for initial load and use default refresh indicator for user-initiated refresh.

Pull-to-Refresh visuals: Since iOS16 allows .refreshable { await viewModel.reload() }, we use that on the List or ScrollView. By default, it shows a spinner. If design wants a custom look (not critical), we could possibly replace it with a custom ProgressView styled with our color. But likely just ensure the spinner tint is our primary color (which it should follow accentColor). Verify by triggering refresh that the UI stays responsive and uses our tokens where possible (accentColor).

Infinite scroll (if applicable, not mentioned) – not needed in MVP, presumably list is finite.

Performance: Use LazyVStack inside a ScrollView if not using List, for smoother scrolling with many orders. Our card and images (if any) should be optimized (with Kingfisher, images are cached and will appear quickly; also consider using .resizable().aspectRatio on images with a placeholder). Make sure that using KFImage for any order thumbnails is done with an appropriate resizing processor to avoid loading huge images into memory
swiftpackageindex.com
.

Verify OrdersList: scroll it on device/Simulator to ensure 60fps (the card shadows and images should not cause lag – if they do, consider reducing shadow radius or using .shadow(color, radius, y-offset) with small values). Also test that tapping an order triggers navigation to detail (if the app does so) with no layout jank – the card should highlight if needed (we can add .contentShape(Rectangle()) to make entire card tappable). In RTL, confirm the HStack with text and StatusBadge order flips (it will, by default alignment leading will flip).

Test large text (Dynamic Type XL): The card might expand vertically, which is fine as long as it doesn’t overlap. We might need to set .minimumScaleFactor on certain Text if space is tight (though better to allow multi-line or truncation on order summary if needed).

Refactor Order Detail Screen: Apply a structured layout and interactive improvements:

Arrange content in sections: Perhaps use a ScrollView or List if the content is long. For example, a section “Order Info” (items, price, etc.), “Customer Info” (name, phone), etc. Each section can be inside a CardView to separate visually. Use our Typography for section headers (or simply rely on spacing and maybe a bold label). Possibly include SF Symbols (e.g., a pin icon for address) next to text to add visual cues. Ensure that any important text has sufficient contrast and size (Dynamic Type friendly).

Implement the sticky action area: Two approaches:
Option A: BottomActionBar – a view anchored to bottom (using .ignoresSafeArea(edges:.bottom) on content and a VStack with the bar, or simply a .toolbar in SwiftUI with .bottomBar placement). The bar would contain one main button whose title and state depend on order status (“Claim” if New, “Picked Up” if claimed, “Delivered” if on route, etc.). Disable the button (and style it as disabled) if the action is not allowed (e.g., you can’t “Pick Up” before claiming). We bind the disabled state to viewModel logic. When tapped, call viewModel action which updates state and pops a toast on success. This bar should use a background color (perhaps .ultraThinMaterial for a translucent effect or a solid token color) and have sufficient height to avoid the iPhone home indicator (use .padding(.bottom) equal to safeAreaInsets).
Option B: BottomSheet – using the BottomSheet library to present actions. For example, show a small sheet that pops up when the user presses an action button like “Change Status” – within the sheet there could be a VStack of buttons “Mark as Picked Up”, “Mark as Delivered” (only the valid next actions enabled). This is more complex but offers a guided flow (like Uber’s trip sheet). If implementing, ensure the BottomSheet’s switchablePositions include .bottom (hidden) and .middle (half) for example, and maybe .top if full view. The user can drag it for more details. We would integrate it such that tapping a floating action button on Order Detail expands the sheet. Given time, we might implement a simpler sticky bar first (Option A), and reserve BottomSheet for a possibly richer interaction later.

Use Haptics: For critical actions, fire a success haptic. For instance, when “Delivered” is tapped and the operation succeeds (we get a 200 from server or we optimistically update), trigger UINotificationFeedbackGenerator().notificationOccurred(.success). On a failure (say network error), trigger .error haptic. Also a softer feedback on intermediate actions (e.g. claiming an order might use a medium impact haptic to acknowledge button press). Integrate these by calling in viewModel or via a .onAppear of toast (since toast indicates completion). We will wrap in a check for user’s accessibility settings (if they disabled haptics, we shouldn’t fire them – iOS typically handles this automatically, but we can check UIFeedbackGenerator().prepare() safely regardless).

Show Toast on action completion: After an action like “Claim” or “Deliver”, set showToast = true with an appropriate AlertToast. For example, after marking delivered, AlertToast(type: .complete(.green), title: "Delivery Completed") (the library’s .complete uses a checkmark animation with given color). This appears at the bottom (banner) or center based on our choice – default is center alert, but we might prefer a non-blocking top/bottom HUD. We can specify .hud displayMode for a banner style
elai950.github.io
. For now, a brief banner at top saying “Order delivered” (which doesn’t block UI) is ideal. Ensure the toast text is localized.

Optimistic UI updates: If we mark delivered, update the UI state immediately (e.g., status badge to “Done”, disable the delivered button) even as the toast shows – this makes the app feel fast. If the server call fails, we can always show an error toast and revert state. But that’s more a ViewModel concern; from the UI side, we ensure state changes reflect promptly (SwiftUI binding will handle that).

Navigation/Back: Ensure the Order Detail screen still has a Back button or some way to close (likely it’s within NavigationView, so default back works). The bottom sheet if used should not conflict with swipe-back gesture; test that.

Test dark mode: The Order Detail cards and bar should adapt (the background might become darker, text lighter – using token colors ensures that if tokens have dark variants).

Test RTL: The layout of info (like address, labels) should flip if we use VStack and HStack appropriately. Might need .frame(maxWidth:.infinity, alignment:.leading) vs .trailing adjustments depending on content. For example, numeric IDs we might want left-aligned even in RTL to avoid confusion, but generally we’ll let the system handle it. Check any icons: SF Symbols often flip automatically if they have directional variants (if not, we might set .flipsForRightToLeftLayoutDirection(true) on them if needed).

By end of this step, the Order Detail should feel modern and intuitive: key actions visible and consistently styled, feedback given for state changes, and no broken flows.

Refactor Profile Screen: Bring this screen in line with the design system:

Likely the Profile is a simple form with logout and some toggles. Wrap content in a ScrollView or VStack with padding. Use CardView if the design calls for grouping (e.g., a card around the demo mode toggle and some label). Or each item can be a List row if currently using a List – we might convert to plain SwiftUI views for flexibility.

Logout: Replace the plain logout button with either a SecondaryButton (if we want it less prominent than primary actions) or still a PrimaryButton if it’s the main call-to-action on that screen. Possibly style it in a warning color if appropriate (but primary color is fine). Attach an action to it that triggers a confirmation dialog. We can use alert(isPresented:) with SwiftUI’s Alert to ask “Are you sure you want to logout?” with Yes/No. Style is system default which is okay (the Alert will follow our global accent color for the default action). Alternatively, use Popovers library to show a custom alert view (but that might be overkill for logout – the standard alert is accessible and familiar).

Demo mode toggle: If it’s a boolean in profile, style it using SwiftUI’s Toggle which automatically gets the new iOS design (round switch). We can put it inside a HStack with a Text label, or use Toggle("Demo Mode", isOn:$demoMode) directly. Use .toggleStyle(SwitchToggleStyle(tint: AppTheme.Colors.primary)) to brand the switch. Ensure the label text uses proper font from Typography. Possibly give this Toggle its own card or section.

Global language/RTL controls: If not handled on Auth screen, they might reside here. For example, a Picker for language selection. Instead of a full picker UI, we can make it a navigation link to a new screen or a Popover menu (similar approach as earlier). It might be acceptable to have a simple Picker in a sheet using NavigationLink("Language", destination: LanguageSelectionView()). But since we have Popovers, we could have a row “Language: [EN]” that on tap presents a Popover with the list of languages and flags. Implement whichever is simpler given time; main goal is to allow user to switch language easily. For RTL toggle, since switching language to an RTL one inherently triggers RTL layout, we might not need a separate RTL boolean (unless the app specifically had a toggle to force RTL for testing). If it does, that can also be a Toggle (perhaps hidden in a debug menu). Regardless, test the profile screen in all languages.

Apply consistent spacing and colors: use AppTheme.Spacing between elements, and background color from tokens for the screen (likely a neutral background). The Profile probably should visually connect to the rest of app (if other screens use a colored nav bar or so, but since it’s SwiftUI, likely plain). We ensure any icons on this screen use SF Symbols (e.g., a logout icon if present, use SFSymbol “arrow.backward.circle.fill” or similar).

After this step, Profile should have the same polished feel: alignment of items, proper use of tokens (no hard-coded colors), and interactive elements (toggles, buttons) in our style. Confirm that VoiceOver reads each element (for Toggle, ensure the label is descriptive beyond just “Demo” – we can set .accessibilityLabel("Demo Mode Toggle") if needed).

Dark Mode, RTL, Accessibility Sweep: Go through each screen with environment overrides: in Xcode previews or simulator, force Dark Mode – ensure color tokens yield appropriate contrast (e.g., PrimaryButton text is still visible on primary background in dark mode, cards use a slightly elevated dark color and not pure white which would be glaring). Adjust token values if needed (perhaps use system background for cards to get the adaptive behavior). Test RTL by setting an RTL language (Hebrew/Arabic) and launching – check that stack alignments and screen transitions are correct (SwiftUI should mirror automatically; ensure any images or icons that shouldn’t mirror are handled – e.g., a logo should perhaps not flip, set .drawingGroup() if needed to avoid symbol mirroring). Test Dynamic Type by increasing font size in Simulator Accessibility settings – all text should scale (if we used system Text Styles or .font with .relativeTo styles, they will; any custom Font(size:) might need a .dynamicTypeSize modifier or use .scaledToFit() on that text). Fix any layout that breaks with larger text (maybe allow text to wrap). Also verify VoiceOver: turn it on and navigate – ensure buttons have meaningful labels (e.g., the Order card might be read as multiple text elements; we can improve by wrapping it in an accessibility element: .accessibilityElement(children: .combine) and give a summary label like “Order #1234, 2 items, Ready for pickup”). Mark purely decorative elements as hidden to VoiceOver (e.g., if we have a decorative image). This accessibility pass is not a single step but an ongoing verification parallel to above steps. It’s considered done when we can confidently pass Apple's accessibility checks (contrast, Dynamic Type, VO focus order) on the updated UI.

Testing & Verification: Build and run the app, going screen by screen to verify new components and flows (detailed test plan in section 8). Fix any issues discovered (for example, if the BottomSheet content isn’t resizing well on smaller devices, adjust the detents or content height). Particularly, test transitions: e.g., login to orders list – any flash of skeleton at wrong time? Fine-tune state handling so skeleton only shows when appropriate. Test that toasts do not accumulate (if user triggers many quickly); the AlertToast mod should handle showing one at a time. Memory check: run a few actions and use memory graph debugger to ensure no major leaks from these new components (the libraries are lightweight, but for example, Lottie animations should be freed after use). After iterating, proceed to final preparations.

If gating the rollout: Implement a feature flag if decided (like an app launch argument or remote config to toggle old/new UI). This could be as simple as an if useNewUI { NewContentView() } else { OldContentView() } at the App entry. Initially “useNewUI” is true. We’ll communicate that this flag exists to stakeholders for rollback plan.

This step is done when the app passes all tests and matches the acceptance criteria visually and behaviorally.

Deployment: Merge the UI overhaul branch into main (assuming tests pass and QA approves). Because this is a significant UI change, we might release it as a new app version and monitor user feedback closely. The final step is enabling any analytics (if in scope) to track usage of new features (not strictly required, but e.g., count how many times toasts appear to gauge certain flows – covered in Observability). Deployment is considered successful when the new UI is live to users and no major issues are reported.

Each step above can be verified through code reviews (ensuring tokens and components are defined and used, libraries added in Package.resolved) and functional testing on device. This incremental plan ensures we integrate libraries one by one (e.g., add all SPM packages first, then gradually use them) to isolate any build/runtime issues.

6. Interfaces & Contracts

Design System API: All new design tokens and components will be accessible through clear, namespaced interfaces. For example, we expose a struct AppTheme with nested structs for tokens:

struct AppTheme {
    struct Colors {
        static let primary = Color("PrimaryColor")       // Light/Dark variants in Assets
        static let background = Color(uiColor: .systemBackground)
        static let card = Color("CardBackground")        // e.g., slightly elevated color
        static let textPrimary = Color("TextPrimary")    // or use .label
        static let textSecondary = Color("TextSecondary")
        static let error = Color.red
        // ... more colors as needed
    }
    struct Spacing {
        static let xs: CGFloat = 4
        static let s: CGFloat  = 8
        static let m: CGFloat  = 16
        static let l: CGFloat  = 24
    }
    struct Radius {
        static let small: CGFloat = 8
        static let medium: CGFloat = 16
        // ...
    }
    struct Typography {
        static let largeTitle = Font.system(size: 34, weight: .bold)
        static let title = Font.system(size: 28, weight: .semibold)
        static let body = Font.system(size: 17, weight: .regular)
        static let bodyBold = Font.system(size: 17, weight: .semibold)
        static let caption = Font.system(size: 13, weight: .regular)
        // (These will automatically scale with Dynamic Type if standard text styles are used or using .system with .default design)
    }
}


Components will use these, e.g., PrimaryButton will refer to AppTheme.Colors.primary etc., rather than hardcoding values. This makes adjusting the look (color palette or corner radius) a one-stop change in AppTheme. The AppTheme struct itself is internal to the UI module but can be made public if needed (for use in other modules or previews).

Component Interfaces: Public structs for each reusable component with intuitive initializers. For instance:

struct PrimaryButton: View { init(_ title: String, action: @escaping () -> Void) { ... } } – encapsulates a styled Button. Usage: PrimaryButton("Confirm", action: submitOrder). Internally it applies a custom label view (Text with our font and color, padded and background). Similarly, SecondaryButton could accept title and perhaps an icon name.

struct StatusBadge: View { init(status: OrderStatus) { ... } } – it will map the status to a color and label text. E.g., if status == .active, background = AppTheme.Colors.warning (orange), label = "Active". This component may be used as StatusBadge(status: order.status).

struct CardView<Content: View>: View { init(@ViewBuilder content: ()->Content) { ... } } – wraps content in a rounded rectangle. Alternatively, we might do a ViewModifier cardStyle() so we can do VStack { ... }.modifier(CardStyle()). Either way, from calling code, it should be simple: e.g., CardView { OrderDetailsContent(order: order) }.

No changes to existing model interfaces or network contracts. The ViewModels might get minor additions (e.g., a published toastMessage or state for showing toast), but no changes to the data they send/receive.

If needed, define a protocol for any view that supports theming so we can apply theme changes globally (but since we rely on static tokens, that’s already global).

Toast & Alerts Contract: We standardize toast usage through a small utility. For example, define an enum ToastType { case success, error } and a function func presentToast(_ type: ToastType, message: String) that sets a binding in the App or environment. However, simpler: use AlertToast directly in each view. The contract is that any user feedback that doesn’t require acknowledgment will use the toast (instead of Alert). For instance, after a network error, we do not show a blocking alert; we show a non-blocking banner. The style of these is consistent – success uses the checkmark animation with green (from AlertToast’s .complete type), errors use red X (.error type)
elai950.github.io
, and general info can use .regular or .systemImage with an icon. All toasts automatically dismiss after a couple of seconds.

Developer usage example: In an async action, upon completion, they set showSuccessToast = true and the view has .toast(isPresenting: $showSuccessToast) { AlertToast(type: .complete(AppTheme.Colors.primary), title: "Done!") }. This is straightforward as seen in library usage
elai950.github.io
.

Localization & Text: All text in UI components will be localizable. For any new strings (“Order delivered”, “Network error, try again”), add keys in the Localizable.strings. In code use NSLocalizedString("OrderDeliveredMessage", comment: "") or SwiftUI’s localized string approach. We’ll ensure default English and provide translations for HE, AR, RU as available. The design system might contain no localized text except maybe common words if needed (like “OK”). But we prefer to handle at feature level. For instance, PrimaryButton("Logout") will actually use Text(NSLocalizedString("Logout", comment:"")).

Right-to-Left: There’s no separate contract needed; by using SwiftUI’s native layout and not forcing alignments, our UI should automatically support RTL. We verify that numeric fields or icons are correctly positioned. If needed, use Environment(\.layoutDirection) to adjust anything manually, but likely not required.

Iconography: We will use SF Symbols for consistency. For any icons (e.g., a mail icon in email field, a logout icon, etc.), use the SF Symbol name through SwiftUI Image(systemName:). Our design system can include an enum of symbols if we want (to avoid stringly-typed names). For example, enum Icons { static let logout = Image(systemName: "rectangle.portrait.and.arrow.forward") }. Ensure to choose symbols that have a consistent weight/style (preferably use the .font modifier to set the weight to match text). By using SF Symbols, we get auto mirroring for RTL for directional symbols. If an icon should not mirror (like a logo or a specific brand image), we mark it with .environment(\.layoutDirection, .leftToRight) or use .flipsForRightToLeftLayoutDirection(false). All icons will have accessible labels (set via .accessibilityLabel("Logout") for instance, unless accompanied by text).

Backward Compatibility: The new UI components replace old SwiftUI code but remain compatible with existing ViewModels. For example, if previously OrdersListView was binding to a ViewModel array of orders, it still does – we’re just changing how each order is displayed. The ViewModel’s published properties (like orders, isLoading, etc.) stay the same, so no changes needed in networking or data parsing. We do ensure any state introduced for new interactions is handled in VM: e.g., if we add a showDeliveredToast state, that can be a @Published in VM or simply a @State in the View – either is fine, likely @State in the View because it’s purely UI. So no existing contract is broken – a consumer of the ViewModel (like unit tests or any other part) sees the same data.

If for some reason we had to change a ViewModel (not anticipated), we’d ensure it remains source-compatible (e.g., adding a new property, not removing old ones). But primarily, this is a drop-in UI replacement.

The code structure (MVVM) remains: Views observe ViewModels. We just inject our design system components in the Views.

Migration for developers: Document the usage of new components – e.g., “Use PrimaryButton instead of a custom Button style in all new code.” Refactor any stray UI in other parts (for example, if there were any SwiftUI views for modals or alerts elsewhere, adapt them to tokens for consistency).

Example Usage of New Interfaces: A snippet demonstrating how a screen might tie these together:

import SwiftUI
import AlertToast

struct OrderRowView: View {
    let order: Order
    var body: some View {
        CardView {
            HStack {
                VStack(alignment: .leading) {
                    Text(order.customerName).font(AppTheme.Typography.bodyBold)
                    Text(order.address).font(AppTheme.Typography.body)
                }
                Spacer()
                StatusBadge(status: order.status)
            }
            .padding(AppTheme.Spacing.m)
        }
        .onTapGesture { /* navigate to detail */ }
    }
}

struct OrderDetailView: View {
    @State private var showDeliveredToast = false
    var body: some View {
        VStack {
            /* ... order info ... */
            PrimaryButton("Mark as Delivered") {
                viewModel.markDelivered()
                showDeliveredToast = true
            }
            .disabled(!viewModel.canMarkDelivered)
            .padding()
        }
        .toast(isPresenting: $showDeliveredToast) {
            AlertToast(type: .complete(AppTheme.Colors.primary), // checkmark in primary color
                       title: NSLocalizedString("OrderDeliveredMessage", comment: ""))
        }
    }
}


In this example, PrimaryButton and StatusBadge come from our UI Components, and the toast uses our color token. This illustrates a typical usage contract: the Views remain declarative and simply assemble tokens and components.

 

Overall, the interfaces are designed to be intuitive and require minimal knowledge of the underlying libraries (e.g., developers use .toast modifier without worrying about how AlertToast is implemented beyond providing an AlertToast object). By encapsulating styles, we ensure consistency and ease future changes (like re-theming the app could be done by adjusting AppTheme values, with all components automatically updating their look).

7. Data Model & Migration (if relevant)

Data Model Changes: None. The UI overhaul does not require any additions or modifications to persistent models or the network data format. All changes are in how data is presented. The existing models for orders, user profile, etc., remain the same. For example, Order model still has status, customer name, etc., which we now display with new UI elements but we do not add fields to Order. There are no schema changes for local storage (we continue using SwiftData/Keychain as is). We are deliberately not introducing new data types, so no migration is needed for the local database.

User Preferences: We do ensure that any existing preferences, such as selected language or theme, continue to work. If currently language selection is stored (perhaps in UserDefaults), we will keep using that. For instance, if the app sets Bundle.main.preferredLocalizations or similar based on a saved language code, we’ll tie our language picker to update that same UserDefaults key. No new preference keys are introduced aside from possibly a feature flag for the UI (for testing rollout), which would be temporary. If we did add a UI toggle for dark mode (unlikely, we’ll use system dark mode), that might be a new preference – but as of now, dark mode will just follow system setting, which is default and doesn’t need storing.

Theming Preferences: As an enhancement, we could allow user to choose light/dark mode override. If we do, it’s as simple as setting an @AppStorage("appearanceMode") value (Light/Dark/System) and using .preferredColorScheme() in the SwiftUI views accordingly. This would be a new setting, but optional. Regardless, implementing it wouldn’t conflict with any existing data – it’s an isolated addition.

Backward Compatibility of Preferences: All existing app settings (demo mode flag, etc.) are still respected. We are not renaming or removing any keys in UserDefaults. E.g., if demoMode was stored, our new toggle will read/write the same key. No migration or default changes needed.

Language & RTL Handling: The global language switch likely sets an app-level locale. We will use the same mechanism that existed (or if not, implement by restarting the app or updating Locale.current via environment in SwiftUI as a new technique). If previously manual RTL toggle was separate, we might simplify by just using language selection to determine RTL. But we won’t remove the ability if it was provided explicitly; we’ll just integrate it better in UI.

In summary, no data migration is required. The focus is purely on the UI layer. Any minor addition (like a new default for appearance) can be handled with AppStorage and a sensible fallback (system default). The transition for users is seamless – when they update the app, they will see the new UI reflecting the same data (orders, profile info) as before.

8. Testing & Validation

We will conduct a thorough testing strategy covering unit tests, UI tests, and accessibility/performance validations:

Unit Tests (Design System & Components):

Token Values Tests: Write unit tests to ensure that color tokens are correctly defined (e.g., AppTheme.Colors.primary matches expected hex in light and dark mode). We can instantiate a Color and compare to a known UIColor if needed. Similarly, test that typography tokens have the intended font traits (size, weight). These tests guard against accidental token changes.

Component Rendering Tests: Using SwiftUI’s UIViewRepresentable snapshot or SwiftUI preview snapshots, verify components layout. For example, snapshot PrimaryButton in enabled and disabled states and compare against reference images (using a library like SnapshotTesting, if permitted, to catch visual regressions). Or at least verify via unit test that PrimaryButton’s label uses the correct foreground color when disabled (we can expose an internal property for testing or use SwiftUI Inspection).

Logic Tests: If any components have logic (e.g., a custom segmented control that computes index selection or a ToastManager that queues messages), test those classes. For example, if we implement a function to provide the appropriate AlertToast given a ToastType, test that .success type returns an AlertToast with .complete animation and correct title. If we have a HapticFeedback utility, test that calling success does not crash and that it respects a disabled setting (this might be just a trivial call, but we can inject a mock feedback generator to verify it was called).

UI Tests (XCTest UIAutomation): We will script end-to-end UI tests to cover main user flows with the new UI:

Authentication Flow: Launch app in fresh state (maybe with demo mode on if no backend test). Navigate the Auth screen – input email/phone, tap the PrimaryButton. Validate that on tapping, if credentials are wrong, an error toast appears (UI test can assert existence of a view with “Invalid credentials” text). If demo mode, toggling it should proceed to Orders without login. This ensures Auth screen elements are functional.

Orders List Display: After login (or demo), the Orders list should show. UI test will check that the segmented control exists with 3 segments (“New/Active/Done” labels). It will swipe down to refresh and ensure that either the loading indicator appears or skeleton cells appear. We can insert a slight delay and then verify actual order cells show up. If using demo data, count that number of cells equals expected demo orders count. Also scroll the list and ensure it scrolls smoothly (UI tests measure scrolling by swiping – we ensure no crashes or hitch).

Order Detail Actions: In UI test, tap the first order to push Order Detail. Verify that the detail view shows correct info (we can assert that a label with text “Order #1234” exists, or if that’s dynamic, check for customer name label). Then test the action button: if it’s “Claim”, tap it. After tapping, assert that a toast appears with “Order claimed” and that the button now maybe changes to “Picked Up” (if our state logic updates it instantly). Then go back and see the order status updated in the list (if we simulate that). Alternatively, in a test environment we might simply verify the toast and that the button became disabled (for a delivered action). Using XCUIElement queries, we can find the AlertToast’s label.

Profile & Logout: Navigate to Profile (maybe via a tab or menu if exists, or perhaps Orders list has a profile icon). In profile screen, test toggling demo mode (the UI should reflect it – e.g., maybe it triggers a different behavior, not easily observable, but at least ensure the toggle can be tapped and changes state). Test tapping Logout: it should bring up a confirmation alert. Assert the alert’s existence and buttons. Tap “Yes” and ensure app goes back to Auth screen. This covers the logout alert flow and ensures no crash.

Additionally, test RTL locale UI: We can write a UI test that launches the app with a Russian or Arabic locale (using launch arguments to simulate). Then verify a few elements, e.g., the segmented control order (in Arabic, “جديد/نشط/منجز” might appear – check that segment labels are correct and not clipped). This ensures our UI is not breaking in RTL.

Dynamic Type UI tests: We can set the environment variable for larger text sizes (there’s UI test APIs to override content size category) and run a subset of screens to ensure elements are still visible (no crucial button off-screen). This might be more of a manual step if automation doesn’t easily support it, but we mention it for completeness.

Manual & Exploratory Testing:

Accessibility Audit: Use Xcode’s Accessibility Inspector on each screen. Verify that all interactive elements have labels (the Inspector will highlight any missing labels or traits). For example, ensure the segmented control segments are labeled as selected or not to VoiceOver, ensure our custom StatusBadge has an accessibility label like “Status: Active”. We will also manually turn on VoiceOver and navigate: check that swiping right moves focus logically (top to bottom). If we find any odd order (like it jumps to something unexpected), we adjust using .accessibilitySortPriority or grouping.

Contrast Testing: Run the app through Accessibility Inspector’s contrast checker. For instance, verify that text on primary buttons meets at least 4.5:1 contrast ratio. If our primary color is very bright, white text should be fine; if it’s lighter, we might darken it. We adjust token colors as needed until all pass.

Performance Testing: Use Instruments (Core Animation) while scrolling the Orders list on a device to ensure FPS is ~60 and no significant frame drops occur. If the skeleton shimmer is heavy, we might see drops – then we might reduce animation frequency or simplify skeleton views. But since Shimmer is lightweight, we expect good performance. We can also profile memory when showing a Lottie animation to ensure it deallocates after (Lottie can be heavy if not handled – our usage is small though). In Xcode’s Memory Graph, check for any strong references preventing views from releasing (like if a toast stays in memory – AlertToast likely not, but check).

Edge Cases: Test on smaller devices (e.g., iPhone SE 2nd gen) to ensure layouts still fit (maybe the Auth screen needs a ScrollView to avoid keyboard covering inputs – ensure we have that if necessary, using SwiftUI’s ignoresSafeArea or KeyboardAvoider if needed). Test with no orders (simulate an empty list) – the Orders list should show an EmptyStateView or at least no cells; ensure it’s not just blank confusing screen. Test long text (e.g., an order with a very long address or customer name) – our card should either wrap text or truncate appropriately, which we can adjust after seeing it.

Test Types Summary:

Unit tests assert that design tokens and components produce the expected styling output and handle state logic (enabled/disabled, etc.).

UI integration tests simulate user interactions on critical flows (login, view orders, action on order, logout) and verify UI responses (presence of toast, navigation, updated elements).

Accessibility tests ensure labels and contrast meet standards.

Performance tests ensure no regressions in scroll or animation fluidity.

Each test will have a clear assertion: e.g., “After tapping Deliver, a success toast is displayed (assert AlertToast’s label exists), and order status changes to Delivered badge in detail (assert badge label text).” If any test fails, we will address the UI or logic until it passes. We will include these tests in our CI pipeline to prevent regressions going forward.

9. Observability & Operations

Even though this is a client-side UI improvement, we will add lightweight observability hooks to monitor usage and issues in production:

Logging Key UI Events: Utilize os.log (Unified Logging) to record user interactions that are important. For example, when a user taps the “Claim Order” or “Deliver” button, log an info message: "Order action initiated: %{public}@" with the action type. Also log success/failure of such actions (if fail, include error code). We’ll use a dedicated subsystem/category like com.courierApp.ui and levels (.info for normal actions, .error for any unexpected UI errors). These logs help debugging if an issue arises (we can see if taps were registered, etc.). They are also useful for analytics-lite understanding (e.g., how often deliveries are marked within the app). We ensure no PII is logged: use order IDs or statuses, but not customer names or addresses in logs. We use %{public}@ placeholders to let us redact if needed (though if we consider order ID sensitive, we can omit it or mark as private, but an ID is usually not personal data).

Toast Appearance Count (Telemetry): While we might not have a full analytics framework integrated, we can leverage logs or a simple counter to track how often certain toasts show – as a proxy for certain events. For example, increment a counter each time an AlertToast for “Network Error” is shown. If we find that in logs or via a debug UI, we might detect frequent network issues. Similarly, count successful deliveries (though backend likely knows, but this double-checks usage of UI). If we had an analytics service, we would send events like Analytics.track("OrderDeliveredToastShown"), but given scope, using logs is acceptable.

Performance Metrics: We can measure time-to-interactive on the Orders List screen by logging timestamps. For instance, log when OrdersList appears and when data is loaded and skeleton is replaced by real content. This delta (which might be recorded in logs or even reported to an analytics backend if available) tells us if our UI is adding overhead. Ideally, initial load time should remain similar or better (skeleton gives perceived speed improvement). If we have OSSignpost or metric kits, we could mark these intervals. For now, we will at least note in logs like “Orders list presented in X ms after launch” (we can compute by capturing a launch timestamp in AppDelegate and comparing when list data bound). These metrics help us verify performance goals in the field.

Crash/Error Monitoring: The new UI should not introduce crashes, but we will use existing mechanisms (Crashlytics or similar, if in place) to monitor after release. No specific code needed except being mindful to catch any SwiftUI errors (rare; perhaps if a library asserts on something, we test thoroughly to avoid it).

Operational Considerations: Since backend and push are unchanged, no new server dashboards needed. However, we ensure push notifications still navigate correctly to screens (e.g., tapping a push should still open Order Detail – test that the new UI doesn’t break deep linking). If any issues arise (like a push uses an old view init), we adjust routing to use new views.

Security/Privacy: Ensure that our logs do not leak private user info. E.g., if we log “User tapped Deliver for Order 123 to John Doe at 5th Ave”, that’s PII (name, address). We should instead log “Deliver action for orderId=123” without personal data. Also, when using external libs, confirm none are phoning home or collecting data – all chosen libraries are UI-only and offline (Lottie, Kingfisher, etc., do not send network requests except Kingfisher to fetch images we request – which is normal and goes to our domains). This is within expected privacy boundaries.

In summary, the UI refresh will be accompanied by improved logging of UI events and user interactions for diagnostic purposes. Post-release, the team will monitor logs for any UI-related errors (for example, if a certain action triggers an assertion in a library, it might log; we will catch that). By keeping an eye on these, we can quickly address any unforeseen issues in an iterative update.

10. Risks & Considerations

Third-Party Library Risks: Each added UI library carries a maintenance risk. Mitigation: we chose well-supported packages (e.g., Popovers and AlertToast are actively developed with many users). If a library becomes unmaintained or breaks on a future iOS, we can either fork it (since permissive licenses allow) or fall back on iOS’s evolving native features. For example, if BottomSheet library fails on iOS 18 due to some change, we could switch to Apple’s UISheetPresentationController via a quick patch. We maintain a list of these alternatives in documentation. Also, to reduce risk, we keep usage minimal and abstract (so replacing a library impacts fewer code locations).

Compatibility: Our base iOS is 16 – the chosen libraries support iOS 13/14+, so that’s fine. We must test on iOS 17 as well to ensure no new issues (some SwiftUI changes could affect layout of our components). Particularly, SwiftUI-Shimmer had a note that iOS17 changed some behavior (though the latest version likely addressed it). We’ll verify on latest OS. Another compatibility aspect is architecture: since we support Apple Silicon and Intel (for Mac Catalyst maybe), these libraries should build universally (they do support macOS, etc., as noted in their docs
github.com
 for Shimmer for example). We’ll restrict ourselves to iOS though.

UIKit Bridge Trade-offs: We mostly avoided heavy UIKit bridges, but a few exist implicitly: Lottie’s SwiftUI view wraps a UIView internally; Kingfisher’s KFImage uses UIViewRepresentable under the hood. This could introduce subtle issues like lifecycle mismatch (e.g., KFImage might not cancel download on view disappear – though Kingfisher usually does). We need to be mindful of memory – ensure images cancel when out of view (Kingfisher has options for that). The bottom sheet library is pure SwiftUI so no bridge issues there. The AlertToast is pure SwiftUI (just overlays). Popovers uses SwiftUI + a little UIVisualEffectView under the hood for blur maybe, but should be fine. We accept these minor bridges as they are proven solutions; alternative would be writing our own, which is higher risk.

App Size Impact: Including Lottie (pre-compiled XCFramework ~8 MB) and a few small Swift packages will increase the binary size modestly. Kingfisher adds a bit, Popovers and others are just code (likely < 500KB each). Overall, perhaps a ~10 MB increase. This is acceptable given modern app size expectations, but it’s a consideration on slower networks for app download. If needed, we could mark Lottie as @available only for certain features or consider on-demand resource for large animation files (not likely necessary). We’ll communicate the size change to the team.

License Compliance: All selected libraries are permissive (MIT or Apache 2.0). We must include their licenses in our attributions (usually in Settings > Acknowledgments if the app has an acknowledgments section). Apache 2.0 (Lottie) requires reproducing the license text and any notices – we will do so. We ensure that using these libraries doesn’t impose copyleft or other restrictions on our app – it does not.

Potential Bugs or Performance issues: Introduction of new UI could surface new bugs. For example, Popovers might have edge cases (maybe if multiple popovers are presented at once or if the source view’s frame isn’t known, etc.). We mitigate by testing common cases and implementing fallbacks: if a popover fails to show on some iPad layout, we could default to an Alert or sheet. Similarly, the BottomSheet might have behavior differences (maybe keyboard handling or not resizing when content changes). We should test with keyboard – e.g., if a text field is inside a bottom sheet, does it adjust? If not, we might avoid putting inputs in bottom sheets for now.

Accessibility regressions: There is a risk that fancy components are not fully accessible out of the box. E.g., the BottomSheet might not be announced as a modal by VoiceOver (we may need to add an accessibility label to the sheet grabber or content). Or the AlertToast might not be read by VoiceOver at all since it’s transient (and if it’s not, that might be okay as it’s purely visual feedback; but for users with VoiceOver, perhaps important ones should still trigger a voice announcement). We will decide if critical toasts should also call UIAccessibility.post(notification: .announcement, "Order delivered") for VoiceOver users. This ensures they get the feedback. We should consider adding that in viewModel for important events.

Dark Mode/RTL edge cases: Perhaps a color we choose looks odd in dark mode (like our “CardBackground” might need to be slightly different in dark vs light). If we see any such, we’ll adjust. Also RTL might break layout if we anchor things incorrectly (like using .leading/.trailing is usually fine; using .left explicitly would break – we won’t do that). We should test multi-line RTL text in our UI for any clipping or alignment issues.

Fallback Plans: If a particular library underperforms, we have alternatives ready:

For toasts, if AlertToast had an issue, we could swap to SimpleToast or even implement a custom overlay with withAnimation and a ZStack. The risk is low as AlertToast is stable, but fallback exists.

For bottom sheet, if it doesn’t meet our needs or causes bugs, we can reduce usage and use a simpler approach (e.g., use a standard .sheet with medium detent for Order Detail actions, losing a bit of fancy drag but still functional). The user experience might be slightly less slick but acceptable.

If Popovers had a major bug (unlikely given maturity), we could revert to using .actionSheet or .menu for those few places (Apple’s API). That’s less flexible (no tooltips), but we don’t have many tooltips critical, so it’s safe.

If Lottie proved problematic (e.g., performance or crash – historically Lottie was heavy but now with precompiled binary, it’s stable), we could drop the animation and just show a static image as a worst-case. Since it’s sugar on top, not core functionality, disabling it wouldn’t break flows.

Kingfisher fallback could be to use SwiftUI’s native AsyncImage if an emergency (with manual caching logic or accept no disk cache short-term). But Kingfisher is low-risk and can be hotfixed if needed since widely used.

Testing in Stages: We will reduce risk by feature-flagging the new UI for internal testing. Beta testers can toggle old vs new UI by a hidden setting, ensuring that if something critical is found, we can remotely disable the new UI (if we build that logic). This is a safety net for the initial rollout.

Binary Stability: Keep an eye on SwiftUI changes – e.g., if a minor iOS update (16.x) changes SwiftUI behavior, our components should still behave. Apple’s updates sometimes fix SwiftUI bugs which might affect layout. We have to test on the latest iOS minor versions.

By acknowledging these risks and having contingency plans (as described), we aim to ensure a smooth transition to the new UI. We will also schedule a post-release review to capture any user feedback or analytics signals (like drop in engagement or any error spikes) to address quickly in a point release.

11. Implementation Checklist

 SPM Packages Added: All chosen UI libraries (BottomSheet, Popovers, AlertToast, Shimmer, Lottie, Kingfisher) are added to the project and the app builds without errors. Verify package versions (BottomSheet 3.1.1, Popovers 1.0.4, etc.) and that no dependency conflicts exist.

 Design Tokens Defined: Established AppTheme (or similar) struct with color palette (light/dark variants tested), typography scale (fonts respond to Dynamic Type), spacing constants, corner radius values, shadow definitions, and timing/haptic settings. All UI code references these tokens (search the codebase to ensure no magic color literals remain).

 Core Components Implemented: Created PrimaryButton, SecondaryButton (and used them in place of any standard Buttons in UI). Created CardView and applied it to list items and relevant containers. Created StatusBadge and integrated into Order list and detail. Established any additional styles (e.g., a .segmentedControlTint) using tokens. Components are previewed in light/dark to validate appearance.

 Skeleton Loading in Orders List: Implemented skeleton placeholder views and used .redacted + .shimmering() for Orders List initial load and refresh. Visually verified skeleton appears and animates, and disappears when data is available. No layout jumps when switching from skeleton to real cells (the card heights roughly match content).

 Toast/Snackbar Integrated: Every user action that requires feedback now shows a toast via AlertToast. Specifically: login errors (if any), order claim/pickup/deliver successes, network failures, logout success. Tested that toasts display with correct message and icon, and auto-dismiss. Verified multiple toasts don’t overlap weirdly (trigger actions sequentially to see if one replaces another or queues appropriately – AlertToast should handle state binding updates gracefully).

 Popovers/Overlays Functional: Implemented at least one popover (e.g., language selector or tooltip). Confirmed it appears at the right location and can be dismissed by tapping outside or selecting an option. On iPad, it doesn’t cover the whole screen unnecessarily (Popovers library handles adaptive presentation). Tooltips if any (like a help icon) are working as expected.

 Bottom Sheet Behavior: If used for Order Detail actions or another flow, verified the sheet can be dragged between states and the content inside updates. Check that the BottomSheet’s drag handle and dimming behavior feel natural. If not using it for final UI (because opted for simpler approach), ensure the BottomSheet library isn’t accidentally linked or causing any issues (otherwise consider removing it to reduce binary size).

 Order Detail Revamp Done: The Order Detail screen now uses a sticky bottom action (bar or sheet). Verified that the action button enables/disables correctly based on order state, and triggers state changes + toast + haptic on tap. Verified layout of info sections is tidy on various device sizes and no important info is cut off.

 Auth Screen Polished: All input fields styled (with proper TextFieldStyle or custom), primary CTA visible and enabled/disabled logic (if e.g. form incomplete -> disable login button). Language switch is accessible from this screen (or profile) as decided. Possibly included a nice animation or at least a graphic to modernize the look (if not, that’s acceptable too). Safe area respected (e.g., content not hidden by keyboard – tested on small devices by focusing text field).

 Profile Screen Updated: Logout flow works with confirmation alert. Demo mode toggle works (and state persists as before). Any other settings on this screen adhere to design system (using toggles, pickers with our tint, etc.). No misaligned elements – used VStack with proper spacing.

 Theming and Mode Switches: Dark Mode verified globally (no glaring issues like white text on bright background). RTL language verified – e.g., set app to Arabic: login fields, order list, etc., all mirror appropriately. Dynamic Type verified – set XXL font: UI still usable (maybe more scrolling but nothing overlaps or is truncated incorrectly). Addressed any found issues (e.g., added scroll views or made text multiline where needed).

 Accessibility Checks Passed: Used Accessibility Inspector – all interactive UI elements have labels (added explicitly if needed). Color contrast for text vs background is sufficient (adjusted colors if any failed). Focus order in each screen is logical. Also ensured large tap areas: e.g., the whole Order card is tappable due to using .contentShape(Rectangle), small icons like info buttons have at least 44x44 hit area (we added padding or made the containing element tappable).

 Performance Acceptable: Scroll through a long orders list on a test device – no significant stutters (ensured by using Lazy stacks and lightweight views). Shimmer effect does not consume excessive CPU (should be fine, we can confirm via Instruments if needed). App launch time not noticeably worse – if Lottie animations are loaded lazily (they should be loaded on first use, not at launch). Memory footprint stable (no continuous growth when showing multiple toasts or opening/closing bottom sheets repeatedly).

 Automated Tests Passing: All unit tests (tokens, components) and UI tests (flows for login, orders, etc.) are passing in CI. Adjust tests if needed to accommodate new UI identifiers (we might use accessibilityIdentifiers for key elements in tests). No flakiness introduced.

 No Backend Breakage: Quick test that data flows are unaffected – e.g., receiving a push for a new order still displays it properly in the list with the new card style. The push handling code might reference UI (if it navigates to detail, ensure it targets the new detail view correctly). API calls triggered by UI (like marking delivered) still work as before (we didn’t change the URLSession calls; just ensure our UI binding calls the same ViewModel function).

 Feature Flag (if implemented): Confirm that toggling the flag indeed switches back to old UI (for safety). We may simulate this via a debug menu or build configuration. This ensures rollback path is viable.

 Stakeholder Review: Demo the new UI to design/product stakeholders using TestFlight or similar. Ensure the look-and-feel meets expectations. Collect any minor UI tweaks and implement them before release. (This checklist item is for internal alignment; consider it done when sign-off is received.)

Once all boxes are checked, we can confidently proceed to release the updated app, knowing it delivers a significantly improved user experience while maintaining reliability and performance.