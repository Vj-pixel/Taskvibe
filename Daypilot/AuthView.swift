// AuthView.swift

import SwiftUI
import UIKit
import GoogleSignIn
import GoogleSignInSwift
import FirebaseAuth
import FirebaseCore
import FirebaseStorage
import AuthenticationServices
import CryptoKit
import FirebaseAppCheck
import PhotosUI

// MARK: - Main Auth Flow

struct AuthFlowView: View {
    @State private var selectedTab: Int = 0
    @State private var showForgotSheet = false

    var onAuthenticated: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.7)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Logo / tagline
                VStack(spacing: 6) {
                    Image(systemName: "metronome.fill")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(colors: [.white, .blue.opacity(0.8)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    Text("Momentum")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Keep your momentum.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(.top, 32)
                .padding(.bottom, 20)

                // Pill tab picker
                Picker("", selection: $selectedTab) {
                    Text("Log In").tag(0)
                    Text("Sign Up").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 28)

                // Content for selected tab
                Group {
                    if selectedTab == 0 {
                        LoginContent(
                            onLogin: onAuthenticated,
                            onForgot: { showForgotSheet = true }
                        )
                        .transition(.asymmetric(
                            insertion: .move(edge: .leading).combined(with: .opacity),
                            removal: .move(edge: .trailing).combined(with: .opacity)
                        ))
                    } else {
                        RegisterContent(onRegister: onAuthenticated)
                            .transition(.asymmetric(
                                insertion: .move(edge: .trailing).combined(with: .opacity),
                                removal: .move(edge: .leading).combined(with: .opacity)
                            ))
                    }
                }
                .frame(maxHeight: .infinity)
                .animation(.easeInOut(duration: 0.25), value: selectedTab)
            }
        }
        .ignoresSafeArea(.keyboard)
        .sheet(isPresented: $showForgotSheet) {
            ForgotPasswordScreen(
                onConfirm: { showForgotSheet = false },
                onBack: { showForgotSheet = false }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Login Content

struct LoginContent: View {
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var generalError: String?
    @State private var isSigningIn = false

    var onLogin: () -> Void
    var onForgot: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        AuthField(icon: "envelope", placeholder: "Email", text: $email, hasError: emailError != nil)
                            .onChange(of: email) { _, _ in emailError = nil; generalError = nil }
                        if let error = emailError {
                            errorText(error)
                        }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        AuthField(icon: "lock", placeholder: "Password", text: $password, isSecure: true, hasError: passwordError != nil)
                            .onChange(of: password) { _, _ in passwordError = nil; generalError = nil }
                        if let error = passwordError {
                            errorText(error)
                        }
                    }
                }

                if let error = generalError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: validateAndSignIn) {
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                    } else {
                        Text("Log In")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
                .disabled(isSigningIn)

                Button(action: onForgot) {
                    Text("Forgot Password?")
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.7))
                }

                socialSection()
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
    }

    @ViewBuilder
    private func socialSection() -> some View {
        VStack(spacing: 12) {
            OrWithDivider()
            ModernGoogleSignInButton { handleGoogleSignIn() }
            ModernAppleSignInButton {
                handleAppleSignIn(onSuccess: onLogin, onError: { generalError = $0 })
            }
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
            .padding(.leading, 16)
    }

    private func validateAndSignIn() {
        emailError = nil; passwordError = nil; generalError = nil
        var isValid = true
        if email.isEmpty { emailError = "Email is required"; isValid = false }
        else if !email.contains("@") || !email.contains(".") { emailError = "Please enter a valid email address"; isValid = false }
        if password.isEmpty { passwordError = "Password is required"; isValid = false }
        else if password.count < 6 { passwordError = "Password must be at least 6 characters"; isValid = false }
        guard isValid else { return }
        signInUser(email: email, password: password)
    }

    private func signInUser(email: String, password: String) {
        isSigningIn = true
        Auth.auth().signIn(withEmail: email, password: password) { _, error in
            isSigningIn = false
            if let error = error as NSError? { handleFirebaseError(error) } else { onLogin() }
        }
    }

    private func handleFirebaseError(_ error: NSError) {
        switch error.code {
        case 17008, 17009:
            emailError = "Invalid email or password"
            passwordError = "Invalid email or password"
        case 17011: emailError = "No account found with this email"
        case 17020: generalError = "Network error. Please check your connection."
        case 17010: generalError = "Too many failed attempts. Please try again later."
        case 17999: passwordError = "Incorrect password. Please try again."
        case 17004:
            emailError = "Invalid email or password"
            passwordError = "Invalid email or password"
        default:
            let msg = error.localizedDescription.lowercased()
            if msg.contains("malformed") || msg.contains("expired") || msg.contains("credential") {
                passwordError = "Incorrect password. Please try again."
            } else {
                generalError = "Authentication failed. Please check your credentials."
            }
        }
    }

    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            generalError = "Unable to access root view controller."
            return
        }
        isSigningIn = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            isSigningIn = false
            if let error = error as NSError? {
                if error.code == 36 || (error.domain == "com.google.GIDSignIn" && error.code == -5) { return }
                generalError = error.localizedDescription; return
            }
            guard let idToken = result?.user.idToken?.tokenString,
                  let accessToken = result?.user.accessToken.tokenString else {
                if result == nil && error == nil { return }
                generalError = "Google sign-in failed: missing token."; return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            Auth.auth().signIn(with: credential) { _, error in
                if let error { generalError = error.localizedDescription } else { onLogin() }
            }
        }
    }

    private func handleAppleSignIn(onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        request.nonce = sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate(onSuccess: onSuccess, onError: onError, currentNonce: nonce)
        AppleSignInManager.shared.currentDelegate = delegate
        controller.delegate = delegate
        let provider = ApplePresentationAnchorProvider()
        AppleSignInManager.shared.presentationProvider = provider
        controller.presentationContextProvider = provider
        controller.performRequests()
    }
}

