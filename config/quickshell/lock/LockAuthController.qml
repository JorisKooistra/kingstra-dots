import QtQuick

// Eén PAM-conversatie voor alle schermen. abort() geeft geen completed-signaal.
QtObject {
    id: controller
    required property var pam
    signal unlocked()
    property bool failed: false
    property bool authenticating: false
    property bool fingerprintAvailable: false
    property bool fingerprintEnabled: false
    property bool passwordMode: false
    property string pendingPassword: ""
    property string statusText: "Locked"
    property string pamFeedback: ""
    readonly property string fingerprintStatus: "Touch fingerprint"

    function startFingerprintAuth() {
        if (!fingerprintAvailable || authenticating) return;
        pam.abort();
        pendingPassword = "";
        pamFeedback = "";
        failed = false;
        passwordMode = false;
        fingerprintEnabled = true;
        statusText = fingerprintStatus;
        pam.config = "hyprlock";
        if (!pam.start()) authUnavailable();
    }

    function authUnavailable() {
        pendingPassword = "";
        authenticating = false;
        failed = true;
        statusText = "Authentication unavailable — try again";
    }

    function switchToPassword() {
        if (passwordMode) return;
        // abort is synchronous; waiting for completed here strands the input.
        pam.abort();
        fingerprintEnabled = false;
        passwordMode = true;
        pam.config = "login";
        statusText = "Enter password";
    }

    function sendPendingPassword() {
        if (!pam.responseRequired || pam.responseVisible || pendingPassword.length === 0) return;
        let password = pendingPassword;
        pendingPassword = "";
        pam.respond(password);
    }

    function submitPassword(password) {
        if (password.length === 0 || authenticating) return;
        switchToPassword();
        pendingPassword = password;
        authenticating = true;
        failed = false;
        pamFeedback = "";
        statusText = "Authenticating...";
        if (!pam.active) {
            // A fresh conversation starts only after an explicit submission.
            if (!pam.start()) authUnavailable();
        } else {
            sendPendingPassword();
        }
    }

    function handleMessage() {
        if (!pam.responseRequired) {
            let message = pam.message.trim();
            if (/locked|minutes? left|too many|blocked/i.test(message)) {
                pamFeedback = pamFeedback ? pamFeedback + " " + message : message;
                statusText = pamFeedback;
            } else if (!passwordMode && /finger/i.test(message)) {
                statusText = fingerprintStatus;
            }
        }
        sendPendingPassword();
    }

    function complete(success) {
        authenticating = false;
        pendingPassword = "";
        fingerprintEnabled = false;
        if (success) {
            unlocked();
        } else {
            failed = true;
            statusText = pamFeedback || "Access Denied — try again";
            // Never automatically repeat a failed login/fingerprint attempt.
        }
    }
}
