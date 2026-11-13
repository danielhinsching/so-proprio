# Validação

## 1. Ambiente de desenvolvimento (13/11/2026) — feito

Executado num Linux de teste (Ubuntu 24.04, não Debian), sem VM:

| Verificação | Resultado |
|---|---|
| `bats tests/` | 25/25 passando |
| `shellcheck` em todos os scripts | sem avisos |
| `./add --dry-run` em base, desktop, dev, navegador, vm | lista os faltantes, não altera nada |
| `./add --yes base` (apt real) | instalou network-manager, htop, zram-tools |
| `./add --yes base` de novo | "nada a instalar" |
| `./add --yes navegador` (pacote inexistente neste Ubuntu) | erro nomeando `firefox-esr`, status 1 |
| `./add --dry-run tuning` | mostra o plano, não altera nada |

**Não validado aqui:** nomes de pacote no Debian estável (exceto `lxqt-core` e `obconf-qt`, conferidos em packages.debian.org/trixie), `dev.sh`, `vm.sh`, `claude.sh` e o login gráfico.

## 2. VM Debian — a fazer pelo Daniel

1. VirtualBox (pode ser no próprio Ubuntu atual): VM Debian estável, 2 CPUs, 4 GB de RAM, disco de 40 GB, EFI ativado.
2. Instalar com o particionamento do README, só "utilitários padrão do sistema".
3. Copiar o repositório para a VM e rodar, anotando erros:
   - [x] `./add base` e depois `./add base` de novo → "nada a instalar"
   - [x] `./add tuning`, reiniciar, conferir: `findmnt -no OPTIONS /` contém `noatime`; `cat /proc/sys/vm/swappiness` = 10; `cat /proc/swaps` mostra `/dev/zram0` (ou `sudo zramctl`; ele fica em /usr/sbin); `cat /sys/block/sda/queue/scheduler` mostra `[bfq]`
   - [x] `./add desktop`, reiniciar → tela do LightDM e sessão LXQt. Anotar `free -h` logo após o login e `systemd-analyze`
   - [ ] `./add navegador` → Firefox ESR abre
   - [ ] `./add dev` → `code` abre; terminal novo, `fnm install --lts`, `node -v`
   - [ ] `./add claude` → mostra a URL e o comando, `claude` abre num terminal novo
   - [ ] `./add vm` → instala o VirtualBox da Oracle (dentro da VM ele só serve para testar a instalação)
4. Corrigir nomes de pacote que falharem (`apt-cache policy <pacote>`) e registrar aqui.

### Resultado na VM (13/11/2026, Debian 13, kernel 6.12, 2 CPUs, 4 GB)

| Verificação | Resultado |
|---|---|
| `noatime` | `/`: `rw,noatime,errors=remount-ro`; `/home`: `rw,noatime` |
| `vm.swappiness` | 10 |
| swap | `/dev/zram0` ~1 GB prioridade 100; `/dev/sda3` ~2 GB prioridade -2 |
| agendador | `none mq-deadline [bfq]` (rotational = 1) |
| `zramswap` | active |
| RAM em repouso (sem desktop) | 324 MiB usados |
| boot | 7,79 s (kernel 5,41 s + userspace 2,39 s) |
| RAM em repouso com LXQt + Openbox | 496 MiB usados |
| boot com desktop | 11,17 s (kernel 9,07 s + userspace 2,10 s) |

## 3. Notebook — só depois da VM e do backup

| Medida | Ubuntu antigo | so-proprio |
|---|---|---|
| `systemd-analyze` (boot) | | |
| `free -h` em repouso | | |
| VS Code abre em | | |