// MARK: - Register Content

struct RegisterContent: View {
    @State private var name: String = ""
    @State private var email: String = ""
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var nameError: String?
    @State private var emailError: String?
    @State private var passwordError: String?
    @State private var confirmPasswordError: String?
    @State private var generalError: String?
    @State private var isSigningIn = false

    // Avatar photo state
    @State private var selectedAvatarItem: PhotosPickerItem?
    @State private var avatarImage: UIImage?

    var onRegister: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Avatar picker
                PhotosPicker(selection: $selectedAvatarItem, matching: .images, photoLibrary: .shared()) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 84, height: 84)
                        if let img = avatarImage {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 84, height: 84)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(Color.white.opacity(0.4), lineWidth: 2))
                        } else {
                            VStack(spacing: 4) {
                                Image(systemName: "person.badge.plus")
                                    .font(.system(size: 30))
                                    .foregroundColor(.white.opacity(0.7))
                                Text("Add photo")
                                    .font(.caption2)
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }
                    }
                }
                .onChange(of: selectedAvatarItem) { _, item in
                    guard let item else { return }
                    Task {
                        if let data = try? await item.loadTransferable(type: Data.self),
                           let img = UIImage(data: data) {
                            await MainActor.run { avatarImage = img }
                        }
                    }
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        AuthField(icon: "person", placeholder: "Full Name", text: $name, hasError: nameError != nil)
                            .onChange(of: name) { _, _ in nameError = nil; generalError = nil }
                        if let error = nameError { errorText(error) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        AuthField(icon: "envelope", placeholder: "Email", text: $email, hasError: emailError != nil)
                            .onChange(of: email) { _, _ in emailError = nil; generalError = nil }
                        if let error = emailError { errorText(error) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        AuthField(icon: "lock", placeholder: "Password", text: $password, isSecure: true, hasError: passwordError != nil)
                            .onChange(of: password) { _, _ in passwordError = nil; generalError = nil }
                        if let error = passwordError { errorText(error) }
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        AuthField(icon: "lock", placeholder: "Confirm Password", text: $confirmPassword, isSecure: true, hasError: confirmPasswordError != nil)
                            .onChange(of: confirmPassword) { _, _ in confirmPasswordError = nil; generalError = nil }
                        if let error = confirmPasswordError { errorText(error) }
                    }
                }

                if let error = generalError {
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                Button(action: validateAndRegister) {
                    if isSigningIn {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 20)
                    } else {
                        Text("Create Account")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.85))
                .foregroundColor(.white)
                .cornerRadius(12)
                .font(.headline)
                .disabled(isSigningIn)

                VStack(spacing: 12) {
                    OrWithDivider()
                    ModernGoogleSignInButton { handleGoogleSignIn() }
                    ModernAppleSignInButton {
                        handleAppleSignIn(onSuccess: onRegister, onError: { generalError = $0 })
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
    }

    private func errorText(_ message: String) -> some View {
        Text(message)
            .font(.caption)
            .foregroundColor(.red)
            .padding(.leading, 16)
    }

    private func validateAndRegister() {
        nameError = nil; emailError = nil; passwordError = nil
        confirmPasswordError = nil; generalError = nil
        var isValid = true
        if name.isEmpty { nameError = "Name is required"; isValid = false }
        if email.isEmpty { emailError = "Email is required"; isValid = false }
        else if !email.contains("@") || !email.contains(".") { emailError = "Please enter a valid email address"; isValid = false }
        if password.isEmpty { passwordError = "Password is required"; isValid = false }
        else if password.count < 6 { passwordError = "Password must be at least 6 characters"; isValid = false }
        if confirmPassword.isEmpty { confirmPasswordError = "Please confirm your password"; isValid = false }
        else if password != confirmPassword { confirmPasswordError = "Passwords do not match"; isValid = false }
        guard isValid else { return }
        registerUser(name: name, email: email, password: password)
    }

    private func registerUser(name: String, email: String, password: String) {
        isSigningIn = true
        Auth.auth().createUser(withEmail: email, password: password) { result, error in
            if let error = error as NSError? {
                isSigningIn = false
                handleFirebaseError(error)
                return
            }
            guard let userId = result?.user.uid else {
                isSigningIn = false
                onRegister()
                return
            }
            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.displayName = name
            changeRequest?.commitChanges { _ in
                if let image = self.avatarImage,
                   let data = image.jpegData(compressionQuality: 0.5) {
                    Task {
                        do {
                            let ref = Storage.storage().reference().child("profile_images/\(userId).jpg")
                            let meta = StorageMetadata()
                            meta.contentType = "image/jpeg"
                            _ = try await ref.putDataAsync(data, metadata: meta)
                            let url = try await ref.downloadURL()
                            let photoReq = Auth.auth().currentUser?.createProfileChangeRequest()
                            photoReq?.photoURL = url
                            try? await photoReq?.commitChanges()
                        } catch {
                            print("Avatar upload failed: \(error.localizedDescription)")
                        }
                        await MainActor.run {
                            self.isSigningIn = false
                            self.onRegister()
                        }
                    }
                } else {
                    self.isSigningIn = false
                    self.onRegister()
                }
            }
        }
    }

    private func handleFirebaseError(_ error: NSError) {
        switch error.code {
        case 17007: emailError = "This email is already registered"
        case 17008: emailError = "Please enter a valid email address"
        case 17026: passwordError = "Password is too weak. Use a stronger password."
        case 17020: generalError = "Network error. Please check your connection."
        default:    generalError = error.localizedDescription
        }
    }

    private func handleGoogleSignIn() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController else {
            generalError = "Unable to access root view controller."
            return
        }
        isSigningIn = true
        GIDSignIn.sharedInstance.signIn(withPresenting: rootVC) { result, error in
            isSigningIn = false
            if let error = error as NSError? {
                if error.code == 36 || (error.domain == "com.google.GIDSignIn" && error.code == -5) { return }
                generalError = error.localizedDescription; return
            }
            guard let idToken = result?.user.idToken?.tokenString,
                  let accessToken = result?.user.accessToken.tokenString else {
                if result == nil && error == nil { return }
                generalError = "Google sign-in failed: missing token."; return
            }
            let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
            Auth.auth().signIn(with: credential) { _, error in
                if let error { generalError = error.localizedDescription } else { onRegister() }
            }
        }
    }

    private func handleAppleSignIn(onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void) {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        let nonce = randomNonceString()
        request.nonce = sha256(nonce)
        let controller = ASAuthorizationController(authorizationRequests: [request])
        let delegate = AppleSignInDelegate(onSuccess: onSuccess, onError: onError, currentNonce: nonce)
        AppleSignInManager.shared.currentDelegate = delegate
        controller.delegate = delegate
        let provider = ApplePresentationAnchorProvider()
        AppleSignInManager.shared.presentationProvider = provider
        controller.presentationContextProvider = provider
        controller.performRequests()
    }
}

