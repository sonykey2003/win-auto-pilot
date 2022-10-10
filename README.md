# Auto-Pilot Windows Provisioning with JumpCloud
## Before We Start
### You will need:
* A [JumpCloud](https://jumpcloud.com/) tenant - free for 10 users.
* A workflow automation tenant. Such as: 
  * [Make.com](https://us1.make.com/) - Exported Scenarios (recipes) can be found in `Make Scenarios` folder.
* An Image distrubition account (Optional):
  * Dell - [Image Assist](https://techdirect.dell.com/Portal/DellImageAssist.aspx) (FKA: Dell Factory image)
  * Lenovo - [Custom image](https://static.lenovo.com/au/services/pdfs/custom-image.pdf) (Untested, an enterprise account is needed according to [this](https://www.lenovo.com/sg/en/services/pc-services/deploy/customization/))
* An autounattended.xml (Windows answer file) with desired configrations. You can get it in various ways:
  * Use my example here.
  * Use [Windows Answer File Generator](https://www.windowsafg.com/win10x86_x64_uefi.html).
  * Triditional and offical, [Windows System Image Manager](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/wsim/windows-system-image-manager-overview-topics).

## Getting Started


steps with screenshots
https://medium.com/analytics-vidhya/how-to-add-a-screenshot-in-your-github-readme-file-176afeb8ad86