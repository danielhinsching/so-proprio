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
   - [x] `./add navegador` → Firefox ESR abre
   - [x] `./add dev` → `code` abre; terminal novo, `fnm install --lts`, `node -v`
   - [x] `./add claude` → mostra a URL e o comando, `claude` abre num terminal novo
   - [x] `./add vm` → instala o VirtualBox da Oracle (dentro da VM ele só serve para testar a instalação)
4. Observação: o pacote do VirtualBox puxou recomendados (ex.: zathura, libsynctex2), que ocupam espaço sem uso.
5. Corrigir nomes de pacote que falharem (`apt-cache policy <pacote>`) e registrar aqui.

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
| Firefox ESR | 153.7.0esr |
| VS Code (repositório Microsoft, deb822) | 1.146.0, sem erro de Signed-By |
| Node.js via fnm | v26.13.1 (LTS) |
| Claude Code (instalador nativo) | 2.1.323; PATH corrigido pelo claude.sh |
| VirtualBox (repositório Oracle, trixie) | virtualbox-7.2 7.2.22r175245; chave aceita pelo apt do Debian 13 |
| Conky (free -h e systemd-analyze, canto superior direito) | funcionando no LXQt + Openbox |
| boot com desktop | 11,17 s (kernel 9,07 s + userspace 2,10 s) |

### Mudança depois da VM: grupos sem recomendados (13/11)

A VM foi validada **com** recomendados. Depois disso, os grupos passaram a instalar sem eles, e a revisão foi feita sem uma VM nova. Itens que eram só recomendados e foram mantidos de forma explícita: `wpasupplicant`, `polkitd`, `dbus-user-session` (base); `lxqt-powermanagement`, `xserver-xorg-input-libinput`, `libgl1-mesa-dri`, `fonts-dejavu-core`, `breeze-icon-theme`, `gvfs`, `udisks2` (desktop). O `navegador` continua com recomendados (codecs). Rede de segurança no notebook: `SO_PROPRIO_RECOMMENDS=1 ./add desktop`.

## 3. Notebook — só depois da VM e do backup

| Medida | Ubuntu antigo | so-proprio |
|---|---|---|
| `systemd-analyze` (boot) | 2 min 45 s (firmware 4,6 s + loader 9,1 s + kernel 29,9 s + userspace 2 min 1,9 s) | |
| `free -h` | 2,9 GiB usados de 9,6 GiB (medido em 13/11, possivelmente com apps abertos) | |
| VS Code abre em | | |