// MARK: - AuthField

struct AuthField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    var hasError: Bool = false

    @State private var isPasswordVisible: Bool = false

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(hasError ? .red : .blue.opacity(0.8))
            if isSecure && !isPasswordVisible {
                SecureField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.6)))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            } else {
                TextField("", text: $text, prompt: Text(placeholder).foregroundColor(.white.opacity(0.6)))
                    .foregroundColor(.white)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
            }
            if isSecure {
                Button(action: { isPasswordVisible.toggle() }) {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(hasError ? Color.red : Color.blue.opacity(0.5), lineWidth: 1.5)
                )
        )
    }
}

// MARK: - Forgot Password Screen

struct ForgotPasswordScreen: View {
    @State private var email: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isCodeSent = false
    @State private var code: [String] = Array(repeating: "", count: 4)
    @FocusState private var focusedIndex: Int?
    @State private var isLoading = false
    @State private var pendingReset: PendingReset? = nil
    @State private var isVerifyingLink = false

    var onConfirm: () -> Void
    var onBack: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.7)]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()
                if !isCodeSent {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Forgot Password")
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                        Text("Enter your email to receive a reset link")
                            .font(.subheadline).foregroundColor(.white.opacity(0.7))
                    }
                    AuthField(icon: "envelope", placeholder: "Email", text: $email)
                    Button(action: {
                        if email.isEmpty {
                            alertMessage = "Please enter your email."
                            showAlert = true
                        } else {
                            sendResetCode(email: email)
                        }
                    }) {
                        Text("Send Reset Link")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.blue.opacity(0.85))
                            .foregroundColor(.white).cornerRadius(12).font(.headline)
                    }
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Check Your Email")
                            .font(.title2).fontWeight(.bold).foregroundColor(.white)
                        Text("A reset link has been sent to \(email)")
                            .font(.subheadline).foregroundColor(.white.opacity(0.7))
                    }
                    Button(action: { handlePastedResetLink() }) {
                        Text("Paste reset link")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.white.opacity(0.12))
                            .foregroundColor(.white).cornerRadius(12).font(.headline)
                    }
                    Button(action: { sendResetCode(email: email) }) {
                        Text("Resend link")
                            .font(.footnote).foregroundColor(.blue).underline()
                    }
                    .alert(isPresented: $showAlert) {
                        Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
                    }
                }
                Button(action: onBack) {
                    Text("Back to Login")
                        .font(.footnote).foregroundColor(.white.opacity(0.7))
                }
                Spacer()
            }
            .padding(.horizontal, 28)
        }
        .sheet(item: $pendingReset) { pending in
            ResetPasswordView(code: pending.code, email: pending.email) {
                pendingReset = nil
                onConfirm()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            checkPasteboardForResetLink()
        }
    }

    private func sendResetCode(email: String) {
        isLoading = true
        Auth.auth().sendPasswordReset(withEmail: email) { error in
            isLoading = false
            if let error {
                alertMessage = error.localizedDescription
                showAlert = true
            } else {
                isCodeSent = true
            }
        }
    }

    private func handlePastedResetLink() {
        guard let pasted = UIPasteboard.general.string, !pasted.isEmpty else {
            alertMessage = "No link found on the clipboard."
            showAlert = true; return
        }
        guard let code = extractOOBCode(from: pasted) else {
            alertMessage = "Could not find a reset code in the pasted link."
            showAlert = true; return
        }
        verifyAndPresent(code: code)
    }

    private func checkPasteboardForResetLink() {
        guard pendingReset == nil else { return }
        guard let pasted = UIPasteboard.general.string,
              let code = extractOOBCode(from: pasted) else { return }
        verifyAndPresent(code: code)
    }

    private func verifyAndPresent(code: String) {
        isVerifyingLink = true
        Auth.auth().verifyPasswordResetCode(code) { email, error in
            isVerifyingLink = false
            if let email {
                pendingReset = PendingReset(code: code, email: email)
            } else {
                alertMessage = error?.localizedDescription ?? "Invalid or expired reset link."
                showAlert = true
            }
        }
    }

    private func extractOOBCode(from urlString: String) -> String? {
        if let url = URL(string: urlString),
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            if let code = components.queryItems?.first(where: { $0.name == "oobCode" })?.value { return code }
            if let linkStr = components.queryItems?.first(where: { $0.name == "link" })?.value,
               let innerURL = URL(string: linkStr),
               let inner = URLComponents(url: innerURL, resolvingAgainstBaseURL: false),
               let code = inner.queryItems?.first(where: { $0.name == "oobCode" })?.value { return code }
        }
        return nil
    }
}

