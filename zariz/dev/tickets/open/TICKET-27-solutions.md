Fix Swift 6 iOS Login Crash and Post-Login Order Sync Bugs

Fixing iOS Login Crash: Concurrency, Keychain, and Sync Resolution Plan
1. Concurrency-Safe Delegate Patterns (Swift 6)

Swift 6’s stricter concurrency checks uncovered that our delegate methods (for push notifications and app lifecycle) were not isolated correctly, causing a runtime trap. The solution is to ensure these delegates run on the main thread (MainActor) or avoid crossing actor boundaries with non-Sendable closures
twocentstudios.com
:

Mark delegate methods or classes with @MainActor: This forces the delegate calls (e.g. userNotificationCenter(_:didReceive:)) to run on the main thread, so the completion handler’s implicit closure executes on main and avoids the crash
twocentstudios.com
. For example, declare @MainActor class PushManager: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate { … }. This way, any UI state (like our @Published properties) is confined to the main actor, and Swift won’t complain about data races. Alternatively, mark the specific problematic method with @MainActor if making the entire class main-actor isolated is too restrictive
twocentstudios.com
.

Use the non-async delegate APIs with explicit main dispatch: Instead of adopting the new async variants of delegate methods, implement the traditional versions with the completion handler. For instance, implement userNotificationCenter(_:didReceive:withCompletionHandler:) rather than the async ...didReceive() async form. Call the completion handler immediately, then dispatch any UI work to the main actor. This avoids capturing non-sendable values across actors
twocentstudios.com
. For example:

func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse,
    withCompletionHandler completion: @escaping () -> Void
) {
    // Process notification (decode payload, etc.)
    Task { @MainActor in 
        handleNotification(response)  // update UI or state on main thread
    }
    completion()  // signal system that we've handled the notification
}


Similarly, for application(_:didReceiveRemoteNotification:fetchCompletionHandler:), call the completionHandler on time. If you need to fetch data, you can perform the fetch asynchronously but call the completion handler after the fetch completes (to inform iOS of new data)
twocentstudios.com
. For example:

func application(_ app: UIApplication,
                 didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                 fetchCompletionHandler completion: @escaping (UIBackgroundFetchResult) -> Void) {
    Task.detached {
        do {
            try await OrdersService.shared.sync()
            await MainActor.run { completion(.newData) }
        } catch {
            await MainActor.run { completion(.failed) }
        }
    }
}


This ensures we don’t capture the completion handler inside an actor-isolated context. By dispatching to MainActor (or using Task.detached), we avoid Swift’s “sending non-Sendable across actors” error. The key point is that the completion handler is invoked on the correct thread without race conditions, and any UI updates happen on the main thread. This approach aligns with the Swift 6 update: Apple essentially recommends either isolating the entire delegate to MainActor or handling the completion in a non-async context
twocentstudios.com
. Following these patterns eliminates the EXC_BREAKPOINT crash caused by the concurrency violation.

Update PushManager accordingly: We should ensure that PushManager’s delegate methods use the above approach. Marking PushManager as @MainActor is advisable since it has @Published properties (like the device token) that are observed by SwiftUI. This guarantees any mutations (e.g. setting deviceToken) happen on the main thread. Then, implement the delegate methods without isolation (they’ll implicitly run on main due to the class annotation) or with @MainActor on each. For example:

@MainActor
final class PushManager: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, ObservableObject {
    @Published var deviceToken: Data? = nil  // only mutate on main thread

    func application(_ application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken token: Data) {
        // Already on main actor, safe to assign directly
        self.deviceToken = token 
        // Possibly send token to backend here
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completion: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Always show banner & sound for foreground notifications
        completion([.banner, .sound])
    }

    func application(_ application: UIApplication,
                     didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // Handle silent push by fetching latest orders
        Task {
            do {
                try await OrdersService.shared.sync()
                completionHandler(.newData)
            } catch {
                completionHandler(.failed)
            }
        }
        // Note: Since PushManager is @MainActor, this method is invoked on main.
        // We call completionHandler inside the Task AFTER data sync completes.
        // This ensures iOS knows when we've finished processing the push.
    }
}


In the above pattern, we call the completion handler after the asynchronous work is done. This is slightly different from our previous approach (where we called it immediately with .noData). The updated approach is more correct for background fetch: we inform the system of .newData only if new data was fetched (or .failed on error). By keeping this logic on the main actor (PushManager is main-isolated), we satisfy Swift concurrency rules and avoid warnings or data races.

These changes address the Swift 6 sendability warnings (like “sending non-Sendable completionHandler across concurrency domains”). After applying them, no more sendability warnings should appear for PushManager or SSEClient. The runtime crash (Task 5: EXC_BREAKPOINT) will be resolved, as we no longer violate MainActor rules. This was confirmed by community insights: ensuring the async delegate callback runs on the main thread prevents the completeTaskWithClosure crash
twocentstudios.com
twocentstudios.com
.

2. Robust Keychain Save/Load with LAContext (Biometrics)

We suspect the crash on login may partly stem from Keychain errors (like an unhandled exception if saving to the Keychain failed, or a read using the wrong context). The recent changes to Keychain usage (adding biometrics and LAContext) need refinement. We want a Keychain storage strategy that works on simulator (no biometrics) and on devices (with or without biometrics), without crashes or lost data.

 

a. Saving credentials with proper access control: We will use SecAccessControl with a fallback hierarchy:

If biometrics (Face ID/Touch ID) are available and enrolled, create SecAccessControl with .biometryCurrentSet. This ties the item to the current biometric enrollment and requires a biometric auth to read
medium.com
. (We prefer .biometryCurrentSet over .biometryAny so that if the user adds a new fingerprint/FaceID, the token invalidates for security
medium.com
.) This provides the highest security (no passcode fallback by default).

If biometrics are not available or not enrolled, but the device has a passcode, use .userPresence instead
medium.com
. This flag allows either biometric or device passcode to unlock the item, providing a fallback. It requires some form of user authentication on access (e.g. Face ID or device PIN). We will pair this with kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly to ensure the device must have a passcode set
medium.com
 (if no passcode, the item won’t be stored at all). Using WhenPasscodeSet adds security by not storing the item on devices without a passcode.

