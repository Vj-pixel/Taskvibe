import SwiftUI
import FirebaseAuth
import FirebaseStorage
import PhotosUI
import SwiftData
import GoogleSignIn
import AuthenticationServices
import CryptoKit

struct ProfileView: View {
    // MARK: - Properties

    @AppStorage("isAuthenticated") private var isAuthenticated = true
    @Environment(\.modelContext) private var modelContext

    // Fetch raw daypilots without sorting to avoid compile issues
    @Query private var daypilotsUnsorted: [Daypilot]

    // Computed sorted daypilots with a default for nil dueDate
    private var daypilots: [Daypilot] {
        daypilotsUnsorted.sorted {
            ($0.dueDate ?? Date.distantFuture) < ($1.dueDate ?? Date.distantFuture)
        }
    }

    // User info states
    @State private var displayName = ""
    @State private var email = ""
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var totalTodos: Int?
    @State private var totalCompleted: Int?

    // Profile image states
    @State private var profileImage: UIImage?
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploadingImage = false

    // Account deletion & auth
    @State private var showDeleteAccountAlert = false
    @State private var showReauthSheet = false
    @State private var authProvider = ""

    // MARK: - View Body

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.8)]),
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            contentView
        }
        .onAppear(perform: loadUser)
        .onChange(of: daypilots) { _, _ in updateTaskStats() }
        .alert(isPresented: $showAlert) {
            Alert(title: Text("Error"), message: Text(alertMessage), dismissButton: .default(Text("OK")))
        }
        .alert("Delete Account", isPresented: $showDeleteAccountAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) { showReauthSheet = true }
        } message: {
            Text("Are you sure you want to delete your account? This action cannot be undone. All your tasks and data will be permanently deleted.")
        }
        .sheet(isPresented: $showReauthSheet) {
            ReauthenticationSheet(
                email: email,
                authProvider: authProvider,
                onSuccess: deleteAccount,
                onCancel: { showReauthSheet = false }
            )
        }
    }

    // MARK: - Subviews

    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                avatarView
                userInfoView
                Divider().background(Color.white.opacity(0.3))
                statsView
                Divider().background(Color.white.opacity(0.3))
                streakView
                Divider().background(Color.white.opacity(0.3))
                rankView
                signOutButton
                deleteAccountButton
            }
            .padding()
            .frame(width: 320)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(.ultraThinMaterial)
                    .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.1), lineWidth: 1))
            )
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    private var avatarView: some View {
        ZStack(alignment: .bottomTrailing) {
            Group {
                if let image = profileImage {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                } else {
                    Circle()
                        .fill(Color.white.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 50, height: 50)
                                .foregroundColor(.white)
                        )
                        .overlay(Circle().stroke(Color.white.opacity(0.3), lineWidth: 2))
                }
            }
            .overlay {
                if isUploadingImage {
                    Circle()
                        .fill(Color.black.opacity(0.5))
                        .overlay(ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white)))
                }
            }

            PhotosPicker(selection: $selectedItem, matching: .images, photoLibrary: .shared()) {
                ZStack {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 32, height: 32)
                        .shadow(radius: 2)
                    Image(systemName: "pencil")
                        .foregroundColor(.white)
                        .font(.system(size: 16, weight: .bold))
                }
            }
            .disabled(isUploadingImage)
            .padding(4)
        }
        .frame(width: 100, height: 100)
        .onChange(of: selectedItem) { _, newItem in
            if let newItem {
                Task { await uploadProfileImage(from: newItem) }
            }
        }
    }

    private var userInfoView: some View {
        Group {
            Text(displayName.isEmpty ? "No Name" : displayName)
                .font(.title2.bold())
                .foregroundColor(.white)

            Text(email.isEmpty ? "No Email" : email)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
        }
    }

    private var statsView: some View {
        HStack(spacing: 40) {
            StatView(title: "Total Tasks", value: totalTodos)
            StatView(title: "Completed", value: totalCompleted)
        }
    }

    private var streakView: some View {
        HStack(spacing: 32) {
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                    Text("\(currentTaskStreak)")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                Text("Task Streak")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text("days")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }

            Divider()
                .frame(height: 44)
                .background(Color.white.opacity(0.2))

            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.yellow)
                    Text("\(bestHabitStreak)")
                        .font(.title3.bold())
                        .foregroundColor(.white)
                }
                Text("Best Habit")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
                Text("day streak")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.4))
            }
        }
        .padding(.vertical, 4)
    }

    private var currentTaskStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let completedDays = Set(
            daypilots
                .filter { $0.isCompleted && $0.dueDate != nil && $0.type == .task }
                .map { cal.startOfDay(for: $0.dueDate!) }
        )
        var streak = 0
        var check = today
        while completedDays.contains(check) {
            streak += 1
            check = cal.date(byAdding: .day, value: -1, to: check)!
        }
        return streak
    }

    private var bestHabitStreak: Int {
        daypilots.filter { $0.type == .habit }.map(\.streakCount).max() ?? 0
    }

    private var rankView: some View {
        let completed = totalCompleted ?? 0
        let tier = RankSystem.rank(for: completed)
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: tier.icon)
                    .font(.title2)
                    .foregroundColor(.yellow)
                Text(tier.name)
                    .font(.headline.bold())
                    .foregroundColor(.white)
            }

            if let nextAt = tier.nextAt {
                ProgressView(value: tier.progress(for: completed))
                    .tint(.yellow)
                    .scaleEffect(x: 1, y: 1.6)
                    .padding(.horizontal, 4)
                Text("\(nextAt - completed) tasks to next rank")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
            } else {
                Text("Max rank achieved!")
                    .font(.caption2)
                    .foregroundColor(.yellow.opacity(0.8))
            }
        }
        .padding(.vertical, 4)
    }

    private var signOutButton: some View {
        Button(action: signOut) {
            Text("Sign Out")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.red)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.white.opacity(0.1))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                )
        }
        .padding(.top, 12)
    }

    private var deleteAccountButton: some View {
        Button(action: { showDeleteAccountAlert = true }) {
            Text("Delete Account")
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity)
                .padding()
                .foregroundColor(.white)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.red.opacity(0.8))
                        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 4)
                )
        }
    }

    // MARK: - Methods

    private func loadUser() {
        if let user = Auth.auth().currentUser {
            displayName = user.displayName ?? "No Name"
            email = user.email ?? ""

            if let providerData = user.providerData.first {
                authProvider = providerData.providerID
            }

            if let photoURL = user.photoURL {
                loadProfileImage(from: photoURL)
            }
        }
        updateTaskStats()
    }

    private func loadProfileImage(from url: URL) {
        Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    await MainActor.run { self.profileImage = image }
                }
            } catch {
                print("Failed to load profile image: \(error.localizedDescription)")
            }
        }
    }

    private func uploadProfileImage(from item: PhotosPickerItem) async {
        isUploadingImage = true

        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data),
                  let compressedData = image.jpegData(compressionQuality: 0.5) else {
                await MainActor.run {
                    alertMessage = "Failed to load image."
                    showAlert = true
                    isUploadingImage = false
                }
                return
            }

            await MainActor.run { self.profileImage = image }

            guard let userId = Auth.auth().currentUser?.uid else {
                await MainActor.run { isUploadingImage = false }
                return
            }

            let storageRef = Storage.storage().reference()
            let profileImageRef = storageRef.child("profile_images/\(userId).jpg")

            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"

            _ = try await profileImageRef.putDataAsync(compressedData, metadata: metadata)
            let downloadURL = try await profileImageRef.downloadURL()

            let changeRequest = Auth.auth().currentUser?.createProfileChangeRequest()
            changeRequest?.photoURL = downloadURL
            try await changeRequest?.commitChanges()

            await MainActor.run { isUploadingImage = false }

        } catch {
            await MainActor.run {
                alertMessage = "Failed to upload image: \(error.localizedDescription)"
                showAlert = true
                isUploadingImage = false
            }
        }
    }

    private func updateTaskStats() {
        totalTodos = daypilots.count
        totalCompleted = daypilots.filter { $0.isCompleted }.count
    }

    private func signOut() {
        do {
            try Auth.auth().signOut()
            isAuthenticated = false
        } catch {
            alertMessage = error.localizedDescription
            showAlert = true
        }
    }

    private func deleteAccount() {
        guard let user = Auth.auth().currentUser else { return }

        Task {
            do {
                for task in daypilots {
                    modelContext.delete(task)
                }
                try? modelContext.save()

                let storageRef = Storage.storage().reference()
                let profileImageRef = storageRef.child("profile_images/\(user.uid).jpg")
                try? await profileImageRef.delete()

                try await user.delete()

                await MainActor.run { isAuthenticated = false }
            } catch let error as NSError {
                await MainActor.run {
                    if error.code == AuthErrorCode.requiresRecentLogin.rawValue {
                        alertMessage = "Please sign in again to delete your account."
                        showAlert = true
                        showReauthSheet = true
                    } else {
                        alertMessage = "Failed to delete account: \(error.localizedDescription)"
                        showAlert = true
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct StatView: View {
    var title: String
    var value: Int?

    var body: some View {
        VStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Text(value == nil ? "— —" : "\(value!)")
                .font(.title3.bold())
                .foregroundColor(.white)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: Daypilot.self, inMemory: true)
}

// MARK: - ReauthenticationSheet and Delegate remain unchanged, organized below your main view code

struct ReauthenticationSheet: View {
    let email: String
    let authProvider: String
    var onSuccess: () -> Void
    var onCancel: () -> Void

    @State private var password = ""
    @State private var isAuthenticating = false
    @State private var errorMessage = ""
    @Environment(\.dismiss) private var dismiss

    var isPasswordProvider: Bool {
        authProvider == "password"
    }

    var providerName: String {
        switch authProvider {
        case "google.com": return "Google"
        case "apple.com": return "Apple"
        default: return "your provider"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.red)

                    Text("Confirm Your Identity")
                        .font(.title2.bold())
                        .foregroundColor(.white)

                    if isPasswordProvider {
                        Text("Please enter your password to delete your account")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    } else {
                        Text("Please sign in with \(providerName) to confirm account deletion")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    Text(email)
                        .font(.body)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.white.opacity(0.1))
                        )

                    if isPasswordProvider {
                        Text("Password")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                            .padding(.top, 8)

                        SecureField("Enter your password", text: $password)
                            .foregroundColor(.white)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red.opacity(0.5), lineWidth: 1.5)
                                    )
                            )
                    }
                }
                .padding(.horizontal)

                if !errorMessage.isEmpty {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal)
                }

                VStack(spacing: 12) {
                    Button(action: {
                        reauthenticateAndDelete()
                    }) {
                        if isAuthenticating {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .frame(maxWidth: .infinity)
                                .frame(height: 20)
                        } else {
                            HStack {
                                if !isPasswordProvider {
                                    if authProvider == "google.com" {
                                        Image(systemName: "g.circle.fill")
                                    } else if authProvider == "apple.com" {
                                        Image(systemName: "applelogo")
                                    }
                                }
                                Text(isPasswordProvider ? "Delete My Account" : "Sign in with \(providerName)")
                                    .fontWeight(.semibold)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .disabled((isPasswordProvider && password.isEmpty) || isAuthenticating)
                    .opacity((isPasswordProvider && password.isEmpty) ? 0.6 : 1.0)

                    Button(action: {
                        dismiss()
                        onCancel()
                    }) {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.2))
                            )
                    }
                }
                .padding(.horizontal)

                Spacer()
            }
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.blue.opacity(0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func reauthenticateAndDelete() {
        guard let user = Auth.auth().currentUser else { return }

        isAuthenticating = true
        errorMessage = ""

        if isPasswordProvider {
            let credential = EmailAuthProvider.credential(withEmail: email, password: password)

            user.reauthenticate(with: credential) { _, error in
                isAuthenticating = false

                if let error = error {
                    errorMessage = error.localizedDescription
                } else {
                    dismiss()
                    onSuccess()
                }
            }
        } else if authProvider == "google.com" {
            // Add Google reauth here if needed
        } else if authProvider == "apple.com" {
            // Add Apple reauth here if needed
        }
    }
}
