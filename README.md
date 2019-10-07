# Obsolete

Someone reported that this script deleted their /usr/bin directory, so please be careful, if you do want to use this script, to check your parameters. After I wrote this script Sublime Text published packages which make the installation and update of ST3 much easier:

https://www.sublimetext.com/docs/3/linux_repositories.html

-------------------

# sublime-text-3-install
Shell script to install/update Sublime Text 3

Modify the shell script `sublime-text-3.sh` permissions and check **Execute: Allow executing file as program** and run the script.

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

The script installs Sublime Text 3 in the `/opt` folder by default, unless a different folder is specified as a parameter

The script installs the latest stable version of Sublime Text 3 by default, unless a specific version number is specified as a parameter.


Install the lated stable version:
```shell
cd sublime-text-3-install
chmod +x sublime-text-3.sh
./sublime-text-3.sh
```

Install the latest dev version:
```shell
./sublime-text-3.sh -d
```

Install a specific dev version in a non-standard folder:
```shell
./sublime-text-3.sh -d /usr/local 1234
```
This will install the Sublime Text version 1234 into the target folder `/usr/local`.