// MARK: - OrWithDivider

struct OrWithDivider: View {
    var body: some View {
        HStack {
            Rectangle().fill(Color.white.opacity(0.18)).frame(height: 1)
            Text("or with").font(.footnote).foregroundColor(.white.opacity(0.7)).padding(.horizontal, 8)
            Rectangle().fill(Color.white.opacity(0.18)).frame(height: 1)
        }
    }
}

// MARK: - Google Sign-In Button

struct ModernGoogleSignInButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Color.white).frame(width: 28, height: 28)
                    GoogleGLogo().frame(width: 16, height: 16)
                }
                Text("Sign in with Google")
                    .fontWeight(.semibold).foregroundColor(.black)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .padding(.horizontal, 18)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.10), radius: 4, x: 0, y: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Apple Sign-In Button

struct ModernAppleSignInButton: View {
    var action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "applelogo")
                    .foregroundColor(.white).font(.system(size: 18, weight: .medium))
                Text("Sign in with Apple")
                    .fontWeight(.semibold).foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.black)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.white.opacity(0.2), lineWidth: 1))
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Google G Logo

struct GoogleGLogo: View {
    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack {
                Path { p in
                    p.addArc(center: CGPoint(x: w/2, y: h/2), radius: w/2, startAngle: .degrees(-45), endAngle: .degrees(45), clockwise: false)
                    p.addLine(to: CGPoint(x: w/2, y: h/2)); p.closeSubpath()
                }.fill(Color(red: 66/255, green: 133/255, blue: 244/255))
                Path { p in
                    p.addArc(center: CGPoint(x: w/2, y: h/2), radius: w/2, startAngle: .degrees(45), endAngle: .degrees(135), clockwise: false)
                    p.addLine(to: CGPoint(x: w/2, y: h/2)); p.closeSubpath()
                }.fill(Color(red: 234/255, green: 67/255, blue: 53/255))
                Path { p in
                    p.addArc(center: CGPoint(x: w/2, y: h/2), radius: w/2, startAngle: .degrees(135), endAngle: .degrees(225), clockwise: false)
                    p.addLine(to: CGPoint(x: w/2, y: h/2)); p.closeSubpath()
                }.fill(Color(red: 251/255, green: 188/255, blue: 5/255))
                Path { p in
                    p.addArc(center: CGPoint(x: w/2, y: h/2), radius: w/2, startAngle: .degrees(225), endAngle: .degrees(315), clockwise: false)
                    p.addLine(to: CGPoint(x: w/2, y: h/2)); p.closeSubpath()
                }.fill(Color(red: 52/255, green: 168/255, blue: 83/255))
            }
        }
    }
}