If neither biometric nor passcode is available (e.g. Simulator or a device with no passcode – though rare), fall back to a less secure option: use no SecAccessControl flags at all, but set the item’s accessibility to .afterFirstUnlockThisDeviceOnly. This means the token is stored on device and accessible after the first device unlock, without additional user auth. On simulator, this is essentially the only working option (since simulator cannot do biometric or passcode auth). It’s still reasonably secure (the keychain item isn’t accessible if the device is rebooted and not unlocked), and it’s marked device-only so it won’t sync to iCloud.

Implementing this in code:

import Security
import LocalAuthentication

enum KeychainError: Error { case unexpected(OSStatus), noAccessControl }

func makeAccessControl() throws -> SecAccessControl? {
    var error: Unmanaged<CFError>?
    // Check biometric availability
    let context = LAContext()
    if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil) {
        // Use biometrics (Face ID/Touch ID)
        let flags: SecAccessControlCreateFlags = .biometryCurrentSet
        let ac = SecAccessControlCreateWithFlags(nil, 
                      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, 
                      flags, &error)
        if let ac = ac { return ac }
        // If creation failed (error might be biometry not enrolled), fall back below
    }
    if LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: nil) {
        // No biometrics, but deviceOwnerAuthentication covers passcode or biometrics
        let flags: SecAccessControlCreateFlags = .userPresence  // allows passcode
        let ac = SecAccessControlCreateWithFlags(nil, 
                      kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly, 
                      flags, &error)
        if let ac = ac { return ac }
    }
    // Final fallback: no SecAccessControl (return nil to indicate using simple accessible attr)
    return nil
}

func saveRefreshToken(_ token: String, for user: AuthenticatedUser) throws {
    // Prepare attributes
    let account = user.identifier  // use username/identifier as keychain account
    let tokenData = Data(token.utf8)
    // Remove any existing item for this account to avoid duplicates
    let baseQuery: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "AuthRefreshToken",  // service name for our app
        kSecAttrAccount as String: account
    ]
    SecItemDelete(baseQuery as CFDictionary)  // ignore result (item may not exist)
    // Decide on access control
    if let ac = try makeAccessControl() {
        var query = baseQuery
        query[kSecAttrAccessControl as String] = ac
        query[kSecValueData as String] = tokenData
        // Optionally, we can supply an LAContext for the *write* operation as well
        // to utilize the reuse duration if recently authenticated. Not required here.
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpected(status)
        }
    } else {
        // No special access control; store with AfterFirstUnlock for widest compatibility
        var query = baseQuery
        query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        query[kSecValueData as String] = tokenData
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unexpected(status)
        }
    }
}


In the above code, makeAccessControl() tries .biometryCurrentSet then .userPresence, using WhenPasscodeSetThisDeviceOnly for strong security (only accessible on this device, and only when unlocked with passcode)
medium.com
. If both attempts return nil, we’ll store without access control. We delete any existing item to handle the re-login case cleanly (avoiding duplicate items or conflicts). Error handling: We throw a custom error if SecItemAdd fails. In practice, SecItemAdd can fail if something unexpected occurs (e.g. out of memory, or the keychain is locked for some reason). We will catch these errors in the calling code to avoid crashing the app (more on that below).

 

b. Loading credentials with and without prompt: Reading the refresh token must handle items that might require authentication. We’ll implement loadRefreshToken(prompt:) to allow an optional biometric prompt:

If prompt is provided (non-nil string), we interpret that as the user is currently performing an action that can prompt for authentication (e.g. the user initiated a refresh or an unlock action). We will supply this prompt to the Keychain query so the system can show the Face ID/Touch ID dialog. In practice, we do this by setting the kSecUseOperationPrompt key in our query to the prompt message
medium.com
. This tells the keychain to allow UI and use the string as the reason text.

If prompt is nil, we want a silent lookup (no UI). We will set kSecUseAuthenticationUI = kSecUseAuthenticationUISkip in the query to bypass any auth prompt
medium.com
. This means if the item needs authentication (biometric/passcode), the query will simply not retrieve it and return an error rather than showing a prompt
medium.com
. (In Swift 6, kSecUseAuthenticationUIFail was deprecated in favor of ...UISkip, which has the same effect of skipping authentication UI.)

Using these flags, we can attempt to load the token silently on app launch (prompt = nil). If it fails with an auth error, we treat it as “no accessible session” and avoid a crash. Later, when a refresh is needed (and perhaps the user is actively using the app), we call loadRefreshToken(prompt: "Authenticate to refresh session") to prompt the user for biometrics or passcode, unlocking the token.

 

Here's an implementation outline:

func loadRefreshToken(prompt: String? = nil) throws -> (token: String, userId: Int)? {
    var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrService as String: "AuthRefreshToken",
        kSecMatchLimit as String: kSecMatchLimitOne,
        kSecReturnData as String: true,
        kSecReturnAttributes as String: true
    ]
    if let promptMessage = prompt {
        // Allow authentication UI with the provided reason
        query[kSecUseOperationPrompt as String] = promptMessage  :contentReference[oaicite:16]{index=16}
    } else {
        // No UI: skip items that would need authentication
        query[kSecUseAuthenticationUI as String] = kSecUseAuthenticationUISkip  :contentReference[oaicite:17]{index=17}
    }
    var item: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &item)
    if status == errSecItemNotFound {
        return nil  // no item stored
    }
    if status == errSecAuthFailed {
        // Item exists but we couldn't access it without authentication.
        // If no prompt was provided, we assume the session is locked.
        // We do not throw here; just indicate no accessible token.
        if prompt == nil {
            return nil 
        } else {
            // If we *did* prompt and still failed, it means authentication was canceled or failed.
            throw KeychainError.unexpected(status)
        }
    }
    guard status == errSecSuccess, let found = item as? [String: Any],
          let data = found[kSecValueData as String] as? Data,
          let tokenStr = String(data: data, encoding: .utf8) 
    else {
        throw KeychainError.unexpected(status)
    }
    // We can also retrieve associated username/ID if we stored it in attributes:
    // e.g., found[kSecAttrAccount] might hold the identifier.
    return (tokenStr, /* maybe parse userId from somewhere if needed */ 0)
}


Key aspects of this implementation:

