# WAP v2 - Operation Guidelines

### System Requirements
* Windows 10 1803 and above
* [Supported models](https://wiki.grab.com/display/GTS/Laptop+Policy), and previous Grab IT issued modules.

### Applicable Scenarios
* A Windows machine after [factory reset](https://wiki.grab.com/display/IT/Windows+10+-+Reset+to+factory+state) with all data wiped 
* Provisioning the windows endpoints from a vanila status (Only factory drivers installed)
* Grab standard laptop / desktop models, came with IT managed CFI image.

### What it does:
1. Change hostname base on
[Naming convention](https://wiki.grab.com/pages/viewpage.action?pageId=201648291#Grab-NamingconventionforGrab.ITsystems(Placeholder)-Endpointhostname)
2. Set Windows Edition to Enterprise.
3. Install Grab IT managed agents and security agents.
4. Base Applications will be installed.

### How to use:
1. Download the [WAPGo.bat](https://repprd.s3.amazonaws.com/WAP/dev/WAPGo.bat) from respective environment folder.
2. Run As admin instead of double click. `If you see error: "Failure: Script is not downloaded, check the network connection and try again", Please check if https://*s3.amazonaws.com/ is whitelisted.`
3. Sit back and have a coffee.
4. You will prompted to choose the usage of the machine if it’s a desktop, i.e. is it a BPO or CE call center machine.
5. Login the same admin user after reboot, click "yes" when powershell prompted for admin rights.
6. Windows box will be preped in 10 mins.


### Things to check - Aftermath action list:
* Hostname should change after a reboot is done. `IT<CountryCode><SN>-TYPE`
* Windows should be switched to enterprise version.
* Check all the mentioned agents are installed and running.
* Check if any errors in c:\windows\temp\WAP.log
* `DO THIS ONLY` for laptops - **Enroll Meraki manually as per** [registering Windows machine](https://n25.meraki.com/GG01_GrabGlobalM/n/j1NBBcz/manage/configure/sm_setup) - Auto-Enrollment has not yet been supported by Meraki. 
* Windows Bitlocker will be in progress after Base Apps’ installation (automatically).
* **Make sure Windows is fully patched before handed over to user.**


### Things it will NOT do:
* Activate Windows licenses.
* Check if the asset own by Grab. (Asset management system work in progress)
