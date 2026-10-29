import QtQuick
import QtTest
import "../../../config/quickshell/lock"

Item {
    QtObject {
        id: pam
        property bool active: false
        property bool responseRequired: false
        property bool responseVisible: false
        property string config: "login"
        property string message: ""
        property int starts: 0
        property int aborts: 0
        property var responses: []
        property bool startWorks: true
        function start() { starts++; active = startWorks; return active; }
        // Real PamContext.abort() deliberately emits no completed signal.
        function abort() { aborts++; active = false; responseRequired = false; }
        function respond(value) { responses = responses.concat([value]); }
    }
    LockAuthController { id: auth; pam: pam }
    SignalSpy { id: unlocks; target: auth; signalName: "unlocked" }
    TestCase {
        name: "LockAuth"
        function init() {
            pam.active = false; pam.responseRequired = false; pam.responseVisible = false;
            pam.config = "login"; pam.message = ""; pam.starts = 0; pam.aborts = 0;
            pam.responses = []; pam.startWorks = true;
            auth.failed = false; auth.authenticating = false; auth.passwordMode = false;
            auth.fingerprintAvailable = false; auth.fingerprintEnabled = false;
            auth.pendingPassword = ""; auth.pamFeedback = ""; unlocks.clear();
        }
        function prompt() {
            pam.responseRequired = true; pam.message = "Password:"; auth.handleMessage();
        }
        function test_switch_does_not_wait_for_aborted_completion() {
            auth.fingerprintAvailable = true; auth.startFingerprintAuth();
            compare(pam.config, "hyprlock"); verify(pam.active);
            auth.switchToPassword();
            compare(pam.config, "login"); verify(auth.passwordMode); verify(!pam.active);
            auth.submitPassword("dummy"); prompt();
            compare(pam.responses, ["dummy"]);
        }
        function test_first_submission_waits_for_prompt_and_sends_once() {
            auth.submitPassword("test-only");
            compare(pam.starts, 1); compare(pam.responses.length, 0);
            prompt(); prompt();
            compare(pam.responses, ["test-only"]); compare(auth.pendingPassword, "");
            auth.submitPassword("duplicate"); compare(pam.starts, 1);
        }
        function test_failure_does_not_retry_and_next_enter_starts_fresh() {
            auth.submitPassword("first"); prompt(); pam.active = false; auth.complete(false);
            compare(pam.starts, 1); verify(auth.failed); compare(auth.pendingPassword, "");
            auth.submitPassword("second"); prompt();
            compare(pam.starts, 2); compare(pam.responses, ["first", "second"]);
        }
        function test_fingerprint_failure_does_not_loop() {
            auth.fingerprintAvailable = true; auth.startFingerprintAuth();
            pam.active = false; auth.complete(false);
            compare(pam.starts, 1); verify(!auth.fingerprintEnabled);
            auth.submitPassword("dummy"); prompt();
            compare(pam.config, "login"); compare(pam.responses, ["dummy"]);
        }
        function test_lockout_message_survives_next_prompt_and_failure() {
            auth.submitPassword("dummy");
            pam.message = "The account is locked due to 3 failed logins."; auth.handleMessage();
            pam.message = "(10 minutes left to unlock)"; auth.handleMessage();
            prompt(); pam.active = false; auth.complete(false);
            verify(auth.statusText.indexOf("10 minutes") >= 0);
            verify(auth.statusText.indexOf("account is locked") >= 0);
            compare(unlocks.count, 0);
        }
        function test_start_failure_does_not_leave_busy_or_keep_password() {
            pam.startWorks = false; auth.submitPassword("dummy");
            verify(!auth.authenticating); verify(auth.failed); compare(auth.pendingPassword, "");
        }
        function test_only_success_unlocks() {
            auth.complete(false); compare(unlocks.count, 0);
            auth.complete(true); compare(unlocks.count, 1);
        }
    }
}