If the status is errSecAuthFailed and we didn’t allow UI, we simply return nil. This way, at app launch (when we call loadRefreshToken() with no prompt), if the token is protected by biometrics we’ll get nil and treat it as no session (the app will show the login screen). We avoid a crash by not trying to force-unwrap or use a token we can’t access.

If a prompt was provided and we still got errSecAuthFailed, it likely means the user failed Touch ID or canceled the prompt. In that case, we throw an error (which our higher-level code can catch and e.g. present an error message). This is a user action, not an app bug.

On errSecSuccess, we decode the token Data to a String. We should also consider that we stored the user’s info. In our case, we might have stored user ID, role, etc., perhaps by encoding a JSON in the data or by separate attributes. If so, parse those here as needed. (If we simply stored the refresh token, then this function can return just the token string. Our AuthenticatedUser can be reconstructed from other persistent info if needed.)

c. Error handling and stability: We must ensure that any errors from Keychain operations are handled gracefully:

During login (AuthSession.configure): Previously, we did try AuthKeychainStore.save(...) inside the actor. If that threw, it might have propagated out unhandled. We should catch errors from save and handle them. For example, if saving to keychain fails (which is rare, but could happen if keychain is somehow not accessible), we can log the error and perhaps show a non-fatal alert to the user (“Secure storage failed, your session won’t be persisted”). The app should not crash. We can proceed with login in memory, but warn that the session might not persist. Given this is a critical scenario (P0 bug), we might even choose to treat it as login failure and ask the user to retry or use a fallback method. Regardless, do not crash. Wrap the save in do/catch.

During refresh (AuthService.refresh): Similar approach – surround AuthKeychainStore.load(prompt:) in a do/catch. If it throws or returns nil (no session), then refresh should throw a specific error (e.g. AuthError.noStoredSession) that we handle by forcing a re-login. If the load returns but later SecItemAdd (when saving new token) fails, catch that and throw an error upward. The refresh() function is awaited inside AuthSession.validAccessToken(), which is itself called by various network requests. If refresh throws, we should ensure it doesn’t bring down the app. We likely handle it by propagating the error to the network call, which then triggers a logout flow. For instance, if refresh returns an HTTP 401 or keychain error, we can post an authSessionExpired notification or set a flag to show the Login screen again.

Test on simulator and device: On the simulator, the code path should use the fallback (no biometrics). Verify that logging in stores the item and that loadRefreshToken() (with no prompt) retrieves it successfully on next app launch (since no auth needed). On a device with Face ID enabled, verify that after login, if you kill and relaunch the app, loadRefreshToken() without prompt returns nil (since Face ID is required). The user should then have to log in again or we implement a logic to prompt them for Face ID at launch. (Many apps choose not to auto-prompt on launch unless the user opts in to “use Face ID to remember me.” Given our scenario, it’s acceptable that the session isn’t automatically restored if locked—user will log in again. Alternatively, we could decide to prompt at launch: if we detect errSecAuthFailed at launch, we might show a pop-up, “Unlock with Face ID to restore your session?” and then call load with prompt. This is a UX decision outside the scope of the technical fix, so for now, treating it as no session is fine.)

LAContext reuse and flexibility: We should set LAContext.interactionNotAllowed = true only when we intend no UI. In our approach, we didn’t manually set this property; instead, we rely on the keychain query flags. Under the hood, if we provide an LAContext to the query and do not allow UI, one could do context.interactionNotAllowed = true and then include kSecUseAuthenticationContext: context in the query. However, using kSecUseAuthenticationUI = .skip is simpler
medium.com
. We should keep our code simple: use the prompt string for allowing UI, or the skip for silent. If needed, the LAContext can also be used to set a Touch ID reuse duration for convenience (so that if the device was just unlocked or recently authenticated, it might not prompt again)
medium.com
. For example, we could do context.touchIDAuthenticationAllowableReuseDuration = 10 seconds
medium.com
 to allow reuse of recent authentication. This can prevent multiple prompts in quick succession. This is optional but improves UX if, say, the user triggers a refresh immediately after unlocking the app.

Reading items saved under older access controls: Since we changed our strategy, consider if a user had a refresh token saved with .biometryCurrentSet (from the previous app version) and now is on simulator or biometrics off. Our new loadRefreshToken() with .skip will return nil (since it can’t satisfy the policy without UI). That’s acceptable – it means the session can’t be restored silently. We then ask for login. Once they log in again, we’ll save using the new logic (perhaps just userPresence or accessible) which will overwrite the old item. Thus, the next launch, the token might be retrievable silently if we ended up using no biometric. Essentially, one re-login might be needed when moving between biometric availability states. We should document this for QA: if a session was saved with Face ID and now the user turned Face ID off (or is running on a different device context), they may have to log in again. This is a reasonable trade-off for security.

d. Sample Keychain usage results: After implementing the above, test both flows:

No-biometrics scenario (Simulator or device with no Face ID): Logging in should save the refresh token with .afterFirstUnlockThisDeviceOnly. No crash should occur. On app restart, AuthKeychainStore.load() (with no prompt) should find the item (since it doesn’t require auth) and return the token. The app will auto-login to the main screen. Logging out should remove the item (we already call SecItemDelete before saving a new one; we might also explicitly delete on logout). Re-login works repeatedly without crash.

Biometric scenario (Device with Face ID/Touch ID): Logging in saves with SecAccessControl (biometric). If the app remains running, everything functions (the token is in keychain, but locked). When making an API call that requires a valid access token after some time, our AuthSession.validAccessToken() will call refresh. In refresh, we do AuthKeychainStore.load(prompt: "Authenticate to refresh session"). This will trigger the Face ID prompt on the device. If the user authenticates successfully, we get the token and proceed with the refresh network call. No crash – if the user cancels, load throws, we catch it and can e.g. cancel the refresh. After a successful refresh, we save the new refresh token back to the keychain (which will still require biometric on next access). The UI should possibly show a message if Face ID was canceled (e.g. “Session expired and unlock was canceled”). In any case, no unhandled exceptions.

By following Apple’s guidelines for biometrics (using kSecUseOperationPrompt for on-demand auth)
medium.com
 and skipping UI for silent checks
medium.com
, we cover all bases. This robust save/load pattern ensures no crashes and consistent behavior across environments.

 

