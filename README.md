# Development Environment setup tools

Everyone needs a development environment. If you're like me, you would like a reliable way to set up your development environment. This is a bit of tooling to do that.

Some basic things to consider:
 - Ubuntu sucks, but it tends to have the best compatibility with prebuilt binaries in various development related package repositories
 - You'll want to use your native desktop as much as possible to run IDEs and such, 

The script assumes the following:
 - You've got a Virtual Machine set up (with Virtual Machine Manager, VirtualBox, VMWare Workstation, or similar)
 - You've installed Ubuntu 22.04 (server or desktop) in it
 - Your basic networking and user account setup are done

How you want to actually use this if you're not me:
 - Fork this repo
 - Modify the command below to point to your repository instead of mine
 - Check the [dev_setup.sh](./dev_setup.sh) and see how you should customize it for your personal preferences. Generally read through it anyway and make sure you understand it, you don't want to run random scripts off the internet.

So, first steps first:
 - Download [Ubuntu 22.04 desktop](https://ubuntu.com/download/desktop)
 - If on Windows, install e.g. [VirtualBox](https://www.virtualbox.org/wiki/Downloads). Make sure you have [disabled Hyper-V](https://learn.microsoft.com/en-us/troubleshoot/windows-client/application-management/virtualization-apps-not-work-with-hyper-v#disable-hyper-v-in-powershell) that conflicts with it.
 - If not on Windows, you probably want to figure out some other means to boot up and run Virtual Machines
 - Create a VM, probably with 350GB of disk space, all your CPU cores, and 16GB of RAM or more. Give it the installer disk image you just downloaded.
 - Run through the install process and restart.
 - Open the terminal and run this script:
```
wget https://raw.githubusercontent.com/lietu/dev-env/main/dev_setup.sh
sudo bash dev_setup.sh
```
 - Reboot the VM

You may want to set up filesystem shares between your VM and your host system for easier access to files, you can set up e.g. a Samba server on the VM, or mount a host folder on the VM.

