#!/usr/bin/env bats

setup() {
  REPO="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  TMP="$(mktemp -d)"
  ROOT="$TMP/root"
  mkdir -p "$ROOT/etc"
  cat > "$ROOT/etc/fstab" <<'EOF'
# /etc/fstab: static file system information.
UUID=aaaa-1111 /               ext4    errors=remount-ro 0       1
UUID=bbbb-2222 /boot/efi       vfat    umask=0077      0       1
UUID=cccc-3333 /home           ext4    defaults        0       2
UUID=dddd-4444 none            swap    sw              0       0
EOF
  source "$REPO/tuning/lib.sh"
}

teardown() { rm -rf "$TMP"; }

opts_of() { awk -v mp="$1" '$1 !~ /^#/ && $2 == mp { print $4 }' "$ROOT/etc/fstab"; }

@test "noatime entra em / e /home" {
  set_noatime "$ROOT/etc/fstab"
  [ "$(opts_of /)" = "errors=remount-ro,noatime" ]
  [ "$(opts_of /home)" = "defaults,noatime" ]
}

@test "noatime não entra em swap nem em /boot/efi, e comentários ficam iguais" {
  set_noatime "$ROOT/etc/fstab"
  [ "$(opts_of none)" = "sw" ]
  [ "$(opts_of /boot/efi)" = "umask=0077" ]
  head -1 "$ROOT/etc/fstab" | grep -qx '# /etc/fstab: static file system information.'
}

@test "rodar duas vezes não duplica noatime" {
  set_noatime "$ROOT/etc/fstab"
  set_noatime "$ROOT/etc/fstab"
  [ "$(opts_of /)" = "errors=remount-ro,noatime" ]
}

@test "cria backup antes de alterar e não o sobrescreve na segunda execução" {
  cp "$ROOT/etc/fstab" "$TMP/original"
  set_noatime "$ROOT/etc/fstab"
  cmp "$ROOT/etc/fstab.so-proprio.bak" "$TMP/original"
  set_noatime "$ROOT/etc/fstab"
  cmp "$ROOT/etc/fstab.so-proprio.bak" "$TMP/original"
}

@test "fstab não ext4 em / não é alterado" {
  sed -i 's|^UUID=aaaa-1111 /               ext4|UUID=aaaa-1111 /               btrfs|' "$ROOT/etc/fstab"
  set_noatime "$ROOT/etc/fstab"
  [ "$(opts_of /)" = "errors=remount-ro" ]
}

@test "arquivos de sysctl, zram e udev contêm os valores da spec" {
  write_sysctl "$ROOT"
  write_zram "$ROOT"
  write_udev "$ROOT"
  grep -qx 'vm.swappiness=10' "$ROOT/etc/sysctl.d/99-so-proprio.conf"
  grep -qx 'ALGO=zstd' "$ROOT/etc/default/zramswap"
  grep -qx 'PERCENT=25' "$ROOT/etc/default/zramswap"
  grep -q 'queue/rotational}=="1"' "$ROOT/etc/udev/rules.d/60-so-proprio-bfq.rules"
  grep -q 'queue/scheduler}="bfq"' "$ROOT/etc/udev/rules.d/60-so-proprio-bfq.rules"
}

@test "write_zram preserva outras linhas e não duplica" {
  mkdir -p "$ROOT/etc/default"
  printf '#ALGO=lz4\nPRIORITY=100\n' > "$ROOT/etc/default/zramswap"
  write_zram "$ROOT"
  write_zram "$ROOT"
  grep -qx 'PRIORITY=100' "$ROOT/etc/default/zramswap"
  [ "$(grep -c '^ALGO=' "$ROOT/etc/default/zramswap")" -eq 1 ]
}

@test "disable_services ignora serviço inexistente" {
  cat > "$TMP/systemctl" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "list-unit-files" ]; then echo "bluetooth.service enabled"; exit 0; fi
