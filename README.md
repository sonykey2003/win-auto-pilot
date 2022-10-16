# Auto Provisioning Windows Devices with JumpCloud
## Before We Start

### The Problem I'm Trying to Solve

To provision Windows devices in a modern way:
* Without signing up with `Intune`, and the MSFT [enterprise subscriptions](https://www.microsoft.com/en-us/microsoft-365/compare-microsoft-365-enterprise-plans). 
* Provide an open-the-box expirence for onboarding remote co-workers.
* Archieve a liteTouch / ZeroTouch Windows provisioning experience for the IT folks - to save the precious man hours. 
* Enforce the security policies and push the managed the softwares with full transparency (to the end users) on d-day.

### You will need:
* A Window 10 / 11 installation media. 
* OR a [MDT](https://github.com/sonykey2003/mdtwinsrv2022) image.
* A [JumpCloud](https://jumpcloud.com/) tenant - free for 10 users.
* A workflow automation tenant. Such as: 
  * [Make.com](https://us1.make.com/) - Exported blueprints can be found in `Make blueprints` folder.
  * [n8n.io](n8n.io) - Exported workflows can be found in `n8n` folder.
* (Optional) An Image distrubition channel, for open-the-box experience, and the benefit for pre-installing the drivers by the manufacturer:
  * Dell - [Image Assist](https://techdirect.dell.com/Portal/DellImageAssist.aspx) (FKA: Dell Factory image), you can submit either an full image or just the autounattended.xml to Dell. 
  * Lenovo - [Custom image](https://static.lenovo.com/au/services/pdfs/custom-image.pdf) (Untested, an enterprise account is needed according to [this](https://www.lenovo.com/sg/en/services/pc-services/deploy/customization/))
* An autounattended.xml (Windows answer file) with desired configrations. You can get it in various ways:
  * Use my example here.
  * Use [Windows Answer File Generator](https://www.windowsafg.com/win10x86_x64_uefi.html).
  * Triditional and offical, [Windows System Image Manager](https://learn.microsoft.com/en-us/windows-hardware/customize/desktop/wsim/windows-system-image-manager-overview-topics).

## Getting Started

### A. Setup the workflow engine to secure your JumpCloud device enrollment connect key and API keys.

On a high level, the 3 workflows will do:

* Securely distribute the JumpCloud device enrollment key to a validated user.
  * By validating the user's email and pre-assigned `enrollmentPin`.
  * Rotate the `enrollmentPin` once obtained.
  * The `enrollmentPin` can be sent to the user as part of the onboarding process, especially for the remote co-workers.
* Bind the user to the device on JumpCloud.
* Add the device to designated device group on JumpCloud, thus on day 1:
  * A set of [security policies](https://support.jumpcloud.com/support/s/article/getting-started-policies-2019-08-21-10-36-47) can be applied.
  * System [patch policies](https://support.jumpcloud.com/support/s/article/Getting-Started-Patch-Management) can be enforced.
  * A set of (managed) [software](https://support.jumpcloud.com/support/s/article/Manage-Software-on-User-Devices) will be installed. 


**Option 1 - Using Make.com**

1. [Import the blueprints](https://github.com/sonykey2003/win-auto-pilot/tree/master/Make%20blueprints) in my repo. 
2. Setup Scenario `jcGetConnKey`:
   * Create a webhook, copy the link, and click on `advanced setting` to add a data structure:

        <img src="https://user-images.githubusercontent.com/19852184/194973929-eb96f4b3-fe41-41bc-8a45-b5b7a80bf265.png"  width=50% height=50%>
   
   * Make sure `systemKey`, `newHostname` , `groupName` are added as the items in the new data structure. 

        <img src="https://user-images.githubusercontent.com/19852184/194973601-396f1b87-4f2f-4689-940f-a01ceb7637cf.png"  width=50% height=50%>
   
   * Move on to `validateUser` web request module, add your JC API key (ideally a [Read-only](https://support.jumpcloud.com/support/s/article/JumpCloud-Roles) one.)
   
        <img src="https://user-images.githubusercontent.com/19852184/194979520-abedb5d2-652e-4c87-8410-40659db25a37.png"  width=50% height=50%>
   

   * Move on to `connKeyData` JSON module, create a data structure consists `conn_key`, `email`, and `user_id`, save it.

        <img src="https://user-images.githubusercontent.com/19852184/194978079-45d246d6-b6d7-4b65-a279-f974d674b96a.png"  width=50% height=50%>
  
   * Move on to `reGenUserEnrolPinData` JSON module, create a data structure like this:

        <img src="https://user-images.githubusercontent.com/19852184/195267931-7b2750b3-8201-4528-812d-3eceb741345c.png"  width=50% height=50%>

        <img src="https://user-images.githubusercontent.com/19852184/195268543-9b978df1-4348-4320-a3a0-112e68f55acd.png"  width=50% height=50%>

    * Contiune to `rotateUserEnrolPin` module, add your JC API key - this time with "writeable" permissions.
   
   * Input your JC connect key as a static value on `connKeyData` module, and fill the `email` and `user_id` by the data processed from the `iterator` module :
        * **Note** You can find the connect key by going to JumpCloud admin console -> Devices -> add Device -> copy the key. 

            <img src="https://user-images.githubusercontent.com/19852184/195002316-6d24620e-21be-40a1-a5ee-bb77160f5afe.png"  width=50% height=50%>


   * Check the rest of the modules and fix any errors. 

3. Setup Scenario `jcSystemBindUser`:
   * Similarily as above - create a webhook, copy the link, and click on `advanced setting` to add a data structure:

      <img src="https://user-images.githubusercontent.com/19852184/195269638-de6729a2-244c-4e85-92a7-0c9d50559500.png"  width=50% height=50%>

   * Move on to `userSystemBindData` JSON module, create a data structure:

     <img src="https://user-images.githubusercontent.com/19852184/195270222-24d51718-59f0-4415-abdd-b2649d4c933c.png"  width=50% height=50%>

     <img src="https://user-images.githubusercontent.com/19852184/195270412-d4dbff1f-d39b-4c83-87b5-63afc4f1ca47.png"  width=50% height=50%>
   

   * Move on to `updateSystemData` JSON module, create a data structure:

     <img src="https://user-images.githubusercontent.com/19852184/195270884-f73357f2-8031-4836-951f-c1da666ec756.png"  width=50% height=50%>

      <img src="https://user-images.githubusercontent.com/19852184/195270999-16bb9625-b93c-4115-b49d-e6421117770f.png"  width=50% height=50%>

   * Check the rest of the modules and fix any errors. 

4. Setup Scenario `jcSystemAddGroup`:
   * Similarily as above - create a webhook, copy the link, and you can reuse the data structure created in `jcSystemBindUser` scenario. 
   
   * Move on to `createGroupBody` JSON module, create a data structure:

     <img src="https://user-images.githubusercontent.com/19852184/195276276-68a1e6c7-2633-499c-85f3-251f0482aaa7.png"  width=50% height=50%>

     <img src="https://user-images.githubusercontent.com/19852184/195276421-564a10e2-6b37-4c55-984b-f3f8ed202564.png"  width=50% height=50%>


   * Move on to `addSysGroupMemberBody` JSON module, create a data structure:

     <img src="https://user-images.githubusercontent.com/19852184/195276905-85e9c715-e8da-4837-9f27-13f5f141a129.png"  width=50% height=50%>

     <img src="https://user-images.githubusercontent.com/19852184/195277030-d5ced862-ed49-47cc-9152-1e01e281aff4.png"  width=50% height=50%>

     * **Note** There are two module named the same, you can reuse the data structure in 1 or the other, and config the same. 

**Option 2 - Using n8n.io**

1. [Import the workflow](https://github.com/sonykey2003/win-auto-pilot/tree/master/n8n) in my repo. 

2. Setup Workflow `jcGetConnKey`:
    * Go to `validateJcUser` node, create a R/O API Header Auth Key:

       <img src="https://user-images.githubusercontent.com/19852184/195522111-478afa40-efe2-4b51-9fef-1260aed1d995.png"  width=50% height=50%>

    
    * Move on to `Respond to Webhook` node and key in your connect key:

        <img src="https://user-images.githubusercontent.com/19852184/195521621-9589044e-e129-4f34-8c8f-86cf064fbaa8.png"  width=50% height=50%>
    
    * Move on to `ran_num` node, write a JS code to gen a random digits of `enrollmentPin`.
    * Continue to `rotateUserEnrolPin` node, create a W/R API Header Auth. 

3. Setup Workflow `jcSystemBindUser`:

   \<WIP\>

4. Setup Workflow `jcSystemAddGroup`:

   \<WIP\>


**B. Change the Webhook URLs in kickstart.ps1**
1. Change the URLs respectively created and copied from section A into:
```pwsh
$getConnkey_url = "your own webhook"
$jcSystemBindUser_url = "your own webhook"
$jcSystemAddGroup_url = "your own webhook"
```

**C. Kickstart.ps1 hosting**
Recommended hosting the `kickOff.ps1` in a publicly accessible, and compliant to your security rquirements. 

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

**P.S. Re-provsioning**

You can place `reKickOff.bat` onto an USB stick or the same reachable cloud storage as `kickOff.ps1` as a backup plan in case the initial provisioning failed. 