// MARK: - Apple Sign-In Manager

class AppleSignInManager: ObservableObject {
    static let shared = AppleSignInManager()
    var currentDelegate: AppleSignInDelegate?
    var presentationProvider: ApplePresentationAnchorProvider?
    private init() {}
}

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate {
    let onSuccess: () -> Void
    let onError: (String) -> Void
    let currentNonce: String

    init(onSuccess: @escaping () -> Void, onError: @escaping (String) -> Void, currentNonce: String) {
        self.onSuccess = onSuccess; self.onError = onError; self.currentNonce = currentNonce
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential else {
            onError("Unable to retrieve Apple credentials."); return
        }
        guard !currentNonce.isEmpty else {
            onError("Invalid state: A login callback was received, but no login request was sent."); return
        }
        guard let appleIDToken = appleIDCredential.identityToken,
              let idTokenString = String(data: appleIDToken, encoding: .utf8) else {
            onError("Unable to fetch or serialize identity token"); return
        }
        let credential = OAuthProvider.credential(providerID: .apple, idToken: idTokenString, rawNonce: currentNonce)
        Auth.auth().signIn(with: credential) { authResult, error in
            if let error { self.onError(error.localizedDescription); return }
            if let user = authResult?.user, user.displayName?.isEmpty != false,
               let fullName = appleIDCredential.fullName {
                let changeRequest = user.createProfileChangeRequest()
                changeRequest.displayName = [fullName.givenName, fullName.familyName]
                    .compactMap { $0 }.joined(separator: " ")
                changeRequest.commitChanges { _ in self.onSuccess() }
            } else {
                self.onSuccess()
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let authError = error as NSError
        if authError.code == ASAuthorizationError.canceled.rawValue { return }
        switch authError.code {
        case 1000: onError("Apple Sign-In is not properly configured. Please check your app's capabilities and Apple Developer settings.")
        case 1001: onError("Apple Sign-In request failed. Please try again.")
        case 1002: onError("Apple Sign-In is not supported on this device.")
        case 1003: onError("Apple Sign-In request was not handled.")
        case 1004: onError("Apple Sign-In failed due to system error.")
        default:   onError("Apple Sign-In failed: \(error.localizedDescription)")
        }
    }
}

class ApplePresentationAnchorProvider: NSObject, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first(where: { $0.isKeyWindow }) ?? ASPresentationAnchor()
    }
}

