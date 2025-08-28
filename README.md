# Miscellonifyntastic
miscello (from miscellaneous) + nify (amplify/fyn) + tastic


#### Reinstall basic needs in xubuntu

chmod +x bootstrap.sh

Run with options:

    Save current package list:

./bootstrap.sh capture my-packages.txt

Reinstall from list:

./bootstrap.sh reinstall my-packages.txt

Install extras (GPU, AV, Dev, Docker, Timeshift, tools):

./bootstrap.sh extras

Skip GPU stuff:

./bootstrap.sh extras --no-gpu

Do all steps in sequence:

./bootstrap.sh all
