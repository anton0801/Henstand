//
//  AuthService.swift
//  Henstand
//
//  FirebaseAuth email/password gate (§14.1). Cached sessions give offline sign-in
//  after the first successful login. Errors are mapped to plain words.
//  Account deletion re-authenticates, wipes /users/{uid}, then deletes the user.
//

import Foundation
import FirebaseAuth
import FirebaseDatabase

enum AuthPhase: Equatable {
    case notConfigured   // placeholder plist — show setup notice
    case signedOut       // show the form
    case authenticating  // spinner on the button
    case signedIn        // into the Till
}

final class AuthService: ObservableObject {
    @Published private(set) var phase: AuthPhase
    @Published private(set) var uid: String?
    @Published private(set) var email: String = ""
    @Published private(set) var emailVerified: Bool = true
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private var listener: AuthStateDidChangeListenerHandle?

    init() {
        if FirebaseService.isConfigured {
            phase = .signedOut
            listener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
                guard let self else { return }
                if let user {
                    self.uid = user.uid
                    self.email = user.email ?? ""
                    self.emailVerified = user.isEmailVerified
                    self.phase = .signedIn
                } else {
                    self.uid = nil
                    self.phase = .signedOut
                }
            }
        } else {
            phase = .notConfigured
        }
    }

    deinit {
        if let listener { Auth.auth().removeStateDidChangeListener(listener) }
    }

    // MARK: Actions

    func signIn(email: String, password: String) {
        guard validate(email: email, password: password) else { return }
        phase = .authenticating
        errorMessage = nil
        Auth.auth().signIn(withEmail: email, password: password) { [weak self] _, error in
            guard let self else { return }
            if let error {
                self.phase = .signedOut
                self.errorMessage = Self.map(error)
                Haptics.error()
            } else {
                self.infoMessage = nil
                Haptics.success()
                // state listener flips to .signedIn
            }
        }
    }

    func signUp(email: String, password: String) {
        guard validate(email: email, password: password) else { return }
        phase = .authenticating
        errorMessage = nil
        Auth.auth().createUser(withEmail: email, password: password) { [weak self] result, error in
            guard let self else { return }
            if let error {
                self.phase = .signedOut
                self.errorMessage = Self.map(error)
                Haptics.error()
                return
            }
            result?.user.sendEmailVerification(completion: nil)
            self.emailVerified = false
            self.infoMessage = "Account created. We sent a verification link to \(email)."
            Haptics.success()
            // state listener flips to .signedIn
        }
    }

    func sendPasswordReset(email: String) {
        guard !email.isEmpty else { errorMessage = "Enter your email first."; return }
        errorMessage = nil
        Auth.auth().sendPasswordReset(withEmail: email) { [weak self] error in
            guard let self else { return }
            if let error {
                self.errorMessage = Self.map(error)
                Haptics.error()
            } else {
                self.infoMessage = "Password reset link sent to \(email)."
                Haptics.success()
            }
        }
    }

    func resendVerification() {
        Auth.auth().currentUser?.sendEmailVerification { [weak self] error in
            self?.infoMessage = error == nil ? "Verification link sent again." : nil
            if error != nil { self?.errorMessage = "Couldn't resend right now." }
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
            infoMessage = nil
            errorMessage = nil
        } catch {
            errorMessage = "Couldn't sign out."
        }
    }

    /// Full account deletion (§14.1): reauth → wipe RTDB subtree → delete auth user.
    func deleteAccount(password: String, completion: @escaping (String?) -> Void) {
        guard FirebaseService.isConfigured, let user = Auth.auth().currentUser, let email = user.email else {
            completion("You're not signed in.")
            return
        }
        let credential = EmailAuthProvider.credential(withEmail: email, password: password)
        user.reauthenticate(with: credential) { _, error in
            if let error {
                completion(Self.map(error))
                Haptics.error()
                return
            }
            let uid = user.uid
            Database.database().reference().child("users").child(uid).removeValue { _, _ in
                user.delete { deleteError in
                    if let deleteError {
                        completion(Self.map(deleteError))
                        Haptics.error()
                    } else {
                        Haptics.success()
                        completion(nil) // state listener → signedOut
                    }
                }
            }
        }
    }

    // MARK: Helpers

    private func validate(email: String, password: String) -> Bool {
        if email.isEmpty || !email.contains("@") {
            errorMessage = "Enter a valid email address."
            Haptics.error()
            return false
        }
        if password.count < 6 {
            errorMessage = "Password must be at least 6 characters."
            Haptics.error()
            return false
        }
        return true
    }

    static func map(_ error: Error) -> String {
        let ns = error as NSError
        switch AuthErrorCode(rawValue: ns.code) {
        case .wrongPassword, .invalidCredential:
            return "Wrong email or password."
        case .invalidEmail:
            return "That doesn't look like an email address."
        case .emailAlreadyInUse:
            return "That email is already registered — try signing in."
        case .weakPassword:
            return "Password is too short — use at least 6 characters."
        case .userNotFound:
            return "No account found for that email."
        case .networkError:
            return "No connection. Connect once to sign in."
        case .tooManyRequests:
            return "Too many attempts. Give it a minute."
        case .userDisabled:
            return "This account has been disabled."
        case .requiresRecentLogin:
            return "Please sign in again to confirm it's you."
        default:
            return "Something went wrong. Please try again."
        }
    }
}
