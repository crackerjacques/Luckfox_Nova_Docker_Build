# Luckfox_Nova_Docker_Build

Build Luckfox Nova firmware in any OS.

# Prepare

Install Docker

```
# MacOS
brew install docker

# Arch
sudo pacman -S docker

# Ubuntu
https://docs.docker.com/engine/install/ubuntu/

# Windows
https://docs.docker.com/desktop/setup/install/windows-install/ 

# And read and install instructions for if you using other OS.

# Easily forgettable items
sudo groupadd docker
sudo usermod -aG docker $USER # or your account name
newgrp docker
sudo systemctl start docker
```


# Download SDK form Google Drive or Baidu
```
#
https://wiki.luckfox.com/Luckfox-Nova/Download

git clone https://github.com/crackerjacques/Luckfox_Nova_Docker_Build.git

mv Luckfox_Nova_SDK_* Luckfox_Nova_Docker_Build/
cd Luckfox_Nova_Docker_Build
chmod +x setup.sh
./setup.sh

```

The script asks you 2 of questions,   
If you want to tweak configuration, you should choose y in make menuconfig.  
Then, select a build type.
(If it's your first time, you should probably choose ALL, although it will take longer.)
