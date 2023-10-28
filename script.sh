#!/bin/bash
if [ -z $1 ]; then
    store_keys=/usr/share/secureboot/keys
else
    store_keys=$1
fi

#Check if root
is_root=$(whoami)
if [ ! $is_root == "root" ]; then
    echo "run as root"
    exit 2
fi

#Install efitools
pacman -S efitools

#Local store keys
mkdir -p ${store_keys}
cd ${store_keys}

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
sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/vmlinuz-linux /boot/vmlinuz-linux
sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/vmlinuz-linux-lts /boot/vmlinuz-linux-lts
sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/vmlinuz-linux-zen /boot/vmlinuz-linux-zen
sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/systemd/systemd-bootx64.efi
sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI

#Pacman Hook
mkdir -p /etc/pacman.d/hooks

cat > /etc/pacman.d/hooks/99-secureboot-linux-bootd.hook <<PACMANHOOK
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = systemd

[Action]
Description = Signing bootd for SecureBoot
When = PostTransaction
Exec = /usr/bin/sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/EFI/systemd/systemd-bootx64.efi /boot/EFI/systemd/systemd-bootx64.efi
Depends = sbsigntools
Depends = findutils
Depends = grep
PACMANHOOK


cat > /etc/pacman.d/hooks/99-secureboot-linux-systemd.hook <<PACMANHOOK
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = systemd

[Action]
Description = Signing SystemD for SecureBoot
When = PostTransaction
Exec = /usr/bin/sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/EFI/BOOT/BOOTX64.EFI /boot/EFI/BOOT/BOOTX64.EFI
Depends = sbsigntools
Depends = findutils
Depends = grep
PACMANHOOK


cat > /etc/pacman.d/hooks/99-secureboot-linux.hook <<PACMANHOOK
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux

[Action]
Description = Signing Kernel for SecureBoot
When = PostTransaction
Exec = /usr/bin/sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/vmlinuz-linux /boot/vmlinuz-linux
Depends = sbsigntools
Depends = findutils
Depends = grep
PACMANHOOK


cat > /etc/pacman.d/hooks/99-secureboot-linux-lts.hook <<PACMANHOOK
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-lts

[Action]
Description = Signing Kernel LTS for SecureBoot
When = PostTransaction
Exec = /usr/bin/sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/vmlinuz-linux-lts /boot/vmlinuz-linux-lts
Depends = sbsigntools
Depends = findutils
Depends = grep
PACMANHOOK


cat > /etc/pacman.d/hooks/99-secureboot-linux-zen.hook <<PACMANHOOK
[Trigger]
Operation = Install
Operation = Upgrade
Type = Package
Target = linux-zen

[Action]
Description = Signing Kernel ZEN for SecureBoot
When = PostTransaction
Exec = /usr/bin/sbsign --key ${store_keys}/db.key --cert ${store_keys}/db.crt --output /boot/vmlinuz-linux-zen /boot/vmlinuz-linux-zen
Depends = sbsigntools
Depends = findutils
Depends = grep
PACMANHOOK

chmod +x -R /etc/pacman.d/hooks/*
echo "keys stored in ${store_keys}"
