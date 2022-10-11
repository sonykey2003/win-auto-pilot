# Auto-Pilot Windows Provisioning with JumpCloud
## Before We Start
### You will need:
* A [JumpCloud](https://jumpcloud.com/) tenant - free for 10 users.
* A workflow automation tenant. Such as: 
  * [Make.com](https://us1.make.com/) - Exported blueprints can be found in `Make blueprints` folder.
* An Image distrubition account (Optional):
  * Dell - [Image Assist](https://techdirect.dell.com/Portal/DellImageAssist.aspx) (FKA: Dell Factory image)
  * Lenovo - [Custom image](https://static.lenovo.com/au/services/pdfs/custom-image.pdf) (Untested, an enterprise account is needed according to [this](https://www.lenovo.com/sg/en/services/pc-services/deploy/customization/))
* An autounattended.xml (Windows answer file) with desired configrations. You can get it in various ways:
  * Use my example here.
  * Use [Windows Answer File Generator](https://www.windowsafg.com/win10x86_x64_uefi.html).
  * Triditional and offical, [Windows System Image Manager](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/wsim/windows-system-image-manager-overview-topics).

## Getting Started

### [Option 1] Using Make.com to secure your JumpCloud device enrollment connect key and API keys. 

**Setup the Make Scenrios.**

1. [Import the blueprints](https://www.make.com/en/help/scenarios/scenario-editor#6---more) in my repo. 
2. For Scenario `jcGetConnKey`:
   * Create a webhook, copy the link, and click on `advanced setting` to add a data structure:
   [image](https://user-images.githubusercontent.com/19852184/194973929-eb96f4b3-fe41-41bc-8a45-b5b7a80bf265.png)
   * Make sure `systemKey`, `newHostname` , `groupName` are added as the items in the new data structure. [image](https://user-images.githubusercontent.com/19852184/194973601-396f1b87-4f2f-4689-940f-a01ceb7637cf.png)

steps with screenshots
https://medium.com/analytics-vidhya/how-to-add-a-screenshot-in-your-github-readme-file-176afeb8ad86