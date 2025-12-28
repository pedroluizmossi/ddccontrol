import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components 3.0 as PlasmaComponents
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.core as PlasmaCore

PlasmoidItem {
    id: root
    
    // Monitor selecionado
    property string monitorBus: ""
    property string monitorName: ""
    property var monitorsAvailable: []
    property bool isLoadingMonitors: false
    
    // Timer para timeout
    Timer {
        id: loadTimeout
        interval: 6000
        running: false
        repeat: false
        onTriggered: {
            console.log("Timeout na detecção de monitores")
            isLoadingMonitors = false
        }
    }
    
    // Largura/altura preferida para modo compacto
    preferredRepresentation: compactRepresentation

    // Motor para execução de comandos shell
    Plasma5Support.DataSource {
        id: executableSource
        engine: "executable"
        connectedSources: []
        
        onNewData: function(sourceName, data) {
            console.log("Comando executado:", sourceName)
            loadTimeout.stop()
            
            if (data.stdout) {
                console.log("Detectando monitores...")
                parseMonitors(data.stdout)
            } else if (data.stderr) {
                console.log("Erro ddcutil:", data.stderr)
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
        console.log("Executando:", cmd)
        executableSource.connectSource(cmd)
    }
    
    function detectMonitors() {
        if (isLoadingMonitors) return
        console.log("Iniciando detecção de monitores...")
        isLoadingMonitors = true
        loadTimeout.start()
        executableSource.connectSource("ddcutil detect")
    }
    
    function parseMonitors(output) {
        var monitors = []
        var lines = output.split("\n")
        var currentBus = ""
        var currentModel = ""
        
        console.log("Parsing monitores...")
        
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
        
        console.log("Monitores encontrados:", JSON.stringify(monitors))
        
        if (monitors.length > 0) {
            monitorsAvailable = monitors
            
            // Restaura a seleção anterior
            var savedBus = plasmoid.configuration.lastMonitorBus
            var savedName = plasmoid.configuration.lastMonitorName
            var found = false
            
            console.log("Buscando monitor salvo - Bus:", savedBus, "Nome:", savedName)
            
            for (var j = 0; j < monitors.length; j++) {
                if (monitors[j].bus === savedBus && monitors[j].name === savedName) {
                    monitorBus = savedBus
                    monitorName = savedName
                    found = true
                    console.log("Monitor salvo encontrado!")
                    break
                }
            }
            
            // Se não encontrou, usa o primeiro
            if (!found) {
                monitorBus = monitors[0].bus
                monitorName = monitors[0].name
                plasmoid.configuration.lastMonitorBus = monitorBus
                plasmoid.configuration.lastMonitorName = monitorName
                console.log("Usando primeiro monitor:", monitorBus, monitorName)
            }
            
            // Sincroniza o ComboBox
            updateComboBoxSelection()
        } else {
            console.log("Nenhum monitor com suporte DDC/CI encontrado")
        }
        
        isLoadingMonitors = false
        loadTimeout.stop()
    }
    
    function updateComboBoxSelection() {
        console.log("Atualizando seleção do ComboBox...")
        if (monitorSelector && monitorsAvailable.length > 0) {
            for (var k = 0; k < monitorsAvailable.length; k++) {
                if (monitorsAvailable[k].bus === monitorBus && 
                    monitorsAvailable[k].name === monitorName) {
                    monitorSelector.currentIndex = k
                    console.log("ComboBox atualizado para index:", k)
                    return
                }
            }
        }
    }
    
    Component.onCompleted: {
        console.log("Widget iniciado")
        detectMonitors()
    }

    // Representação compacta: ícone na barra de tarefas
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

    // Representação completa: Seletor de monitor + Slider
    fullRepresentation: Item {
        width: 350
        height: 180
        
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 12
            spacing: 10
            
            // Seletor de monitor
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
                        ["Carregando..."] : 
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
            
            // Informações do monitor selecionado
            PlasmaComponents.Label {
                text: "Controle de Brilho"
                font.bold: true
                font.pixelSize: 12
                Layout.fillWidth: true
                opacity: 0.8
            }
            
            // Slider de brilho
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
            
            // Informações adicionais
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
