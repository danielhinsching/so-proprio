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
| `base` | sudo, NetworkManager, git, curl, gnupg, htop, zram |
| `tuning` | ajustes de HD: `noatime`, `swappiness=10`, zram (zstd, 25%), agendador `bfq`, desativa Bluetooth/CUPS/Avahi/ModemManager se existirem |
| `desktop` | LXQt + Openbox, LightDM, QTerminal, PCManFM-Qt |
| `navegador` | Firefox ESR |
| `dev` | Python (venv, pipx), build-essential, VS Code (repositório Microsoft), fnm para Node.js |
| `vm` | VirtualBox (repositório Oracle) |
| `claude` | Claude Code no terminal (instalador oficial) |

Ordem sugerida: `base` → `tuning` → `desktop` → `navegador` → `dev` → `claude` → `vm`.

Depois do `dev`: abra um terminal novo e rode `fnm install --lts`.
Depois do `vm`: faça logout/login. Com Secure Boot ativo, os módulos do VirtualBox precisam ser assinados ou o Secure Boot desativado no BIOS.

O histórico de execuções fica em `~/.local/state/so-proprio/add.log`.

## Medir

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
