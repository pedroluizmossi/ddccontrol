import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    
    // Selected monitor
    property string monitorBus: ""
    property string monitorName: ""
    property var monitorsAvailable: []
    property bool isLoadingMonitors: false
    
    // Timer for timeout
    Timer {
        id: loadTimeout
        interval: 6000
        running: false
        repeat: false
        onTriggered: {
            console.log("Timeout detecting monitors")
            isLoadingMonitors = false
        }
    }
    
    // Preferred width/height for compact mode
    preferredRepresentation: compactRepresentation

    // Engine for executing shell commands
    Plasma5Support.DataSource {
        id: executableSource
        engine: "executable"
        connectedSources: []
        
        onNewData: function(sourceName, data) {
            console.log("Command executed:", sourceName)
            loadTimeout.stop()
            
            if (data.stdout) {
                console.log("Detecting monitors...")
                parseMonitors(data.stdout)
            } else if (data.stderr) {
                console.log("ddcutil error:", data.stderr)
                isLoadingMonitors = false
            } else {
                isLoadingMonitors = false
            }
            
            disconnectSource(sourceName)
        }
    }

    function setBrightness(value) {
        var valInt = Math.round(value)
        var cmd = "ddcutil setvcp 10 " + valInt + " --bus=" + root.monitorBus + " --noverify"
        console.log("Executing:", cmd)
        executableSource.connectSource(cmd)
    }
    
    function detectMonitors() {
        if (isLoadingMonitors) return
        console.log("Starting monitor detection...")
        isLoadingMonitors = true
        loadTimeout.start()
        executableSource.connectSource("ddcutil detect")
    }
    
    function parseMonitors(output) {
        var monitors = []
        var lines = output.split("\n")
        var currentBus = ""
        var currentModel = ""
        
        console.log("Parsing monitors...")
        
        for (var i = 0; i < lines.length; i++) {
            var line = lines[i]
            
            if (line.match(/^Display \d+/)) {
                if (currentBus !== "" && currentModel !== "") {
                    monitors.push({
                        bus: currentBus,
                        name: currentModel
                    })
                }
                currentModel = ""
                currentBus = ""
            }
            
            if (line.match(/I2C bus:.*\/dev\/i2c-/)) {
                var match = line.match(/\/dev\/i2c-(\d+)/)
                if (match) {
                    currentBus = match[1]
                }
            }
            
            if (line.match(/Model:\s*/)) {
                var match = line.match(/Model:\s+(.+)$/)
                if (match) {
                    currentModel = match[1].trim()
                }
            }
        }
        
        if (currentBus !== "" && currentModel !== "") {
            monitors.push({
                bus: currentBus,
                name: currentModel
            })
        }
        
        console.log("Monitors found:", JSON.stringify(monitors))
        
        if (monitors.length > 0) {
            monitorsAvailable = monitors
            
            // Restore previous selection
            var savedBus = plasmoid.configuration.lastMonitorBus
            var savedName = plasmoid.configuration.lastMonitorName
            var found = false
            
            console.log("Looking for saved monitor - Bus:", savedBus, "Name:", savedName)
            
            for (var j = 0; j < monitors.length; j++) {
                if (monitors[j].bus === savedBus && monitors[j].name === savedName) {
                    monitorBus = savedBus
                    monitorName = savedName
                    found = true
                    console.log("Saved monitor found!")
                    break
                }
            }
            
            // If not found, use the first
            if (!found) {
                monitorBus = monitors[0].bus
                monitorName = monitors[0].name
                plasmoid.configuration.lastMonitorBus = monitorBus
                plasmoid.configuration.lastMonitorName = monitorName
                console.log("Using first monitor:", monitorBus, monitorName)
            }
            
            // Sincroniza o ComboBox
            updateComboBoxSelection()
        } else {
            console.log("No monitor with DDC/CI support found")
        }
        
        isLoadingMonitors = false
        loadTimeout.stop()
    }
    
    function updateComboBoxSelection() {
        console.log("Updating ComboBox selection...")
        if (monitorSelector && monitorsAvailable.length > 0) {
            for (var k = 0; k < monitorsAvailable.length; k++) {
                if (monitorsAvailable[k].bus === monitorBus && 
                    monitorsAvailable[k].name === monitorName) {
                    monitorSelector.currentIndex = k
                    console.log("ComboBox updated to index:", k)
                    return
                }
            }
        }
    }
    
    Component.onCompleted: {
        console.log("Widget started")
        detectMonitors()
    }

    // Compact representation: system tray icon
    compactRepresentation: Item {
        PlasmaComponents.Label {
            anchors.centerIn: parent
            text: "🔆"
            font.pixelSize: 18
            
            MouseArea {
                anchors.fill: parent
                onClicked: root.expanded = !root.expanded
            }
        }
    }

    // Full representation: Monitor selector + Slider
    fullRepresentation: Item {
        width: 350
        height: 180
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            
            // Monitor selector
            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                
                PlasmaComponents.Label {
                    text: "Monitor:"
                    font.bold: true
                }
                
                PlasmaComponents.ComboBox {
                    id: monitorSelector
                    Layout.fillWidth: true
                    model: root.isLoadingMonitors ? 
                        ["Loading..."] : 
                        root.monitorsAvailable.map(m => m.name + " (Bus " + m.bus + ")")
                    enabled: !root.isLoadingMonitors && root.monitorsAvailable.length > 0
                    
                    onCurrentIndexChanged: {
                        if (!root.isLoadingMonitors && currentIndex >= 0 && 
                            root.monitorsAvailable.length > currentIndex) {
                            root.monitorBus = root.monitorsAvailable[currentIndex].bus
                            root.monitorName = root.monitorsAvailable[currentIndex].name
                            plasmoid.configuration.lastMonitorBus = root.monitorBus
                            plasmoid.configuration.lastMonitorName = root.monitorName
                        }
                    }
                }
                
                PlasmaComponents.Button {
                    text: root.isLoadingMonitors ? "⏳" : "🔄"
                    implicitWidth: 30
                    enabled: !root.isLoadingMonitors
                    onClicked: root.detectMonitors()
                }
            }
            
            // Selected monitor information
            PlasmaComponents.Label {
                text: "Brightness Control"
                font.bold: true
                font.pixelSize: 12
                Layout.fillWidth: true
                opacity: 0.8
            }
            
            // Brightness slider
            RowLayout {
                spacing: 10
                Layout.fillWidth: true
                
                PlasmaComponents.Label { 
                    text: "☀" 
                    font.pixelSize: 16
                    Layout.alignment: Qt.AlignVCenter
                }

                PlasmaComponents.Slider {
                    id: slider
                    Layout.fillWidth: true
                    from: 0
                    to: 50
                    stepSize: 5
                    value: 25
                    
                    onPressedChanged: {
                        if (!pressed) root.setBrightness(value)
                    }
                }
                
                PlasmaComponents.Label { 
                    text: Math.round((slider.value / 50) * 100) + "%"
                    Layout.minimumWidth: 40
                    Layout.alignment: Qt.AlignVCenter
                    font.bold: true
                }
            }
            
            // Additional information
            PlasmaComponents.Label {
                text: "DDC/CI Value: " + Math.round(slider.value) + "/50"
                font.pixelSize: 10
                opacity: 0.6
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }
        }
    }
}
