# Ticket: SwiftUIX-02 — Enhanced Text Input with SwiftUIX

Read /Users/sasha/IdeaProjects/ios/zariz/dev/tickets/coding_rules.md first

## 1. Task Summary

**Objective:** Replace standard SwiftUI TextField components with SwiftUIX's enhanced text input components for better UX and functionality.

**Expected Outcome:** Login, order creation, and search fields use SwiftUIX components with improved keyboard handling, validation feedback, and accessibility.

**Success Criteria:**
- All text input fields use `CocoaTextField` or `TextView` from SwiftUIX
- Keyboard dismissal works smoothly
- Input validation provides visual feedback
- Accessibility labels preserved
- No regression in existing functionality

**Go/No-Go Preconditions:**
- SwiftUIX-01 completed
- Existing text fields identified and documented
- Design mockups reviewed (if applicable)

## 2. Assumptions & Scope

**Assumptions:**
- SwiftUIX text components are more feature-rich than standard TextField
- Keyboard handling improvements are noticeable
- No breaking API changes in SwiftUIX

**In Scope:**
- Login screen (email/phone, password)
- Order creation form (recipient name, phone, address fields)
- Search bars in order list

**Out of Scope:**
- Multi-line text editors (covered in SwiftUIX-03)
- Custom keyboard types beyond standard
- Complex form validation logic (keep existing)

**Non-Goals:**
- Redesigning entire forms
- Adding new input fields

**Budgets:**
- p95 keyboard appearance: ≤ 100ms
- Input lag: ≤ 16ms (60fps)

## 3. Architecture Overview

**Components:**
- **LoginView:** Email/phone and password fields
- **NewOrderView:** Recipient details, address fields
- **OrdersListView:** Search bar

**Pattern:** Replace `TextField` with `CocoaTextField`; maintain existing ViewModel bindings.

**Diagram:**
```mermaid
flowchart TD
    A[LoginView] -->|@Binding| B[LoginViewModel]
    A -->|CocoaTextField| C[SwiftUIX]
    D[NewOrderView] -->|@Binding| E[OrderViewModel]
    D -->|CocoaTextField| C
    F[OrdersListView] -->|@State| G[Search Query]
    F -->|SearchBar| C
```

**Key Interfaces:**
- `CocoaTextField`: Drop-in replacement for TextField with enhanced features
- `SearchBar`: Native-like search with cancel button

## 4. Affected Modules/Files

**Files to Modify:**
- `ios/Zariz/Features/Auth/LoginView.swift`: Replace TextField with CocoaTextField
- `ios/Zariz/Features/Orders/NewOrderView.swift`: Replace all input fields
- `ios/Zariz/Features/Orders/OrdersListView.swift`: Add SearchBar component

**Files to Create:**
- `ios/Zariz/Modules/DesignSystem/TextFieldStyles.swift`: Shared styling for CocoaTextField

**Config Files:**
- None

## 5. Implementation Steps

1. **Create Shared TextField Style**
   ```swift
   // ios/Zariz/Modules/DesignSystem/TextFieldStyles.swift
   import SwiftUI
   import SwiftUIX
   
   extension CocoaTextField {
       func zarizStyle() -> some View {
           self
               .font(DS.Font.body)
               .padding(DS.Spacing.md)
               .background(DS.Color.surface)
               .cornerRadius(DS.Radius.medium)
               .overlay(
                   RoundedRectangle(cornerRadius: DS.Radius.medium)
                       .stroke(DS.Color.divider, lineWidth: 1)
               )
       }
   }
   ```

2. **Update LoginView**
   ```swift
   // Before
   TextField("Email or Phone", text: $viewModel.identifier)
       .textContentType(.emailAddress)
       .keyboardType(.emailAddress)
   
   // After
   CocoaTextField("Email or Phone", text: $viewModel.identifier)
       .textContentType(.emailAddress)
       .keyboardType(.emailAddress)
       .zarizStyle()
       .onSubmit { focusPassword() }
   ```

3. **Update NewOrderView**
   ```swift
   // Replace all TextField instances
   CocoaTextField("Recipient First Name", text: $viewModel.firstName)
       .zarizStyle()
       .accessibilityLabel("Recipient first name input")
   
   CocoaTextField("Phone Number", text: $viewModel.phone)
       .keyboardType(.phonePad)
       .zarizStyle()
   ```

