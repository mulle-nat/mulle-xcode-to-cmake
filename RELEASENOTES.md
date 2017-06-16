#### 0.6.4

* added -w option, so that I can place MulleObjCLoader files last in sorted lists

#### 0.6.3

* added -i option, mainly to output `include_directories` in `CMakeSourcesAndHeaders.txt`
* modernize release mechanism

#### 0.6.2

* improve Framework target output for not APPLE case
* split off Releasenotes into separate file
* fixed missing `find_library` and `target_include_directories` emission when using -2

#### 0.6.1

* improve sexport reminder

### 0.6.0

* there is a new option `-2`. It generates a `CMakeLists.txt` that includes
a file called `CMakeSourcesAndHeaders.txt`. This is a file that you can generate
with an additional run of `mulle-xcode-to-cmake sexport`.

#### 0.5.4

* the reminder is now more readable

#### 0.5.3

* added another little hack for mulle-objc
* output commandline arguments in the reminder
* sexport now also prints the reminder

### 0.5.2

* add sexport command for generating source and header file lists
* added -l switch, also for mulle-objc to specify the project language
* fix a bug, when files are not group relative in Xcode

#### 0.4.1

* add a reminder how this file was generated. Actually useful sometimes.

### 0.4.0

* whitespace in target names is converted to '-'
* bundle targets are supported now
* added -n flag
* fix framework resource copy stage


### 0.3.0

* don't emit link commands for static library targets
* add -s option
* slight reorganization of code
* output filepaths sorted
* fix some bugs
* improved boiler-plate code


### 0.2.0

* output resources too
* allow to specify multiple targets
* fix more bugs
* add -u option, but iOS builds don't work anway
* somewhat half hearted attempt to also support applications and bundles
* quote paths with whitespace

### 0.1.0

* Fix some bugs. Add -p and -f options.


# 0.0

* Quickly hacked together from mulle-xcode-settings.
