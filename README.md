# Miscellonifyntastic
miscello (from miscellaneous) + nify (amplify/fyn) + tastic


#### Reinstall basic needs in xubuntu

chmod +x bootstrap.sh

# Install everything incl. Resolve deps and NVIDIA:
./bootstrap.sh extras

# Skip Resolve deps:
./bootstrap.sh extras --no-resolve-deps

# Full sequence (capture -> reinstall -> extras):
./bootstrap.sh all

