# DDC Brightness Control - Plasmoid

Um widget KDE Plasma que controla o brilho dos monitores via protocolo DDC-CI.

## Requisitos

- KDE Plasma 6.0+
- `ddcutil` instalado no sistema
- Permissões adequadas para acessar os dispositivos I2C

### Passo 1: Instalar dependências do sistema

**Fedora/RHEL:**
```bash
sudo dnf install ddcutil
```

**Debian/Ubuntu:**
```bash
sudo apt install ddcutil
```

**Arch Linux:**
```bash
sudo pacman -S ddcutil
```

### Passo 2: Configurar permissões (opcional, mas recomendado)

Se receber erro de permissão ao usar ddcutil:
```bash
# Adicione seu usuário ao grupo i2c
sudo usermod -a -G i2c $USER

# Faça logout e login novamente
```

Ou alternativamente, use `sudo` ao executar ddcutil:
```bash
ddcutil detect --sudo
```

### Passo 3: Clonar o repositório

```bash
# Clone para uma pasta temporária
git clone https://github.com/seu-usuario/com.pedroluizmossi.ddccontrol.git
cd com.pedroluizmossi.ddccontrol
```

### Passo 4: Instalar o Plasmoid

```bash
# Crie o diretório se não existir
mkdir -p ~/.local/share/plasma/plasmoids

# Copie o plasmoid para a pasta correta
cp -r . ~/.local/share/plasma/plasmoids/com.pedroluizmossi.ddccontrol/
```

### Passo 5: Reiniciar o Plasma Shell

```bash
# Reinicie o Plasma Shell para carregar o novo widget
kquitapp plasmashell && kstart5 plasmashell &
```

### Passo 6: Adicionar o widget ao painel

1. Clique com botão direito no painel do Plasma
2. Selecione "Editar painel"
3. Procure por "DDC Brightness"
4. Adicione à sua barra de tarefas

### Verificação

Após instalar, você pode verificar se tudo está funcionando:

```bash
# Teste se ddcutil está funcionando
ddcutil detect

# Você deve ver uma lista de monitores conectados com suporte DDC-CI
```

## Uso

1. Adicione o widget ao seu painel do Plasma
2. O widget detectará automaticamente os monitores conectados que suportam DDC-CI
3. Use o dropdown para selecionar qual monitor controlar
4. Use o slider para ajustar o brilho
5. Clique no botão de atualização (🔄) para redetectar monitores

## Estrutura do Projeto

```
com.pedroluizmossi.ddccontrol/
├── metadata.json          # Metadados do Plasmoid
├── contents/
│   ├── config/
│   │   └── config.ui      # Interface de configuração
│   └── ui/
│       └── main.qml       # Interface principal (QML)
├── README.md              # Este arquivo
└── .gitignore             # Arquivos a ignorar no git
```

## Funcionalidades

- ✅ Detectar automaticamente monitores com suporte DDC-CI
- ✅ Selecionar qual monitor controlar
- ✅ Ajustar brilho via slider
- ✅ Memorizar última seleção de monitor
- ✅ Redetectar monitores com botão de atualização
- ✅ Timeout de detecção (6 segundos)

## Resolução de problemas

**Erro: "ddcutil not found"**
- Verifique se ddcutil foi instalado corretamente
- Rode `which ddcutil` para confirmar o caminho

**Widget não detecta monitores**
- Teste `ddcutil detect` no terminal
- Verifique se tem permissões suficientes
- Adicione seu usuário ao grupo i2c: `sudo usermod -a -G i2c $USER` (requer logout/login)
- Verifique se o monitor suporta DDC-CI

**Widget carregando infinitamente**
- Teste `ddcutil detect` no terminal
- Verifique se tem permissões suficientes

**Slider não controla o brilho**
- Teste manualmente: `ddcutil setvcp 10 50 --bus=XX` (substitua XX pelo número do bus)

**Nenhum monitor detectado**
- Nem todos os monitores suportam DDC-CI
- Conecte o monitor diretamente (não via USB-C ou docks)
- Verifique se o monitor está ligado

## Desinstalação

Se precisar remover o widget:

```bash
rm -rf ~/.local/share/plasma/plasmoids/com.pedroluizmossi.ddccontrol
# Reinicie o Plasma Shell
kquitapp plasmashell && kstart5 plasmashell &
```

## Autor

Pedro Luiz Mossi

## Licença

MIT