4. **Add SearchBar to OrdersListView**
   ```swift
   import SwiftUIX
   
   struct OrdersListView: View {
       @State private var searchText = ""
       
       var body: some View {
           VStack {
               SearchBar("Search orders...", text: $searchText)
                   .showsCancelButton(true)
                   .onCancel { searchText = "" }
               
               // Existing list code
           }
       }
   }
   ```

5. **Add Keyboard Dismissal**
   ```swift
   // In each form view
   .onTapGesture {
       UIApplication.shared.sendAction(
           #selector(UIResponder.resignFirstResponder),
           to: nil, from: nil, for: nil
       )
   }
   ```

6. **Test All Inputs**
   - Verify keyboard types
   - Test tab order (onSubmit)
   - Validate accessibility
   - Check RTL languages

## 6. Interfaces & Contracts

**CocoaTextField API:**
```swift
CocoaTextField(
    _ placeholder: String,
    text: Binding<String>
)
.keyboardType(UIKeyboardType)
.textContentType(UITextContentType)
.onSubmit(() -> Void)
```

**SearchBar API:**
```swift
SearchBar(
    _ placeholder: String,
    text: Binding<String>
)
.showsCancelButton(Bool)
.onCancel(() -> Void)
```

**Backward Compatibility:** Maintains existing @Binding contracts; no ViewModel changes.

## 7. Data Model & Migration

Not applicable (UI only).

## 8. Testing & Validation

**Unit Tests:**
- Verify text binding updates ViewModel
- Test validation logic unchanged

**Integration Tests:**
```swift
// ios/ZarizTests/LoginViewTests.swift
func testCocoaTextFieldBinding() {
    let vm = LoginViewModel()
    let view = LoginView(viewModel: vm)
    
    // Simulate text input
    vm.identifier = "test@example.com"
    XCTAssertEqual(vm.identifier, "test@example.com")
}
```

**UI Tests:**
```swift
// ios/ZarizUITests/LoginFlowTests.swift
func testLoginWithCocoaTextField() {
    let app = XCUIApplication()
    app.launch()
    
    let emailField = app.textFields["Email or Phone"]
    emailField.tap()
    emailField.typeText("courier@test.com")
    
    let passwordField = app.secureTextFields["Password"]
    passwordField.tap()
    passwordField.typeText("password123")
    
    app.buttons["Sign In"].tap()
    
    XCTAssertTrue(app.staticTexts["Orders"].waitForExistence(timeout: 2))
}
```

**Adversarial:**
- Very long input strings (>1000 chars)
- Special characters (emoji, RTL text)
- Rapid keyboard switching
- VoiceOver navigation

## 9. Observability & Operations

**Logging:**
```swift
let log = Logger(subsystem: "app.zariz", category: "ui.input")
log.info("CocoaTextField focused: field=\(fieldName)")
```

**Metrics:**
- Input lag (target: ≤16ms)
- Keyboard appearance time (target: ≤100ms)
- Form completion rate

**Feature Flags:** None required.

**Rollout Plan:** Deploy with next TestFlight build; monitor crash reports.

## 10. Risks & Considerations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Keyboard behavior differences | Medium | Extensive testing on real devices |
| Accessibility regression | High | VoiceOver testing mandatory |
| Performance on older devices | Low | Profile on iPhone 12 (iOS 17) |
| SwiftUIX bugs | Medium | Keep fallback to standard TextField |

**Security:** No PII logged; text fields use secure input for passwords.

**Privacy:** Keyboard input respects system privacy settings.

## 11. Implementation Checklist

- [ ] TextFieldStyles.swift created with zarizStyle()
- [ ] LoginView updated with CocoaTextField
- [ ] NewOrderView all fields replaced
- [ ] OrdersListView SearchBar added
- [ ] Keyboard dismissal implemented
- [ ] Accessibility labels verified
- [ ] Unit tests pass
- [ ] UI tests updated and passing
- [ ] VoiceOver tested on real device
- [ ] RTL languages tested (Arabic, Hebrew)
- [ ] Performance profiled (Instruments)
- [ ] Changes committed with clear message
- [ ] TestFlight build deployed
- [ ] No crash reports after 48h

---

**Estimated Effort:** 4 hours  
**Priority:** P1 (High user impact)  
**Dependencies:** SwiftUIX-01  
**Blocks:** None
