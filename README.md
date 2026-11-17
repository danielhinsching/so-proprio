# so-proprio

Sistema leve do Daniel para o Acer Aspire A315-42 (HD mecânico), montado aos poucos sobre um Debian estável mínimo.

A ideia: instalar só a base, e depois adicionar um grupo de cada vez com `./add <grupo>`. Rodar o mesmo grupo de novo não estraga nada.

## Fase 0: instalar a base

> A instalação **apaga o disco**. Não comece sem o passo 1 conferido.

1. **Backup.** Copie a pasta pessoal (`/home/daniel`) para um disco externo ou pendrive e **abra alguns arquivos da cópia** para conferir. Não esqueça: chaves SSH (`~/.ssh`), configurações do Git (`~/.gitconfig`), repositórios com commits não enviados (`git status` / `git log origin/HEAD..` em cada um), arquivos `.env` e VMs que você queira manter.
2. **Baixar o Debian estável** (imagem `netinst` amd64 em <https://www.debian.org/distrib/>) e conferir o checksum:
   ```bash
   sha256sum -c SHA256SUMS --ignore-missing
   ```
3. **Gravar no pendrive** (troque `sdX` pelo pendrive, confira com `lsblk`):
   ```bash
   sudo dd if=debian-*-amd64-netinst.iso of=/dev/sdX bs=4M status=progress oflag=sync
   ```
4. **Instalar.** No BIOS, dê boot pelo pendrive (no Acer, F12 no boot; se não aparecer, habilite o *F12 Boot Menu* no F2).
   - Particionamento **manual**:
     | Partição | Tamanho | Tipo | Montagem |
     |---|---|---|---|
     | EFI | 512 MB | EFI System | `/boot/efi` |
     | raiz | 80–100 GB (**primeira** depois da EFI: início do disco é mais rápido) | ext4 | `/` |
     | swap | 2 GB | swap | — |
     | home | o restante | ext4 | `/home` |
   - Em "Seleção de software", marque **somente** "utilitários padrão do sistema". Desmarque ambiente de desktop.
   - Deixe a senha de root **em branco** para que seu usuário ganhe `sudo`.
   - Wi-Fi: se o instalador pedir firmware, o netinst oficial já traz os firmwares non-free. Se não conectar, use cabo.
5. **Primeiro boot** (tela de texto, faça login):
   ```bash
   sudo apt update && sudo apt install -y git
   git clone https://github.com/danielhinsching/so-proprio.git
   cd so-proprio
   ./add base
   ./add tuning
   sudo reboot
   ```
6. **Rede depois do reboot:** `nmtui` (menu em texto) para conectar no Wi-Fi.

## Fase 1: adicionar o resto aos poucos

```bash
./add               # lista os grupos
./add --dry-run dev # mostra o que seria instalado, sem instalar
./add dev           # instala (pede confirmação; --yes pula)
```

| Grupo | O que traz |
|---|---|
| `base` | sudo, NetworkManager (com Wi-Fi), git, curl, gnupg, htop, zram; comenta o `/etc/network/interfaces` para o NetworkManager assumir a rede (original em `interfaces.so-proprio.bak`) |
| `tuning` | ajustes de HD: `noatime`, `swappiness=10`, zram (zstd, 25%), agendador `bfq`, `GRUB_TIMEOUT=1` (menu do GRUB espera 1 s), desativa CUPS/Avahi/ModemManager se existirem |
| `desktop` | LXQt + Openbox, LightDM, QTerminal, PCManFM-Qt, gerenciamento de energia, Conky com `free -h` e `systemd-analyze` no canto superior direito da tela |
| `visual` | visual limpo (estilo macOS/Windows 11): tema claro, ícones Papirus, fonte Inter, janelas planas, papel de parede suave, dock própria (menu e janelas abertas); barra em cima com rede, Bluetooth, bateria, volume e hora), 1 área de trabalho e atalhos: **Ctrl+Alt+T** terminal, **Ctrl+Alt+F** Firefox, **Ctrl+Alt+C** VS Code |
| `navegador` | Firefox ESR com preferências de baixo consumo (cache em memória, menos processos), uBlock Origin e sem telemetria |
| `dev` | Python (venv, pipx), build-essential, VS Code (repositório Microsoft), fnm para Node.js |
| `vm` | VirtualBox (repositório Oracle). Opcional |
| `claude` | Claude Code no terminal (instalador oficial) |

Ordem sugerida: `base` → `tuning` → `desktop` → `visual` → `navegador` → `dev` → `claude` (e `vm`, se precisar).

Para atualizar um sistema que já está instalado: `git pull`, depois `./add base`, `./add tuning`, `./add visual` e `./add navegador` (rodar de novo é seguro). Depois do `visual`, faça logout e login.

**Fundo:** a área de trabalho e a tela de login ficam pretas; `SO_PROPRIO_FUNDO=tema ./add visual` volta ao degradê do tema.

**Painel do PC fixo no fundo e área de trabalho limpa:** o `visual` instala o `so-proprio-painel` (`~/.local/bin`) e o inicia sozinho no login (`--fundo`): fica centralizado no fundo da área de trabalho, abaixo das janelas, com os 4 apps clicáveis (Firefox, VS Code, Terminal e Arquivos), gráfico de CPU, barras de RAM, swap, disco e bateria e o `free -h` completo. Não é um app: não tem janela, item na dock nem atalho. Para ver sem relogar: `so-proprio-painel --fundo &`; em texto: `so-proprio-painel --resumo`. Ele substitui o Conky (o autostart antigo é removido e o `./add desktop` não o recria). A área de trabalho fica sem nenhum ícone (lixeira, Home, Computer e Network): o `visual` para o gerenciador da área de trabalho, grava `DesktopShortcuts=` vazio e o religa, senão ele regravaria a config antiga ao sair.

