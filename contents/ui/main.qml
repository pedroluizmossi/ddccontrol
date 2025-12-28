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
    
    // Brightness properties
    property int maxBrightness: 100
    property int currentBrightness: 50
    property bool isLoadingBrightness: false
    
    // ComboBox selection index
    property int selectedMonitorIndex: 0
    
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
    
    // Timer for brightness detection timeout
    Timer {
        id: brightnessTimeout
        interval: 5000
        running: false
        repeat: false
        onTriggered: {
            console.log("Timeout detecting brightness")
            isLoadingBrightness = false
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
            
            // Check if it's a brightness detection command
            if (sourceName.indexOf("getvcp 10") !== -1) {
                brightnessTimeout.stop()
                if (data.stdout) {
                    parseBrightness(data.stdout)
                } else {
                    console.log("Error getting brightness:", data.stderr)
                    isLoadingBrightness = false
                }
                disconnectSource(sourceName)
                return
            }
            
            // Check if it's a set brightness command
            if (sourceName.indexOf("setvcp 10") !== -1) {
                disconnectSource(sourceName)
                return
            }
            
            // Monitor detection
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
    
    function getBrightness() {
        if (isLoadingBrightness || monitorBus === "") return
        console.log("Getting brightness for bus:", monitorBus)
        isLoadingBrightness = true
        brightnessTimeout.start()
        var cmd = "ddcutil getvcp 10 --bus=" + monitorBus
        executableSource.connectSource(cmd)
    }
    
    function parseBrightness(output) {
        console.log("Parsing brightness output:", output)
        // Example output: "VCP code 0x10 (Brightness): current value = 50, max value = 100"
        var match = output.match(/current value\s*=\s*(\d+).*max value\s*=\s*(\d+)/)
        if (match) {
            maxBrightness = parseInt(match[2])
            currentBrightness = parseInt(match[1])
            console.log("Brightness - Current:", currentBrightness, "Max:", maxBrightness)
        } else {
            console.log("Could not parse brightness values")
        }
        isLoadingBrightness = false
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
            
            // Get brightness values for selected monitor
            getBrightness()
        } else {
            console.log("No monitor with DDC/CI support found")
        }
        
        isLoadingMonitors = false
        loadTimeout.stop()
    }
    
    function updateComboBoxSelection() {
        console.log("Updating ComboBox selection...")
        if (monitorsAvailable.length > 0) {
            for (var k = 0; k < monitorsAvailable.length; k++) {
                if (monitorsAvailable[k].bus === monitorBus && 
                    monitorsAvailable[k].name === monitorName) {
                    selectedMonitorIndex = k
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
                    currentIndex: root.selectedMonitorIndex
                    
                    onActivated: function(index) {
                        if (!root.isLoadingMonitors && index >= 0 && 
                            root.monitorsAvailable.length > index) {
                            root.selectedMonitorIndex = index
                            root.monitorBus = root.monitorsAvailable[index].bus
                            root.monitorName = root.monitorsAvailable[index].name
                            plasmoid.configuration.lastMonitorBus = root.monitorBus
                            plasmoid.configuration.lastMonitorName = root.monitorName
                            // Get brightness for newly selected monitor
                            root.getBrightness()
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
                    to: root.maxBrightness
                    stepSize: root.maxBrightness >= 100 ? 5 : 1
                    value: root.currentBrightness
                    enabled: !root.isLoadingBrightness
                    
                    onPressedChanged: {
                        if (!pressed) root.setBrightness(value)
                    }
                }
                
                PlasmaComponents.Label { 
                    text: Math.round((slider.value / root.maxBrightness) * 100) + "%"
                    Layout.minimumWidth: 40
                    Layout.alignment: Qt.AlignVCenter
                    font.bold: true
                }
            }
            
            // Additional information
            PlasmaComponents.Label {
                text: "DDC/CI Value: " + Math.round(slider.value) + "/" + root.maxBrightness
                font.pixelSize: 10
                opacity: 0.6
                Layout.fillWidth: true
            }
            
            Item { Layout.fillHeight: true }
        }
    }
}
