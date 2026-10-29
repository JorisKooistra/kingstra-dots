import QtQuick
import QtTest
import "../../../config/sddm/themes/kingstra"

Item {
    width: 1920; height: 1080
    property var config: ({background: ""})
    property var keyboard: ({layouts: [{shortName: "US intl"}], currentLayout: 0})
    property var userModel: ({count: 1, lastUser: "test-user",
        index: function(i, c) { return i; }, data: function(i, role) { return "test-user"; }})
    property var sessionModel: ({lastIndex: 0,
        index: function(i, c) { return i; }, data: function(i, role) { return "Hyprland"; }})
    property var sddm: mockSddm
    QtObject {
        id: mockSddm
        property string facesDir: "/nonexistent-kingstra-test"
        property string submitted: ""
        signal loginSucceeded()
        signal loginFailed()
        function login(user, password, session) { submitted = password; }
    }
    Main { id: greeter; anchors.fill: parent }
    TestCase {
        name: "SddmInput"
        when: windowShown
        function test_first_key_reaches_password() {
            wait(100);
            verify(!greeter.inputActive);
            keyClick(Qt.Key_A);
            verify(greeter.inputActive);
            keyClick(Qt.Key_B);
            keyClick(Qt.Key_Return);
            compare(mockSddm.submitted, "ab");
        }
    }
}