**Janelas e dock:** botões de fechar/minimizar/maximizar estilo Mac (bolinhas vermelha, amarela e verde, à direita; sem o nome da janela na barra de título); a dock de baixo é o `so-proprio-dock` (PyQt5, autostart): uma ilha flutuante e arredondada, centralizada, que sem nada aberto mostra só o asterisco do nofio (menu: apps, buscar, bloquear, sair, reiniciar, desligar) e cresce um ícone por app aberto (clique traz a janela; clique de novo minimiza); fica sempre visível, por cima dos apps, sem reservar espaço; a barra de cima, do LXQt, é reta e fica com rede, Bluetooth, bateria, volume e hora (precisa do `picom` para os cantos transparentes, instalado pelo `visual`); o `visual` também coloca o usuário no grupo `video` para as teclas de brilho funcionarem (vale após logout e login).

**Tela de login:** o `visual` deixa o LightDM escuro, sem foto de perfil e sem os botões Entrar/Cancelar (digite a senha e Enter); vale no próximo logout/reinício.

**Teclas e extras do `visual`:** Super+L bloqueia a tela (light-locker, pelo LightDM); Print ou Ctrl+Alt+P captura a tela (ScreenGrab, seleção de área); teclas de brilho (`brightnessctl`) e de volume (`wpctl`) funcionam; a bateria usa o `cbatticon` (o ícone do LXQt é um gráfico de pizza); o touchpad usa rolagem invertida e toque para clicar (vale no próximo login); a dock de baixo se esconde e aparece ao encostar o mouse na borda; VS Code e Firefox são lidos para a memória 20 s depois do login, para abrirem rápido no HD.

**Tema claro ou escuro:** o padrão é escuro. Para o claro: `SO_PROPRIO_TEMA=claro ./add visual`; a escolha fica salva em `~/.config/so-proprio/tema` e vale nas próximas execuções (volte com `SO_PROPRIO_TEMA=escuro ./add visual`). Isso troca tema do LXQt, ícones, janelas do Openbox, apps GTK e papel de parede de uma vez. O Conky tem fundo escuro fixo; edite `~/.config/conky/conky.conf` se quiser outra cor.

**Ícones sem moldura:** o `visual` cria o tema `so-proprio-claro`/`so-proprio-escuro` (cópia do tema base do LXQt com os botões do painel sem borda), e os painéis ficam menores (dock 36 px, barra 26 px). Para mudar tamanhos, edite `~/.config/lxqt/panel.conf` (`panelSize` e `iconSize`).

**Painel e atalhos:** o `visual` só regera a barra de cima se faltar a marca `so_proprio=7` em `~/.config/lxqt/panel.conf`, então suas edições ficam. Para voltar ao do repo: `SO_PROPRIO_VISUAL_FORCE=1 ./add visual` (o anterior fica em `panel.conf.so-proprio.bak`). Os atalhos ficam em `~/.config/openbox/rc.xml`.

**Firefox:** confira em `about:policies` se as políticas estão ativas. As preferências são padrões e dá para mudar em `about:config`. O uBlock Origin é baixado na primeira abertura, com rede.

Depois do `dev`: o Node.js LTS já vem instalado; abra um terminal novo para usar `node` e `npm`.
Depois do `vm`: faça logout/login. Com Secure Boot ativo, os módulos do VirtualBox precisam ser assinados ou o Secure Boot desativado no BIOS.

Os grupos são instalados **sem pacotes recomendados**, para ocupar menos o HD. Para instalar um grupo com os recomendados: `SO_PROPRIO_RECOMMENDS=1 ./add <grupo>`. Um grupo que sempre precisa deles tem a linha `# so-proprio: com-recomendados` no seu `.txt` (é o caso do `navegador`, por causa dos codecs de vídeo).

**Se faltar algo no desktop** (ícones, som, algum diálogo), rode `SO_PROPRIO_RECOMMENDS=1 ./add desktop`: ele instala só os recomendados que faltam.

O histórico de execuções fica em `~/.local/state/so-proprio/add.log`.

## Medir

O `./add visual` troca o Conky pelo painel de fundo (veja Painel do PC). Quem quiser o Conky de volta: apague `~/.config/so-proprio/sem-conky` e rode `./add desktop`; a config fica em `~/.config/conky/conky.conf`.


Compare antes (Ubuntu antigo) e depois:

```bash
systemd-analyze          # tempo de boot
systemd-analyze blame | head -15
free -h                  # RAM em repouso, logo após o login
```

## Adicionar um grupo novo

Crie `grupos/<nome>.txt` com um pacote por linha (`#` para comentários). Se precisar de repositório próprio, crie também `grupos/<nome>.sh` (roda depois dos pacotes; deve checar se já está instalado).

## Desenvolvimento

```bash
sudo apt install -y bats shellcheck
bats tests/
shellcheck -x add lib/*.sh tuning/*.sh grupos/*.sh
```

## Firefox limpo e abertura mais rápida

O grupo `navegador` deixa o Firefox abrindo em branco, sem restaurar abas, sem cache em disco e sem sondas de rede na partida. Em perfis existentes grava um `user.js` (ganha do `prefs.js` antigo) e apaga a sessão salva e o `cache2`; favoritos, senhas e extensões não são tocados. Com o Firefox aberto a limpeza de arquivos é pulada (feche e rode `./add navegador` de novo). Se ainda demorar muito: meça com `time firefox-esr --new-instance about:blank`, compare com `firefox-esr --safe-mode` (se for bem mais rápido, o culpado é extensão) e lembre que o HD mecânico paga a primeira abertura do dia, enquanto as seguintes saem do cache de arquivos do kernel.
