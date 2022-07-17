#!/bin/bash

#Login root
sudo -i
cd

#Create keys
pacman -S efitools

#Local store keys
mkdir -p /usr/share/secureboot/keys
cd /usr/share/secureboot/keys

#Generate GUID
uuidgen --random > GUID.txt

#Platform Key:
openssl req -newkey rsa:4096 -nodes -keyout PK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Platform Key/" -out PK.crt
openssl x509 -outform DER -in PK.crt -out PK.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" PK.crt PK.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt PK PK.esl PK.auth

#Sign an empty file to allow removing Platform Key when in "User Mode"
sign-efi-sig-list -g "$(< GUID.txt)" -c PK.crt -k PK.key PK /dev/null rm_PK.auth

#Key Exchange Key
openssl req -newkey rsa:4096 -nodes -keyout KEK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Key Exchange Key/" -out KEK.crt
openssl x509 -outform DER -in KEK.crt -out KEK.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" KEK.crt KEK.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt KEK KEK.esl KEK.auth

#Signature Database Key
openssl req -newkey rsa:4096 -nodes -keyout db.key -new -x509 -sha256 -days 3650 -subj "/CN=my Signature Database key/" -out db.crt
openssl x509 -outform DER -in db.crt -out db.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" db.crt db.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k KEK.key -c KEK.crt db db.esl db.auth

#Sign an empty file to allow removing Platform Key when in "User Mode"
sign-efi-sig-list -g "$(< GUID.txt)" -c PK.crt -k PK.key PK /dev/null rm_PK.auth

#Key Exchange Key
openssl req -newkey rsa:4096 -nodes -keyout KEK.key -new -x509 -sha256 -days 3650 -subj "/CN=my Key Exchange Key/" -out KEK.crt
openssl x509 -outform DER -in KEK.crt -out KEK.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" KEK.crt KEK.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k PK.key -c PK.crt KEK KEK.esl KEK.auth

#Signature Database Key
openssl req -newkey rsa:4096 -nodes -keyout db.key -new -x509 -sha256 -days 3650 -subj "/CN=my Signature Database key/" -out db.crt
openssl x509 -outform DER -in db.crt -out db.cer
cert-to-efi-sig-list -g "$(< GUID.txt)" db.crt db.esl
sign-efi-sig-list -g "$(< GUID.txt)" -k KEK.key -c KEK.crt db db.esl db.auth

#Sign bootloader and kernel
pacman -S sbsigntools
sbsign --key db.key --cert db.crt --output /boot/vmlinuz-linux /boot/vmlinuz-linux
sbsign --key db.key --cert db.crt --output /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/systemd/systemd-bootx64.efi
sbsign --key db.key --cert db.crt --output /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI

#Pacman Hook
mkdir -p /etc/pacman.d/hooks
echo "[Trigger]\nOperation = Install\nOperation = Upgrade\nType = Package\nTarget = linux\n\n[Action]\nDescription = Signing Kernel for SecureBoot\nWhen = PostTransaction\nExec = /usr/bin/find /boot/ -maxdepth 1 -name 'vmlinuz-*' -exec /usr/bin/sh -c 'if ! /usr/bin/sbverify --list {} 2>/dev/null | /usr/bin/grep -q \"signature certificates\"; then /usr/bin/sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output {} {}; fi' \ ;\nDepends = sbsigntools\nDepends = findutils\nDepends = grep" > /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "[Trigger]\nOperation = Install\nOperation = Upgrade\nType = Package\nTarget = systemd\n\n[Action]\nDescription = Signing systemd for SecureBoot\nWhen = PostTransaction\nExec = /usr/bin/find /boot/EFI/systemd/ -maxdepth 1 -name 'systemd-*' -exec /usr/bin/sh -c 'if ! /usr/bin/sbverify --list {} 2>/dev/null | /usr/bin/grep -q \"signature certificates\"; then /usr/bin/sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output {} {}; fi' \ ;\nDepends = sbsigntools\nDepends = findutils\nDepends = grep" > /etc/pacman.d/hooks/99-secureboot-systemd.hook
echo "[Trigger]\nOperation = Install\nOperation = Upgrade\nType = Package\nTarget = systemd\n\n[Action]\nDescription = Signing system bootd for SecureBoot\nWhen = PostTransaction\nExec = /usr/bin/find /boot/EFI/BOOT/ -maxdepth 1 -name 'BOOTX*' -exec /usr/bin/sh -c 'if ! /usr/bin/sbverify --list {} 2>/dev/null | /usr/bin/grep -q \"signature certificates\"; then /usr/bin/sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output {} {}; fi' \ ;\nDepends = sbsigntools\nDepends = findutils\nDepends = grep" > /etc/pacman.d/hooks/99-secureboot-systembootd.hook

#Copy keys to efi partition so we can enroll them from the UEFI
cp /usr/share/secureboot/keys/*.cer /usr/share/secureboot/keys/*.esl /usr/share/secureboot/keys/*.auth /boot/EFI

