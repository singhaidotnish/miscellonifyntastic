# Miscellonifyntastic
###### miscello (from miscellaneous) + nify (amplify/fyn) + tastic

### with this one script (manage_packages.sh) you’ve got the full cycle covered:

#### Create / export a list of your current manually-installed packages:

> ./manage_packages.sh capture my-packages.txt


#### Reinstall from a list (on a fresh system):

> ./manage_packages.sh reinstall my-packages.txt


#### Keep it clean and updated:

##### Add/remove packages from the list (add, remove).

##### Check what changed vs your current system (diff).

##### Verify all packages exist in apt repos (verify).

##### Deduplicate & normalize (dedupe).