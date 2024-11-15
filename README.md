# MistOS
A Raspberry Pi distribution for running Steam Link.

## Building
```bash
docker run --rm -v $(pwd)/src:/distro --device /dev/loop-control --privileged guysoft/custompios:devel build -d
```