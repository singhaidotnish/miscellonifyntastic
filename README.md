# Miscellonifyntastic
miscello (from miscellaneous) + nify (amplify/fyn) + tastic

#### Two steps to reinstall 

#####1. > chmod +x ~/bootstrap.sh
> ./bootstrap.sh reinstall ~/my-packages.txt
#####2. > chmod +x restore_from_capture.sh
> ./restore_from_capture.sh ~/system-capture-YYYYMMDD-HHMMSS


#### Reinstall basic needs in xubuntu

chmod +x bootstrap.sh

./bootstrap.sh capture my-packages.txt

#### Reinstall from list:

./bootstrap.sh reinstall my-packages.txt

#### Install extras (GPU, AV, Dev, Docker, Timeshift, tools):

./bootstrap.sh extras

#### Skip GPU stuff:

./bootstrap.sh extras --no-gpu

#### Do all steps in sequence:

./bootstrap.sh all

#### Install everything incl. Resolve deps and NVIDIA:
./bootstrap.sh extras

#### Skip Resolve deps:
./bootstrap.sh extras --no-resolve-deps

#### Full sequence (capture -> reinstall -> extras):
./bootstrap.sh all

