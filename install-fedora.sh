#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-only
# Copyright (c) 2026 Jan Helge Røe
# Original Fedora adapter. Downloads upstream projects under their own licenses.
set -Eeuo pipefail
trap 'printf "Installation stopped at line %s. Review the error before retrying.\n" "$LINENO" >&2' ERR
usage() {
  cat <<'HELP'
Experimental RTKBase installer for Fedora 44 x86_64 (not yet tested on Fedora).
Usage: bash install-fedora.sh --plan
       sudo bash install-fedora.sh --apply --user LOGIN
Installs RTKBase 2.7.0 and RTKLIB 2.5.0. Does not start services,
configure GNSS, open firewall ports, or publish corrections automatically.
Fresh installations only. See README.md for commissioning and limitations.
HELP
}
mode=plan
rtk_user=''
while (($#)); do
  case "$1" in
    --help|-h) usage; exit 0 ;;
    --plan) mode=plan; shift ;;
    --apply) mode=apply; shift ;;
    --user) [[ $# -ge 2 ]] || { usage; exit 2; }; rtk_user=$2; shift 2 ;;
    *) printf 'Unknown argument: %s\n' "$1" >&2; exit 2 ;;
  esac
done
if [[ $mode == plan ]]; then
  usage
  printf '\nPlan: dnf dependencies; verified RTKBase archive; RTKLIB build;\nPython 3.11 virtual environment; F9P USB rule; systemd units.\nNo changes made.\n'
  exit 0
fi
[[ $EUID == 0 ]] || { echo 'Run --apply with sudo.' >&2; exit 1; }
source /etc/os-release
[[ $ID == fedora && $VERSION_ID == 44 && $(uname -m) == x86_64 ]] || {
  echo 'This prototype targets Fedora 44 x86_64 only.' >&2; exit 1;
}
[[ $rtk_user =~ ^[a-z_][a-z0-9_-]*\$?$ && $rtk_user != root ]] || {
  echo '--user must name an existing non-root Linux account.' >&2; exit 2;
}
id "$rtk_user" >/dev/null
rtk_dir=/opt/rtkbase
[[ ! -e $rtk_dir ]] || { echo '/opt/rtkbase already exists; refusing to overwrite it.' >&2; exit 1; }
for unit in /etc/systemd/system/rtkbase* /etc/systemd/system/str2str*; do
  [[ ! -e $unit ]] || { echo 'Existing RTKBase services found; refusing to overwrite.' >&2; exit 1; }
done
for app in str2str convbin rtkrcv; do
  [[ ! -e /usr/local/bin/$app ]] || { echo "Existing $app binary found; refusing to overwrite." >&2; exit 1; }
done
command -v dnf >/dev/null
work_dir=$(mktemp -d /var/tmp/rtkbase-fedora.XXXXXX)
trap 'rm -rf -- "$work_dir"' EXIT
# Keep the system Python unchanged; pinned upstream Python packages use 3.11.
dnf install -y git curl tar gzip make gcc gcc-c++ python3.11 python3.11-devel \
  systemd-devel openssl-devel libffi-devel libxml2-devel libxslt-devel \
  pkgconf-pkg-config python3-pyserial bc dos2unix socat zip unzip psmisc \
  proj nftables sudo NetworkManager polkit policycoreutils
curl -fL --retry 3 --connect-timeout 20 --max-time 180 \
  https://github.com/Stefal/rtkbase/archive/refs/tags/v2.7.0.tar.gz \
  -o "$work_dir/rtkbase.tar.gz"
printf '%s  %s\n' 6153e57236c7f121b9015e5225485162d0b59aae457f76e69ea98ff949941270 \
  "$work_dir/rtkbase.tar.gz" | sha256sum -c -
tar -xzf "$work_dir/rtkbase.tar.gz" -C "$work_dir"
[[ -f $work_dir/rtkbase-2.7.0/web_app/requirements.txt ]]
install -d -o "$rtk_user" -g "$(id -gn "$rtk_user")" "$rtk_dir"
cp -a "$work_dir/rtkbase-2.7.0/." "$rtk_dir/"
chown -R "$rtk_user:$(id -gn "$rtk_user")" "$rtk_dir"
runuser -u "$rtk_user" -- python3.11 -m venv "$rtk_dir/venv"
runuser -u "$rtk_user" -- "$rtk_dir/venv/bin/python" -m pip install --upgrade pip
runuser -u "$rtk_user" -- "$rtk_dir/venv/bin/python" -m pip install \
  -r "$rtk_dir/web_app/requirements.txt" pyserial
runuser -u "$rtk_user" -- "$rtk_dir/venv/bin/python" -m pip check
curl -fL --retry 3 --connect-timeout 20 --max-time 180 \
  https://github.com/rtklibexplorer/RTKLIB/archive/refs/tags/v2.5.0.tar.gz \
  -o "$work_dir/rtklib.tar.gz"
# Verify the pinned RTKLIB release archive.
printf '%s  %s\n' 2229dadd2e71c7ef3a2cc97c11903a900a661e56c39fd0be7450d932685ce249 "$work_dir/rtklib.tar.gz" | sha256sum -c -
tar -xzf "$work_dir/rtklib.tar.gz" -C "$work_dir"
for app in str2str convbin rtkrcv; do
  make -C "$work_dir/RTKLIB-2.5.0/app/consapp/$app/gcc"
  make -C "$work_dir/RTKLIB-2.5.0/app/consapp/$app/gcc" install
  test -x "/usr/local/bin/$app"
done
cp "$rtk_dir/settings.conf.default" "$rtk_dir/settings.conf"
sed -i -e 's/^web_port=.*/web_port=8080/' -e "s/^user=.*/user='$rtk_user'/" \
  "$rtk_dir/settings.conf"
chmod 600 "$rtk_dir/settings.conf"
chown "$rtk_user:$(id -gn "$rtk_user")" "$rtk_dir/settings.conf"
groupadd -f dialout
usermod -a -G dialout "$rtk_user"
cat > /etc/udev/rules.d/99-rtkbase-fedora-f9p.rules <<'RULE'
SUBSYSTEM=="tty", ATTRS{idVendor}=="1546", ATTRS{idProduct}=="01a9", SYMLINK+="ttyGNSS", GROUP="dialout", MODE="0660"
RULE
udevadm control --reload-rules
# A reconnect applies the rule; do not trigger all USB devices.
bash "$rtk_dir/tools/copy_unit.sh" --python_path "$rtk_dir/venv/bin/python" --user "$rtk_user"
restorecon -RF "$rtk_dir" /usr/local/bin/str2str /usr/local/bin/convbin /usr/local/bin/rtkrcv \
  /etc/systemd/system /etc/udev/rules.d/99-rtkbase-fedora-f9p.rules
systemctl daemon-reload
printf '\nInstallation files are in /opt/rtkbase. Services are NOT started.\n'
printf 'Read README.md: configure F9P, set password/coordinates, then test services.\n'
printf 'SELinux and firewall were not disabled or opened. Fedora testing remains required.\n'