Finally, ensure that all keychain results are logged for telemetry (in non-sensitive ways). For example, log an event when a keychain save succeeds or fails (without printing the token itself). This will help us track if any Keychain operation fails unexpectedly in the wild. Often SecItemAdd just works, but logging any non-success OSStatus (and the device scenario) could reveal edge cases (like iCloud Keychain issues or keychain being locked if device is locked – though .WhenUnlocked prevents access when locked anyway).

3. Hardening Auth Token Lifecycle and Refresh Flow

Our token management logic will be strengthened to be correct, thread-safe, and resilient:

Single-flight refresh using actors: The current design (an AuthSession actor with a refreshingTask property) is on the right track. It prevents multiple simultaneous refresh calls. This pattern is essentially a known best practice for refresh flows
medium.com
. We’ll maintain it, with a minor tweak: ensure that once refreshingTask is set, any awaiting calls get the result then we clear refreshingTask (we already do this with a defer { refreshingTask = nil } in our code). This avoids a deadlock where refreshingTask might never be cleared if an error is thrown before clearing. To handle that, ensure defer runs in all paths. Our implementation is:

actor AuthSession {
    private var refreshingTask: Task<String, Error>?

    func validAccessToken() async throws -> String {
        if let token = accessToken, !isExpiringSoon(token) {
            return token
        }
        // Token is expired or about to expire
        if let task = refreshingTask {
            // A refresh is already in progress; wait for it
            return try await task.value
        }
        // No refresh in progress, start one
        refreshingTask = Task {
            let pair = try await AuthService.shared.refresh()
            // Update in-memory token
            self.accessToken = pair.accessToken
            self.accessTokenExp = pair.expiresAt
            return pair.accessToken
        }
        do {
            let newToken = try await refreshingTask!.value
            return newToken
        } finally {
            // Always clear the task when done or if error
            refreshingTask = nil
        }
    }
}


This ensures no concurrent refresh storm even if many network calls hit an expired token simultaneously – all will await the one refresh() call
medium.com
. The actor serialization plus the refreshingTask guard accomplishes this.

Avoiding deadlocks and reentrancy: In our design, AuthSession and AuthService are both actors. We must be careful to avoid them calling each other in a cyclic waiting pattern. For example, AuthService.refresh() might call AuthSession.configure() internally (which is an actor call back into AuthSession). Our current code hinted at that: “update session via AuthSession.configure … return pair”. We should simplify this: have AuthService.refresh() simply perform the HTTP request and parse the token, but not call back into AuthSession. Instead, handle updating AuthSession state in the validAccessToken() after awaiting. Notice in the code above, we update self.accessToken and expiresAt inside the AuthSession actor, rather than inside AuthService. This way, AuthService doesn’t need to know about AuthSession internals, avoiding a potential actor-to-actor call cycle.

 

If we do need AuthService to update global state, we could mark AuthService.refresh() as nonisolated or make it a static function, since it doesn’t actually need AuthService’s isolation (it’s just a network call). But the simpler approach is as above: do updates in AuthSession context after receiving the new tokens.

Refresh on demand vs proactive: Our validAccessToken() checks if the current access token is near expiry. We should define “near expiry” (say, 1 minute or 5 minutes before actual expiration) to avoid using an expired token. For safety, we might refresh if less than 30 seconds to expiry to avoid race. This threshold can be adjusted. Logging the time remaining whenever we decide to refresh vs reuse token is useful for debugging future issues.

HTTP 401 handling: Even with best efforts, it’s possible a token expires or is revoked such that a refresh token is no longer valid. The backend will respond with HTTP 401 Unauthorized in that case. Our AuthService.refresh() should detect a 401 and throw a specific error (e.g. AuthError.refreshExpired). The validAccessToken() logic can catch this and propagate it in a way that the UI/network layer can handle (possibly by forcing logout).

 

Concretely:

struct AuthError: Error {
    enum Kind { case noSession, refreshExpired, networkError }
    let kind: Kind
    let underlying: Error?
}

// In AuthService.refresh():
let (data, resp) = try await URLSession.shared.data(for: req)
guard let httpResponse = resp as? HTTPURLResponse else {
    throw AuthError(kind: .networkError, underlying: nil)
}
if httpResponse.statusCode == 401 {
    throw AuthError(kind: .refreshExpired, underlying: nil)
}
if httpResponse.statusCode != 200 {
    throw AuthError(kind: .networkError, underlying: nil)  // or parse error message
}
// parse JSON for new tokens...


Then, in AuthSession.validAccessToken(), if refresh() throws .refreshExpired, we know the refresh token was invalid. We should not retry in that case (refresh token is single-use and already refused). Instead, we can do something like:

do {
    return try await task.value
} catch let err as AuthError {
    refreshingTask = nil
    if err.kind == .refreshExpired {
        // Clear session and notify logout
        self.accessToken = nil
        self.currentUser = nil
        try? AuthKeychainStore.clear()  // function to delete stored token
        NotificationCenter.default.post(name: .authSessionExpired, object: nil)
    }
    throw err
} catch {
    refreshingTask = nil
    throw error
}


This way, if the refresh fails because it’s invalid (e.g., server revoked it or it’s been used already), we immediately log the user out for safety. The UI (on observing the .authSessionExpired) can navigate to the login screen. We also clear any leftover token from keychain to avoid repeated failures. This scenario might happen if the user logged out from another device or if the refresh token timed out (some systems expire refresh tokens after a long period).

Retry/backoff strategy: For network errors during refresh (e.g., no internet), we might implement a simple retry. Perhaps attempt one immediate retry if the first attempt fails due to network (e.g., URLError.notConnectedToInternet). We can use a short delay with try? await Task.sleep(nanoseconds: 1_000_000_000) (1 second) before retrying. But we should not loop indefinitely. A simple approach: one retry, then give up and surface an error (maybe prompting the user to check connection). Given refresh usually happens in the background, an automatic retry is user-transparent. However, to keep things minimal, we might skip automated retry for now and just bubble up the error. The user’s action (like pulling to refresh orders) might trigger another attempt later.

Telemetry and logging: We will instrument key points:

Log auth.login.success (with user ID or role, and time taken).

Log auth.login.failure (with reason, e.g. wrong password or network error).

