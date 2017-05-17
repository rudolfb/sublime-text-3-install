# sublime-text-3-install
Shell script to install/update Sublime Text 3

Modify the shell script `sublime-text-3.sh` permissions and check **Execute: Allow executing file as program**

```shell
cd sublime-text-3-install
chmod +x sublime-text-3.sh
./sublime-text-3.sh
```

```
Usage: {script} [ OPTIONS ] TARGET BUILD

  TARGET        Installation target. Default target is "/opt".
  BUILD         Build number, e.g. 3126. If not defined uses a Sublime Text 3 
                  web service to retrieve the latest stable or dev version number.

OPTIONS
  -h, --help    Displays this help message.
  -d, --dev     Install the dev version
  -s, --stable  Install the stable version (default)
  
Report bugs to Rudolf Bargholz <https://github.com/rudolfb/sublime-text-3-install>
```