// MARK: - Nonce utilities

func randomNonceString(length: Int = 32) -> String {
    precondition(length > 0)
    let charset: [Character] = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
    var result = ""
    var remainingLength = length
    while remainingLength > 0 {
        let randoms: [UInt8] = (0..<16).map { _ in
            var random: UInt8 = 0
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, 1, &random)
            if errorCode != errSecSuccess { fatalError("Unable to generate nonce. SecRandomCopyBytes failed with OSStatus \(errorCode)") }
            return random
        }
        randoms.forEach { random in
            if remainingLength == 0 { return }
            if random < charset.count { result.append(charset[Int(random)]); remainingLength -= 1 }
        }
    }
    return result
}

func sha256(_ input: String) -> String {
    let inputData = Data(input.utf8)
    let hashedData = SHA256.hash(data: inputData)
    return hashedData.compactMap { String(format: "%02x", $0) }.joined()
}

// MARK: - PendingReset & ResetPasswordView

struct PendingReset: Identifiable, Equatable {
    let id = UUID()
    let code: String
    let email: String
}

struct ResetPasswordView: View {
    let code: String
    let email: String
    var onCompleted: () -> Void

    @State private var newPassword: String = ""
    @State private var confirmPassword: String = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var isLoading = false
    @FocusState private var focusedField: Field?

    enum Field { case newPassword, confirmPassword }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Reset Password for:").foregroundColor(.gray)
                Text(email).font(.headline).foregroundColor(.white)
                SecureField("New Password", text: $newPassword)
                    .textContentType(.newPassword).padding()
                    .background(Color.white.opacity(0.1)).cornerRadius(8).foregroundColor(.white)
                    .focused($focusedField, equals: .newPassword)
                SecureField("Confirm Password", text: $confirmPassword)
                    .textContentType(.newPassword).padding()
                    .background(Color.white.opacity(0.1)).cornerRadius(8).foregroundColor(.white)
                    .focused($focusedField, equals: .confirmPassword)
                Button(action: resetPassword) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(8)
                    } else {
                        Text("Reset Password")
                            .frame(maxWidth: .infinity).padding().background(Color.blue).cornerRadius(8).foregroundColor(.white)
                    }
                }
                .disabled(isLoading)
                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.7)]),
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ).ignoresSafeArea()
            )
            .navigationTitle("Reset Password")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCompleted() }.foregroundColor(.white)
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
            }
        }
    }

    private func resetPassword() {
        guard !newPassword.isEmpty, !confirmPassword.isEmpty else {
            alertMessage = "Please fill in all fields."; showAlert = true; return
        }
        guard newPassword == confirmPassword else {
            alertMessage = "Passwords do not match."; showAlert = true; return
        }
        isLoading = true
        Auth.auth().confirmPasswordReset(withCode: code, newPassword: newPassword) { error in
            isLoading = false
            if let error { alertMessage = error.localizedDescription; showAlert = true }
            else { onCompleted() }
        }
    }
}