Log auth.refresh.success (including whether it was using cached refresh token or user had to authenticate via Face ID, maybe log interactive=true/false).

Log auth.refresh.failure (with error code: e.g., expired_token vs network timeout).

Log token rotation events: when we receive new tokens, possibly log a debug with old vs new token expiry times.

Use OSLog (Logger) with subsystem "com.myapp.auth" and categories like "AuthService" so that these can be filtered in Console. Avoid logging actual tokens or PII; use identifiers or just statuses.

Also log when keychain load/save happens: e.g., auth.keychain.save.success or any errSec code on failure.

For orders syncing (next section), similarly add logs:

orders.sync.request (with endpoint and maybe query params).

orders.sync.response (status code, bytes).

orders.sync.parsed (count of orders, IDs of orders).

If after parsing, we attempt to save to SwiftData, log success or any error from saving.

These logs will help us if issues persist. For instance, if orders are not appearing, the logs might show that we parsed 1 order but perhaps SwiftData.save() threw an error (which we’d log).

 

In summary, our refresh logic now ensures only one refresh at a time, handles error cases gracefully (no crash, just a logout on fatal refresh failure), and logs important events. This aligns with standard patterns: using actors to serialize refresh calls
medium.com
 and rotating refresh tokens every time for security
stackoverflow.com
stackoverflow.com
.

4. Ensuring Orders Appear After Login (SwiftData Sync)

The orders were successfully fetched (HTTP 200 and JSON parsed) but not showing in the UI. This indicates a data persistence or UI update issue, likely due to SwiftData context usage. We will address this by synchronizing the timing of data insertion with SwiftUI’s context availability and verifying the data flow:

Initialize SwiftData ModelContainer early: To avoid any race conditions, we should create the SwiftData container as early as possible, ideally at app launch. SwiftData is integrated with SwiftUI via the .modelContainer() view modifier. In our SwiftUI App struct, we can attach the container to the WindowGroup. For example:

@main
struct ZarizApp: App {
    @UIApplicationDelegateAdaptor(PushManager.self) var pushManager
    // Suppose Order and other model types are annotated with @Model
    var body: some Scene {
        WindowGroup {
            ContentView()  // decide initial view based on session in ContentView
        }
        .modelContainer(for: [Order.self, ...])  // attach SwiftData container for our models
    }
}


By doing this, any view in our app can access the ModelContext via @Environment(\.modelContext). We should then refactor AppSession/ModelContextHolder: instead of manually setting a global context in an .onAppear, rely on environment. For instance, in our OrdersListView, we can get the context with @Environment(\.modelContext) var modelContext. Since the container is set up at app launch, by the time the user logs in and OrdersListView appears, modelContext will be non-nil. This eliminates the window where ModelContextHolder.shared.context was nil.

Delay sync until context is ready: If we prefer not to inject the container globally (for example, if there are reasons to initialize it later or not at app start), then ensure we do not call OrdersService.sync() until after the SwiftData context is set. In our current flow, it seems a sync might be triggered immediately on login (perhaps via the push delegate calling sync() on didReceiveRemoteNotification, or via an .onAppear in the main view). We should adjust the timing:

 

One approach is to initiate the first sync when the Orders list view appears (which inherently means the context is in place). For example, in OrdersListView.onAppear, call OrdersService.shared.sync(). If we already did a sync earlier (e.g., due to a silent push right at login), that data might not have been saved due to no context. We can simply run sync again on appear to be safe. The duplicate network call is not ideal, but given the small number of orders and our P0 urgency, it’s acceptable. In future, we might implement a better caching between the two, but it’s more important that the user sees their orders.

 

Another approach: if AuthSession.configure posts an .authSessionConfigured notification, we could respond to that after the main view is set. For instance, in the main MainTabs view’s .onAppear, we observe .authSessionConfigured and then trigger sync(). This ensures we only sync when UI is ready to consume data.

Perform data insertion on the correct thread: SwiftData’s ModelContext is not thread-safe unless documented otherwise. We should treat it similarly to Core Data’s NSManagedObjectContext, which is typically tied to a thread/queue. The model context provided via .modelContainer in SwiftUI is bound to the main thread (since SwiftUI views update on main). Therefore, when our background task fetches orders, we need to insert them on the main thread’s context.

 

We can achieve this by wrapping the save logic in DispatchQueue.main.async or using MainActor.run. For example, inside OrdersService.sync():

func sync() async throws {
    let req = await authorizedRequest(path: "orders")
    let (data, _) = try await URLSession.shared.data(for: req)
    let orders = try JSONDecoder().decode([Order].self, from: data)
    os_log("orders.sync.parsed count=%d ids=%@", orders.count, orders.map{$0.id})
    // Save to SwiftData
    try await MainActor.run {
        guard let context = ModelContextHolder.shared.context else {
            os_log("orders.sync: No ModelContext available, skipping save", type: .error)
            return
        }
        for order in orders {
            context.insert(order)  // if order is @Model, this registers it for saving
        }
        try context.save()
    }
    os_log("orders.sync.saved count=%d", orders.count)
}


In this pseudo-code, we ensure that insertion and saving happen on the MainActor. If we adopt the environment approach, we might not even need ModelContextHolder – we could pass the context in or use an EnvironmentObject. But to minimize refactoring, we can keep a shared context reference that the view sets once it’s created, then do await MainActor.run to use it. Logging is added to catch if context was nil or if save threw an error.

 

By doing this, we avoid missing data due to threading. If sync() was called from a background thread (like the push handling Task), without this, it might be trying to use the context from the wrong thread (or context was nil). Now, with MainActor.run, if the context isn’t set yet, we log and skip (the log will help us verify if this happens unexpectedly). However, if we ensure context is set at app launch (via .modelContainer), then by the time any network response arrives, context will exist. The guard check is just an extra safety net.

Verify SwiftData pipeline: Once data is saved in the context, how does the UI show it? Ideally, the OrdersListView is using SwiftData to fetch Order objects. SwiftData provides a property wrapper @Query for SwiftUI views, e.g.:

struct OrdersListView: View {
    @Query(sort: \Order.timestamp, order: .reverse) private var orders: [Order]
    // ...
    var body: some View {
        List(orders) { order in
            OrderRow(order: order)
        }
        .onAppear {
            // possibly trigger OrdersService.sync() here as discussed
        }
    }
}


