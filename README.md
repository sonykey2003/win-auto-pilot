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

###  Option 1 - Using Make.com to secure your JumpCloud device enrollment connect key and API keys.

**A. Setup the Make Scenrios**

1. [Import the blueprints](https://www.make.com/en/help/scenarios/scenario-editor#6---more) in my repo. 
2. Setup Scenario `jcGetConnKey`:
   * Create a webhook, copy the link, and click on `advanced setting` to add a data structure:
   ![image](https://user-images.githubusercontent.com/19852184/194973929-eb96f4b3-fe41-41bc-8a45-b5b7a80bf265.png)
   * Make sure `systemKey`, `newHostname` , `groupName` are added as the items in the new data structure. ![image](https://user-images.githubusercontent.com/19852184/194973601-396f1b87-4f2f-4689-940f-a01ceb7637cf.png)
   * Move on to `validateUser` web request module, add your JC API key (ideally a [Read-only](https://support.jumpcloud.com/support/s/article/JumpCloud-Roles) one.) ![image](https://user-images.githubusercontent.com/19852184/194979520-abedb5d2-652e-4c87-8410-40659db25a37.png)
        * **Note** You can find the connect key by going to JumpCloud admin console -> Devices -> add Device -> copy the key. 
   * Move on to `connKeyData` JSON module, create a data structure consists `conn_key`, `email`, and `user_id`, save it.
   ![image](https://user-images.githubusercontent.com/19852184/194978079-45d246d6-b6d7-4b65-a279-f974d674b96a.png)
   * Input your JC connect key as a static value on `connKeyData` module, and fill the `email` and `user_id` by the data processed from the `iterator` module :![image](https://user-images.githubusercontent.com/19852184/195002316-6d24620e-21be-40a1-a5ee-bb77160f5afe.png)


   * Check the rest of the modules and fix any errors. 
3. Setup Scenario `jcSystemBindUser`:
   * WIP

4. Setup Scenario `jcSystemAddGroup`:
   * WIP

**B. Change the Webhook URLs in kickstart.ps1**
1. Change the URLs respectively created and copied from section A into:
```pwsh
$getConnkey_url = "your own webhook"
$jcSystemBindUser_url = "your own webhook"
$jcSystemAddGroup_url = "your own webhook"
```

**C. Kickstart.ps1 hosting**
Recommended hosting the `Kickstart.ps1` in a publicly accessible, and compliant to your security rquirements. 

It can be:
* AWS S3 or,
* Azure blob or,
* Github


\[Optional\] You can self-host `main.psm1` too by changing the url in `kickstart.ps1`:
```pwsh
$moduleUrl = "your hosted main.psm1 url"
```

**D. Update the kickstart.ps1 url in autounattended.xml**
Once you decided and attained the public url for `kickstart.ps1`, change the url in `autounattended.xml`:

```xml
<SynchronousCommand wcm:action="add">
    <Order>4</Order>
    <CommandLine>PowerShell.exe -WindowStyle Maximized -ExecutionPolicy RemoteSigned iex (irm "your kickstart.ps1 url") </CommandLine>
    <Description>wap kickoff</Description>
</SynchronousCommand>
```
