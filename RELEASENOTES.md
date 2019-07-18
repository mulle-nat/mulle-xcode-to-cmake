## 0.9.0

* improved collection of localized resources
* modernized the emitted CMakeLists.txt for mulle-objc 0.16
* fix mulle-sde project
* update README install instructions
* fix incorrect group relative paths


### 0.8.1

* fix mulle-sde project
* update README install instructions
* fix incorrect group relative paths

## 0.8.0

* add a couple of suggestions and fix ideas by @saxbophone
* change boilerplate to support mulle-objc legacy style development
* added GNUSTEp code by @RJVB and @ElMostafaIdrassi
* boilerplate code migrated off mulle-bootstrap unto mulle-sde
* migrated project to mulle-sde
* remove mulle-configuration code since it is obsolete


### 0.7.1

* Modernized mulle-project packaging
* Removed unused files from project

## 0.7.0

* raise baseline to 10.6 for Xcode 10
* emit `INCLUDE_DIRS` now for newer mulle-configuration compatibility


### 0.6.6

* modernize formula generation

#### 0.6.5

* fix usage, update README.md

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