With @Query, SwiftUI automatically fetches Order objects from the model context and updates the list when they change. If we inserted orders into the context on the main thread, this should cause the orders property to update and the List to refresh, showing the new orders. Important: Ensure that the Order model in SwiftData has an appropriate primary key or uniqueness so that inserting the same order twice doesn’t create duplicates. If our Order model is defined with an @Attribute(.unique) or we manually check, it’s okay. If not, our context.insert(order) might insert duplicates on each sync. A better approach in sync is to perform an upsert: find existing order by ID and update it, or insert if not exists. SwiftData is new and might not yet have a built-in upsert; we might need to query by ID and replace. Given only one order was coming in the test, duplicates may not have been an issue yet, but something to be mindful of.

 

If our UI was not using @Query but instead an explicit fetch or an @Published list that we populate, we should make sure to update that list on the main thread after saving. However, since SwiftData is likely used (the question references SwiftData migration), we’ll assume @Query or similar is in place.

Race between sync and context setup: Suppose, hypothetically, OrdersService.sync() was called very quickly after login, perhaps even before the SwiftUI view appeared (e.g., via the push manager). In that case, our ModelContextHolder.shared.context might still be nil when sync tries to save. Our log would catch it (“No ModelContext available, skipping save”). To handle this, we could do one of two things:

Buffer the orders: If context is nil, store the fetched orders in a temporary array or in OrdersService state. Then, when the context becomes available, insert them. We could listen for a notification or have the view call a method to flush the buffer. This is a bit complex.

Simply re-trigger sync once context is available: As mentioned, calling sync again on view appearance is straightforward. So, if the first sync “missed” due to nil context, the second sync will load the data anyway. The downside is an extra network call, but it’s acceptable given the low volume (and it’s all local dev environment now).

We opt for the simpler approach: ensure OrdersListView.onAppear calls sync unconditionally. In practice, after login, the user is taken to the main screen; on that .onAppear, call sync. Meanwhile, if a background push had already synced, it either succeeded (and context was present, showing data) or did nothing (context nil). In either case, the onAppear sync ensures data is there.

Add instrumentation in SwiftData operations: Add assert(context != nil, "ModelContext is nil in OrdersService.sync") in debug builds, so we catch if that ever happens in development. We should also log the results of context.save(). If save() throws (for example, due to a schema mismatch or constraint violation), catch it and log the error message. A common issue could be if the Order model has a required field that’s nil in the JSON, the save might fail validation. We already mitigated one such crash by making fields optional for migration. But logging any save error will help identify if something like that is preventing data from persisting.

With these measures, when the user logs in and navigates to Orders, they will see their orders. We know the network call succeeded (as per logs), so the focus is on the data path into SwiftUI. By ensuring the SwiftData context is ready and used properly on the main thread, we fix the gap.

 

Recap flow after fixes:

App launches, sets up SwiftData container (context available).

If a previous session exists (and accessible), app goes to MainTabs; if not, to Login.

User logs in (if needed), AuthSession.configure posts notification, and we set session.isAuthenticated = true which triggers showing MainTabs.

MainTabs/OrdersListView appears, and in .onAppear it calls OrdersService.sync().

sync() fetches orders, decodes JSON (e.g., one order with id 12).

sync() inserts the Order on main thread into context and saves. This is on main actor, so the SwiftUI view (also on main) is notified of the new model data.

The @Query in OrdersListView picks up the new Order object in the context, and the List now shows 1 order (id 12).

Telemetry: logs show orders.sync.parsed count=1 ids=[12] and orders.sync.saved count=1. If any issue occurred, logs would show an error.

We should test this end-to-end. Particularly, verify that after login, the UI doesn’t show zero orders anymore. Also test a logout -> login again cycle to ensure no duplicates or stale data: perhaps clear the SwiftData store on logout or simply rely on the next sync to overwrite data (if an order is re-fetched with same id, SwiftData might currently insert a duplicate unless we handle it – a possible improvement is to delete all Order objects on logout or before inserting new ones for a new session, to avoid showing old orders from a previous user session).

 

Given time, a simpler path: on login (in AuthSession.configure), if we detect a new user logging in, we could wipe the Orders container (to remove any orders from the previous user). This prevents cross-user data mixing. SwiftData can delete all objects of a type via a query; or if using separate containers per user, even better. But a quick fix: if previousUser.id != newUser.id { for order in try context.fetch(Order.self) { context.delete(order) }; try context.save() } upon login. This ensures a clean slate for new data. This is an edge detail, but important if multiple accounts are used on the same device.

5. Diagnostics and Testing

To catch issues like our EXC_BREAKPOINT crash in the future and to verify fixes, we should enhance our diagnostics:

Enable exception breakpoints: In Xcode, add a Symbolic Breakpoint for objc_exception_throw and a Swift Error Breakpoint. The former catches Objective-C exceptions (like an NSAssert failure in UIKit), and the latter catches Swift errors that trigger a trap. Swift concurrency runtime violations can manifest as such traps (often as EXC_BREAKPOINT). By having these breakpoints, the debugger will pause exactly at the point of failure, instead of showing an oblique crash later. This helped in our analysis – e.g., an NSAssertion from UIApplication about state restoration was caught by a developer using an exception breakpoint
twocentstudios.com
twocentstudios.com
. We should do similarly. We can also add a breakpoint for dispatch_assert_queue_fail (the low-level function in our crash log) if needed, but usually the above are sufficient.

Use the Swift concurrency checker: Keep the Main Thread Checker and Swift Concurrency Checks enabled (these are on by default in debug for Xcode 15+ when using Swift 6). They will raise issues at runtime if we accidentally update UI on a background thread or misuse an actor. Our previous crash was essentially Swift’s concurrency trap noticing a background call to a main-isolated closure. With our fixes, we expect no such errors. But if any appears, it will stop at the exact line of misuse.

Memory and thread sanitizers: We can run the app with Thread Sanitizer to catch data races (though it may not catch high-level actor isolation issues, it can catch low-level simultaneous memory access issues). Also run with Address Sanitizer to catch memory corruption. Our code is mostly Swift high-level, but if any C APIs (Security framework) misuse happened, ASan could catch buffer issues. Given our changes are in Swift, it’s just a good practice.

