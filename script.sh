#!/bin/bash

#Login root
sudo su

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
sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/vmlinuz-linux /boot/vmlinuz-linux
sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/vmlinuz-linux-lts /boot/vmlinuz-linux-lts
sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/vmlinuz-linux-zen /boot/vmlinuz-linux-zen
sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/systemd/systemd-bootx64.efi
sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI

#Pacman Hook
mkdir -p /etc/pacman.d/hooks

echo "[Trigger]" > /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "Operation = Install" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "Operation = Upgrade" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "Type = Package" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "Target = systemd" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "[Action]" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "Description = Signing bootd for SecureBoot" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "When = PostTransaction" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "Exec = /usr/bin/sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/systemd/systemd-bootx64.efi" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "Depends = sbsigntools" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "Depends = findutils" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook
echo "Depends = grep" >> /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook

echo "[Trigger]" > /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "Operation = Install" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "Operation = Upgrade" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "Type = Package" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "Target = systemd" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "[Action]" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "Description = Signing SystemD for SecureBoot" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "When = PostTransaction" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "Exec = /usr/bin/sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "Depends = sbsigntools" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "Depends = findutils" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook
echo "Depends = grep" >> /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook

echo "[Trigger]" > /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "Operation = Install" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "Operation = Upgrade" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "Type = Package" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "Target = linux" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "[Action]" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "Description = Signing Kernel for SecureBoot" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "When = PostTransaction" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "Exec = /usr/bin/sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/vmlinuz-linux /boot/vmlinuz-linux" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "Depends = sbsigntools" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "Depends = findutils" >> /etc/pacman.d/hooks/99-secureboot-linux.hook
echo "Depends = grep" >> /etc/pacman.d/hooks/99-secureboot-linux.hook

echo "[Trigger]" > /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "Operation = Install" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "Operation = Upgrade" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "Type = Package" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "Target = linux-lts" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "[Action]" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "Description = Signing Kernel LTS for SecureBoot" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "When = PostTransaction" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "Exec = /usr/bin/sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/vmlinuz-linux-lts /boot/vmlinuz-linux-lts" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "Depends = sbsigntools" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "Depends = findutils" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook
echo "Depends = grep" >> /etc/pacman.d/hooks/99-secureboot-linux-lts.hook


echo "[Trigger]" > /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "Operation = Install" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "Operation = Upgrade" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "Type = Package" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "Target = linux-zen" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "[Action]" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "Description = Signing Kernel ZEN for SecureBoot" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "When = PostTransaction" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "Exec = /usr/bin/sbsign --key /usr/share/secureboot/keys/db.key --cert /usr/share/secureboot/keys/db.crt --output /boot/vmlinuz-linux-zen /boot/vmlinuz-linux-zen" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "Depends = sbsigntools" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "Depends = findutils" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook
echo "Depends = grep" >> /etc/pacman.d/hooks/99-secureboot-linux-zen.hook

chmod +x -R /etc/pacman.d/hooks/*

#Copy keys to efi partition so we can enroll them from the UEFI
cp /usr/share/secureboot/keys/*.cer /usr/share/secureboot/keys/*.esl /usr/share/secureboot/keys/*.auth /boot/EFI

