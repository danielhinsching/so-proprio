#!/usr/bin/env bash
# Aplica os ajustes de HD. Uso: tuning/apply.sh [--dry-run] [--yes]
# ROOT_PREFIX permite aplicar numa árvore de teste em vez do sistema real.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=tuning/lib.sh
source "$HERE/lib.sh"

ROOT="${ROOT_PREFIX:-}"
DRY_RUN=0
ASSUME_YES=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --yes|-y) ASSUME_YES=1 ;;
    *) echo "Opção desconhecida: $arg" >&2; exit 2 ;;
  esac
done

SERVICES=(bluetooth cups cups-browsed avahi-daemon ModemManager)

cat <<PLAN
== Ajustes de HD (raiz: ${ROOT:-/})
- $ROOT/etc/fstab: noatime em / e /home (ext4), com backup em fstab.so-proprio.bak
- $ROOT/etc/sysctl.d/99-so-proprio.conf: vm.swappiness=10
- $ROOT/etc/default/zramswap: ALGO=zstd, PERCENT=25
- $ROOT/etc/udev/rules.d/60-so-proprio-bfq.rules: agendador bfq em discos rotacionais
- Desativar, se existirem: ${SERVICES[*]}
PLAN

if [ "$DRY_RUN" -eq 1 ]; then
  echo "(dry-run: nada foi alterado)"
  exit 0
fi

if [ "$ASSUME_YES" -ne 1 ]; then
  printf 'Aplicar? [s/N] '
  read -r answer || exit 1
  [[ "$answer" =~ ^[sSyY]$ ]] || { echo "Cancelado."; exit 1; }
fi

# No sistema real, precisa de root: reexecuta com sudo.
if [ -z "$ROOT" ] && [ "$(id -u)" -ne 0 ]; then
  exec sudo bash "$0" --yes
fi

set_noatime "$ROOT/etc/fstab"
write_sysctl "$ROOT"
write_zram "$ROOT"
write_udev "$ROOT"
if [ -z "$ROOT" ]; then
  disable_services "${SERVICES[@]}"
else
  echo "(ROOT_PREFIX definido: serviços do sistema real não foram alterados)"
fi

if [ -z "$ROOT" ]; then
  sysctl --system >/dev/null
  udevadm control --reload && udevadm trigger --subsystem-match=block
  systemctl restart zramswap.service 2>/dev/null || true
  echo "Ajustes aplicados. Reinicie para o noatime valer em / e /home."
else
  echo "Ajustes escritos em $ROOT."
fi