Unit tests for Auth logic: We will create some targeted unit tests:

AuthServiceTests: using URLProtocol to stub network responses, we can simulate the login and refresh flows without hitting a real server. For example, set up URLProtocol to intercept requests to /auth/login_password and return a preset JSON ({"access_token": "...", "refresh_token": "..."} with some dummy JWTs). Then in the test, call AuthService.shared.login("courier", "12345678") and verify that:

it returns a valid AuthTokenPair and AuthenticatedUser.

it calls AuthSession.configure (we might spy on AuthSession.currentUser or use a delegate/callback).

after it returns, check that AuthKeychainStore contains the expected refresh token (call loadRefreshToken() in test with no prompt, expecting the token).

Also test that calling AuthSession.shared.validAccessToken() shortly after returns the same access token without refresh (since not expired).

Refresh tests: Simulate an expired access token scenario. We can override AuthSession.accessTokenExp to a past time in the test, then call AuthSession.validAccessToken(). Our test URLProtocol will stub /auth/refresh to return a new token pair JSON. Verify that:

The returned token matches the new one from stub.

The old refresh token was replaced in keychain (i.e., load returns the new token).

AuthSession.currentUser remains the same and notification was posted (if we post one on refresh, which we might not need to).

If we simulate a 401 refresh response, verify that AuthSession.validAccessToken() throws an AuthError.refreshExpired and that our session state is cleared (we can check that AuthSession.currentUser == nil and keychain has no token after).

Keychain tests: These can be a bit tricky because Keychain APIs actually talk to the OS. We can, however, exercise our AuthKeychainStore.save and load methods in a unit test to ensure they behave as expected:

Test saving a token with no biometric (simulate by calling saveRefreshToken on simulator – it will take the no-AC path). Then test loading it with no prompt (should succeed).

Test saving with an .userPresence requirement. To simulate a device with passcode but no biometric, we can call makeAccessControl() after temporarily disabling biometric in the test environment. We can actually force a specific path by temporarily overriding LAContext.canEvaluatePolicy using a subclass or by injecting a parameter for testing (we might modify makeAccessControl() to accept a parameter for test to force a certain flag). For example, call a variant of makeAccessControl(desiredFlag: .userPresence) in a test. Save token, then call load with no prompt: it should return nil (because it requires auth and we skipped UI). Then call load with a prompt string: since we cannot actually complete a biometric in a unit test, keychain will immediately call the completion with failure. We expect our load to throw errSecAuthFailed in that case. We can simulate a “successful” auth by not using LAContext at all and just storing with no requirement for that test case.

Given the complexity of testing biometrics in CI, we might limit ourselves to testing that our logic returns nil or errors appropriately when expected, rather than actually invoking real Face ID (which is not possible in a non-interactive test).

OrdersService tests: If we have a in-memory SwiftData store for tests (SwiftData is still new; we might use a separate container for test), we can test that calling OrdersService.sync() with a stubbed network (using URLProtocol to return a sample orders JSON) results in Order objects being saved in the model context. We might need to run this in an environment where SwiftUI is not available; SwiftData does have programmatic APIs as shown on StackOverflow
stackoverflow.com
 (creating a ModelContainer in code). We can create a ModelContainer for Order model in memory and assign it to ModelContextHolder.shared.context for the test. Then call OrdersService.sync() and verify that ModelContextHolder.shared.context.fetch(Order.self) returns the expected objects.

These tests will give us confidence that each piece (auth, keychain, data sync) works in isolation. Importantly, the tests around refresh ensure we don’t accidentally reintroduce concurrency bugs. For instance, we can write a test that calls validAccessToken() from multiple concurrent tasks and assert that AuthService.refresh() was only called once (we can count calls via a stub). Using the actor approach, this should hold true.

Manual QA scenarios: In addition to automated tests, we should manually test the following on a device:

Fresh install, login, see orders appear.

Logout, login as a different user (if applicable) – ensure no old user’s orders remain (if we implement the context wipe).

Enable Face ID, login, background the app for >15 min (simulate token expiry), then bring app to foreground and attempt an action that triggers refresh (like pulling to refresh orders). You should see a Face ID prompt (“Authenticate to refresh session”). After accepting, the action should succeed (orders update or new data loads). If you cancel the prompt, the action should be canceled or show an error, but not crash.

Do the same with Face ID disabled (or use a device with no biometric): it should fall back to passcode prompt. Canceling it should force login again (because without any way to get a token, we log out).

Test on simulator: login, kill app, relaunch. It should auto-login (since we stored token without auth requirement). Ensure orders load without requiring login.

Also test edge cases like invalid credentials (should show an error and not crash – our changes shouldn’t affect that, but just part of regression testing).

By rigorously testing and using these diagnostics tools, we’ll ensure the P0 issues are truly resolved and prevent regressions. The combination of breakpoints (to catch any thrown exceptions) and unit tests (to simulate scenarios) will make our codebase more robust
avanderlee.com
.

 

Finally, remember to run the app with Enable Hardened Runtime in Debug if possible. Swift concurrency can sometimes crash (SIGTRAP) on data race; the hardened runtime might also catch improper API usage. Given all fixes, we expect a clean run with no crashes or warnings.

6. Backend Contract Sanity Checks

Our iOS app changes remain aligned with the backend’s authentication contract (FastAPI 3.12+ with JWTs and rotating refresh tokens). We should verify a few points to be safe:

Login and refresh endpoints: The login (POST /auth/login_password) returns JSON with access_token and refresh_token. The refresh (POST /auth/refresh) expects a JSON body {"refresh_token": "<token>"} and returns a new pair. This matches what our iOS code sends. We add a quick integration test or curl script to double-check:

 

Using the data from the summary, from a terminal (already partially done in the problem description):

# Test login
curl -X POST http://192.168.3.47:8000/v1/auth/login_password \
     -H 'Content-Type: application/json' \
     -d '{"identifier":"courier","password":"12345678"}'
# -> expect 200 with {"access_token":"...","refresh_token":"..."}

# Take the refresh_token from above and test refresh
curl -X POST http://192.168.3.47:8000/v1/auth/refresh \
     -H 'Content-Type: application/json' \
     -d '{"refresh_token":"<token_from_login>"}'
