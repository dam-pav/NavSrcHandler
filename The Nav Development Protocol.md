# The Nav Development Protocol

The protocol is a set of steps that make sure your development artifacts are trackable and resilitent. It is not so much about source versioning and tracking as about making sure that source doesn't get lost. But, it also provides means to track versions and changes.

The protocol can be viewed as two separate, but essential processes.

1. Development
2. Deployment

## Development

Your development has two dimensions.

1. Development task goals (or User Story)
2. Time, in sessions.

Your develoment efforts come in sessions that can take as little time as necessary to achieve your development task goals, or as much as you can achieve in one work day. Never longer. 

Each development session must end with you gathering all the objects that you modified for the purpose of your task goals, regardless of when, and save them as a text objects file.

For instance. You have a Projects folder containing Customer folders. Each customer has its own folder. Each task for this customer has its own folder within the customer folder.

You start developing an Item Card customization on March 1st 2028. In your customer folder you will create a task folder named  - `TaskId - Item Card Customization` (where TaskID should be the actual identifier). In this folder you will create a subfolder named `_code`. The task might require other subfolders, for documentation and such, so this structure lets you keep the code tidy and separate. The naming conventions you will use may vary to suit your preferences, but the folder structure should be followed.

In `_code `you create a subfolder per each development session. Your first subfolder will therefore be named `280301`. When you are ready to round up your first session, you will save the modified objects in a file named `DEV.txt`.

The next day you return to the task at hand. Create a new subfolder in `_code` named `280302`. At the end of the day save the modified objects in this new folder, again in a file named `DEV.txt`.

Typical folder structure:

> - Projects
>   
>   - Customer 1
>     
>     - TaskId01 - task 1 description
>       
>       - _code
>         
>         - 280301
>         
>         - 280302
>         
>         - 280305
>         
>         - 280315
>       
>       - API specs
>       
>       - data samples
>     
>     - TaskId02 - task 2 description
>       
>       - ...
>   
>   - Customer 2
>     
>     - ...

By doing this after each session, you are making sure that:

- you can keep track of what you did during each session
- you do not lose any work because of external reasons such as:
  - another developer overwriting your changes because he needed to work on the same objects
  - the development database was overwritten or removed entirely
  - etc.

## Deployment

All your development task goals are achieved and you need to prepare a deployment package. Your last session is stored in the subfolder named `280315`.

All your activity up to this point was done in your development environment. The deployment target has to be a different environment, be it functional testing, UAT or even production.

Based on the final state of your development, compile a list of objects modified and use it to prepare object id filters, one per each object type. For instance:

* Pages: 30|31|36
* Tables: 27|90
* Codeunits: 21|22

Open the target environment, apply the filters you prepared, mark the objects, and export all marked objects into the last session subfolder (`280315`) in a file named `TST.txt` or `UAT.txt`, or `PRD.txt`, according to what is the target environment. Why, because if testing is approved you will eventually proceed to a different and ultimately the production target environment and you want the target object sets kept separated.

Use the Nav development cmdlets in Powershell (`Split-NAVApplicationObjectFile`) to split the objects into another level of subfolders. You will need a subfolder for the original objects per each environment. In this instance you will create subfolders in `280315` named `DEV` and `TST`, if you are deploying to a test environment. Make a copy of each original object subfolder, `DEV` to `DEV2MRG`, `TST` to `TST2MRG`. You will use `*2MRG` folders to actually compare objects and merge the changes.

Compare and merge as necessary.

Use the Nav development cmdlets in Powershell (`Join-NAVApplicationObjectFile`) to build a txt object package from the merge folder, in this instance `TST2MRG`, and save it in a new file named `TST2MRG.txt`.

You can import the package into the target environment directly, except for production. Compile and verify.

Importing into production environment requires additional cautionary steps. You need a staging environment, ideally a daily copy of the production environment. Import the txt package, compile and verify, then export the same object set as compiled binary (.fob). Name this file TaskId.Deployment.280315.fob (where TaskID should be the actual identifier) and place it at the task subfolder root, in this example `TaskId - Item Card Customization`. In case of iterated deployment you will have a clear view of your deployment attempts.
