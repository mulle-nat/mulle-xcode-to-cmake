# mulle-xcode-settings

A little tool to set Xcode build settings from the command line.

You can specify the target and the configuration to set. If you don't
specify a target, the setting is changed in the project. If you don't
specify a configuration, the setting will be applied to all configurations.

Therefore when you specify a target and a configuration only the setting in
that target for that configuration is affected.

Fork      |  Build Status | Release Version
----------|---------------|-----------------------------------
[Mulle kybernetiK](//github.com/mulle-nat/mulle-xcode-settings) | [![Build Status](https://travis-ci.org/mulle-nat/mulle-xcode-settings.svg?branch=release)](https://travis-ci.org/mulle-nat/mulle-xcode-settings) | ![Mulle kybernetiK tag](https://img.shields.io/github/tag/mulle-nat/mulle-xcode-settings.svg) [![Build Status](https://travis-ci.org/mulle-nat/mulle-xcode-settings.svg?branch=release)](https://travis-ci.org/mulle-nat/mulle-xcode-settings)


## Install

Use the [homebrew](//brew.sh) package manager to install it, or build
it yourself with Xcode:

```
brew install mulle-kybernetik/software/mulle-xcode-settings
```


## Usage

```
usage: mulle-xcode-settings [options] <commands> <file.xcodeproj>

Options:
   -c <configuration>          : configuration to set
   -t <target>                 : target to set
   -a                          : set on all targets

Commands:
   list                        : list all keys
   get     <key>               : get value for key
   set     <key> <value>       : sets key to value
   add     <key> <value>       : adds value to key
   insert  <key> <value>       : inserts value in front of key
   remove  <key> <value>       : removes value from key
   replace <key> <old> <value> : replace old value for key (if exists)

Environment:
   VERBOSE                     : dump some info to stderr
```

### Examples

List all current non-default project settings:

```console
$ mulle-xcode-settings list mulle-xcode-settings.xcodeproj
Targets:
   mulle-xcode-settings
   mullepbx
Project:
   Debug:
      CLANG_WARN_DIRECT_OBJC_ISA_USAGE="NO"
      CURRENT_PROJECT_VERSION="1.1.0"
      DEBUG_INFORMATION_FORMAT="dwarf"
      DYLIB_COMPATIBILITY_VERSION="$(CURRENT_PROJECT_VERSION)"
      DYLIB_CURRENT_VERSION="1.0.0"
      GCC_OPTIMIZATION_LEVEL="0"
      MACOSX_DEPLOYMENT_TARGET="10.4"
      OTHER_CFLAGS="-DCURRENT_PROJECT_VERSION=\"${CURRENT_PROJECT_VERSION}\""
   Release:
      CLANG_WARN_DIRECT_OBJC_ISA_USAGE="NO"
      CURRENT_PROJECT_VERSION="1.1.0"
      DEBUG_INFORMATION_FORMAT="dwarf"
      DYLIB_COMPATIBILITY_VERSION="$(CURRENT_PROJECT_VERSION)"
      DYLIB_CURRENT_VERSION="1.0.0"
      GCC_GENERATE_DEBUGGING_SYMBOLS="NO"
      MACOSX_DEPLOYMENT_TARGET="10.4"
      OTHER_CFLAGS="-DCURRENT_PROJECT_VERSION=\"${CURRENT_PROJECT_VERSION}\""
```

List all non-default project settings for target `mullepbx`:

```console
$ mulle-xcode-settings -t mullepbx list mulle-xcode-settings.xcodeproj
mullepbx:
   Debug:
      EXECUTABLE_PREFIX="lib"
      PRODUCT_NAME="$(TARGET_NAME)"
   Release:
      EXECUTABLE_PREFIX="lib"
      PRODUCT_NAME="$(TARGET_NAME)"
```

Change a setting in target `mullepbx` for configuration **Release**:

```console
$ mulle-xcode-settings -t mullepbx -c Debug set PRODUCT_NAME 'My Foo' mulle-xcode-settings.xcodeproj
```


Add a setting to the project then remove it again, leaving previous setting
unperturbed:

```console
$ mulle-xcode-settings add HEADER_SEARCH_PATHS '/usr/local/include' ./X.xcodeproj
$ mulle-xcode-settings remove HEADER_SEARCH_PATHS '/usr/local/include' ./X.xcodeproj
```


### History

This is basically a stripped down version of `mulle_xcode_utility`.

### Releasenotes

#### 1.1.0

* Added **list** command, which makes `mulle-xcode-settings` easier to use.


#### 1.0.6

* Changed option handling to -<short> and --<long> (but keep old flags for
  compatibility.


#### 1.0.5

* Added -alltargets
* Added -help


#### 1.0.4

* Adding a string to another string, creates a proper array of strings.
        (If the string isn't a duplicate).
        New command "insert" like add, but adds in front of previous value(s).


#### 1.0.3

* Fix moar compile problems that turned up in brew (why not earlier ?)


#### 1.0.2

* Fix some compile problems that turned up in brew (why not earlier ?)


#### 1.0.1

* Fixed a crasher due to multi-value settings


### Author

Coded by Nat!
