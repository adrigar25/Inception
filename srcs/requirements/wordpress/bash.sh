# 1. Actualiza paquetes y asegúrate de tener lo necesario
sudo apt update
sudo apt install build-essential dkms linux-headers-$(uname -r) -y

# 2. Monta la ISO si no está montada automáticamente
sudo mount /dev/cdrom /mnt

# 3. Ejecuta el instalador de Guest Additions
sudo sh /mnt/VBoxLinuxAdditions.run

# 4. Desmonta la ISO
sudo umount /mnt

# 5. Reinicia la VM
sudo reboot