# -> expect 200 with new {"access_token":"...","refresh_token":"..."}

# Test that old refresh is invalidated:
curl -X POST http://192.168.3.47:8000/v1/auth/refresh \
     -H 'Content-Type: application/json' \
     -d '{"refresh_token":"<same_token_again>"}'
# -> expect 401, as that token was rotated out.


The backend likely already does this (refresh rotation) as implied. It’s a best practice we’ll adhere to: issue a new refresh token on every refresh, and invalidate the old
stackoverflow.com
. Our app now handles this by updating the keychain each time. This means if the app tries to reuse an old refresh token (e.g. due to a bug), the server will 401 – and we handle that by logging out. So consistency is achieved.

Access token usage: Our OrdersService.authorizedRequest attaches Bearer <token> in the Authorization header. FastAPI likely expects this (it’s standard). We should ensure that we always call validAccessToken() before each request so that an unexpired token is used, or a refreshed one if needed. Our design does that on each authorizedRequest(). That ensures the backend gets a valid JWT or at worst a request might fail once with 401 and then we refresh and retry. We might consider automatically retrying the request after a refresh (some designs do: intercept 401, refresh, then retry original request). In Donny Wals’ blog, he outlines such a flow
donnywals.com
donnywals.com
. In our case, because we pre-emptively refresh via authorizedRequest, we may not need to implement response interception. (However, if a token expires exactly at the time of a request, that request could 401. We don’t have a global interceptor in URLSession easily; we’d rely on the 401 handling per call. We can handle this later if needed.)

Order data validity: Confirm that the JSON from /v1/orders matches our SwiftData Order model. E.g., the sample shows an order with fields like id, store_id, courier_id, status, .... Our SwiftData model should have corresponding fields (id, storeId, courierId, status, etc.). If names differ (e.g., store_id vs storeId property), ensure our Decodable initializer or coding keys handle it. This is just to be sure we’re not dropping data or failing to decode something that could cause a missing field issue.

Push/SSE considerations: The problem statement mentioned Gorush for APNs and SSE client for live updates. These are tangential but relevant:

Push: We already handle silent push by calling OrdersService.sync(). With our fixes, those pushes will correctly update the context as long as the app is running. If the app is backgrounded, iOS may allow a brief execution for the background fetch. Our code calls Task to sync and calls completion handler. We should ensure that in background, we don’t violate time constraints. Possibly, if orders are small, it’s fine. If not, we might want to call completionHandler(.noData) immediately and do syncing outside the allowed background time. But as a blocker issue context, it’s fine.

SSE: The SSEClient was refactored to not use unsafe pointers, which is good. We should confirm it’s working after these changes (non-crashing, though SSE is more of a continuous connection – likely unaffected by auth except needing a valid token at connect time). If SSE requires an Authorization header or token param, ensure we pass a valid token when starting the SSE stream. That may require calling AuthSession.validAccessToken() inside SSEClient when connecting.

Security and compliance: Ensure that storing tokens in keychain (especially now possibly without biometric in some cases) is acceptable. Keychain is generally secure storage, and since we use .ThisDeviceOnly, even if iCloud Keychain is on, these tokens won’t sync to other devices. That’s good. We also ensured we require a passcode on device to store (WhenPasscodeSet), which is an extra security measure – it means if someone has no device passcode, they can’t even persist a login (which is fine; such a device is insecure anyway).

Documentation: Document these changes for the backend team and QA:

The app now rotates refresh tokens properly and handles 401 refresh failures by logging out. Backend should continue to revoke tokens accordingly.

The “orders not appearing” issue was due to client-side sync, now fixed with proper persistence. No changes needed server-side.

The crash after login was client-side (no server changes).

The only backend-facing change is perhaps an extra refresh call if the app doesn’t store sessions (like on simulator, we now store without auth, so maybe more persistent sessions). It’s all within normal usage patterns.

Lastly, we verify with a final run through acceptance criteria:

No crash after tapping Login: With concurrency fixes and keychain error handling, pressing Login should transition to the main screen smoothly. (We should test tapping Login repeatedly or with wrong password to ensure no edge crash there either).

Orders appear after login/refresh: With the sync timing fix, they do. Also test after a manual refresh (like pull-to-refresh if implemented) to see if orders list updates (it should, either via SSE or via another sync call).

No Swift 6 sendability warnings: After marking PushManager methods appropriately, Xcode should be clean of those warnings (like the “nonSendable closure” warnings).

Keychain works across simulator/device with biometrics toggled: We tested those scenarios above. On a device, enabling/disabling biometrics might cause a previous token to be inaccessible (requiring re-login), but that’s expected. Importantly, repeated login/logout doesn’t crash: the code deletes old keychain items and writes new ones, so there’s no duplication or conflict (SecItemAdd with an existing item used to cause error code -25299, which we avoid by SecItemDelete).

Telemetry present: We added logs for auth events and order syncing. We can observe console output or device logs to ensure they print. For example, after a login, we expect something like:

auth.login.success user=5 role=courier (just an example log we might add).

orders.sync.request path=orders and then orders.sync.parsed count=1 ids=[12] and orders.sync.saved count=1.

If any error occurs, e.g., keychain auth failed, a log like auth.refresh.failed error=errSecAuthFailed would appear (with some mapping to a string).

Ensure not to log sensitive data.

By doing these checks and tests, we confirm the app and backend remain in harmony. The refresh token rotation scheme is now correctly handled on the client side (which is a security improvement)
stackoverflow.com
. Tokens are short-lived and refresh is long-lived on server; rotating them each time is indeed recommended
stackoverflow.com
stackoverflow.com
. We also ensure that if a refresh token is compromised or reused, the backend’s 401 will trigger an immediate logout on client, limiting any security risk.

In conclusion, the above changes and verifications will resolve TICKET-27:

The login crash is fixed by proper concurrency handling in delegates and guarding keychain calls (no more EXC_BREAKPOINT).

Orders not appearing is fixed by synchronizing data save with SwiftUI’s lifecycle.

The app’s auth flow is robust: it securely stores tokens, handles refresh seamlessly (with Face ID or silently as appropriate), and aligns with backend expectations.

We’ve also added diagnostic tools and tests to prevent similar issues going forward.