echo "systemctl $*" >> "$SYSTEMCTL_LOG"
EOF
  chmod +x "$TMP/systemctl"
  export SYSTEMCTL="$TMP/systemctl" SYSTEMCTL_LOG="$TMP/sc.log"
  run disable_services bluetooth cups
  [ "$status" -eq 0 ]
  grep -q 'disable --now bluetooth.service' "$TMP/sc.log"
  ! grep -q cups "$TMP/sc.log"
}

@test "apply --dry-run não escreve nenhum arquivo" {
  cp "$ROOT/etc/fstab" "$TMP/original"
  run env ROOT_PREFIX="$ROOT" SYSTEMCTL=true "$REPO/tuning/apply.sh" --dry-run
  [ "$status" -eq 0 ]
  cmp "$ROOT/etc/fstab" "$TMP/original"
  [ ! -e "$ROOT/etc/fstab.so-proprio.bak" ]
  [ ! -e "$ROOT/etc/sysctl.d" ]
  [[ "$output" == *noatime* ]]
}

@test "apply --yes com ROOT_PREFIX escreve os arquivos" {
  run env ROOT_PREFIX="$ROOT" SYSTEMCTL=true "$REPO/tuning/apply.sh" --yes
  [ "$status" -eq 0 ]
  [ -e "$ROOT/etc/sysctl.d/99-so-proprio.conf" ]
  [ "$(opts_of /home)" = "defaults,noatime" ]
}

# --- Correções da revisão final ---

@test "disable_services também desativa .socket e .path" {
  cat > "$TMP/systemctl" <<'EOF2'
#!/usr/bin/env bash
if [ "$1" = "list-unit-files" ]; then printf '%s enabled\n' cups.service cups.socket cups.path avahi-daemon.socket; exit 0; fi
echo "systemctl $*" >> "$SYSTEMCTL_LOG"
EOF2
  chmod +x "$TMP/systemctl"
  export SYSTEMCTL="$TMP/systemctl" SYSTEMCTL_LOG="$TMP/sc.log"
  run disable_services cups avahi-daemon
  [ "$status" -eq 0 ]
  grep -q 'disable --now cups.socket' "$TMP/sc.log"
  grep -q 'disable --now cups.path' "$TMP/sc.log"
  grep -q 'disable --now cups.service' "$TMP/sc.log"
  grep -q 'disable --now avahi-daemon.socket' "$TMP/sc.log"
}

@test "apply com ROOT_PREFIX não mexe nos serviços do sistema real" {
  printf '#!/usr/bin/env bash\necho "systemctl $*" >> "%s"\n' "$TMP/sc.log" > "$TMP/systemctl"
  chmod +x "$TMP/systemctl"
  run env ROOT_PREFIX="$ROOT" SYSTEMCTL="$TMP/systemctl" "$REPO/tuning/apply.sh" --yes
  [ "$status" -eq 0 ]
  [ ! -e "$TMP/sc.log" ]
}

@test "fstab que não passa na verificação não é instalado" {
  cp "$ROOT/etc/fstab" "$TMP/original"
  # findmnt falso: aprova o fstab original e reprova qualquer outro arquivo
  printf '#!/bin/sh\n[ "$3" = "%s" ] && exit 0\nexit 1\n' "$ROOT/etc/fstab" > "$TMP/findmnt"; chmod +x "$TMP/findmnt"
  FINDMNT_CMD="$TMP/findmnt" run set_noatime "$ROOT/etc/fstab"
  [ "$status" -ne 0 ]
  cmp "$ROOT/etc/fstab" "$TMP/original"
  [ -z "$(find "$ROOT/etc" -name 'fstab.*' ! -name 'fstab.so-proprio.bak')" ]
}

@test "set_noatime preserva permissões do fstab" {
  chmod 640 "$ROOT/etc/fstab"
  set_noatime "$ROOT/etc/fstab"
  [ "$(stat -c %a "$ROOT/etc/fstab")" = "640" ]
}

@test "avisa quando / e /home não são ext4" {
  sed -i 's/ ext4 / btrfs /' "$ROOT/etc/fstab"
  run set_noatime "$ROOT/etc/fstab"
  [ "$status" -eq 0 ]
  [[ "$output" == *"nenhuma linha"* ]]
}
