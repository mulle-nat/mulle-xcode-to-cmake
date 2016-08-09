# mulle-xcode-settings

A little tool to set Xcode build settings from the command line.

You can specify the target and the configuration to set. If you don't
specify a target, the setting is changed in the project. If you don't
specify a configuration, the setting will be applied to all configurations.

Therefore when you specify a target and a configuration only the setting in
that target for that configuration is affected.

## Usage

```
usage: mulle-xcode-settings [options] <commands> <file.xcodeproj>

Options:
   -configuration <configuration> : configuration to set
   -target <target>               : target to set

Commands:
   get     <key>                  : get value for key
   set     <key> <value>          : sets key to value
   add     <key> <value>          : adds value to key
   insert  <key> <value>          : inserts value in front of key
   remove  <key> <value>          : removes value from key
```

### Examples

```console
mulle-xcode-settings add HEADER_SEARCH_PATHS '/usr/local/include' ./X.xcodeproj
mulle-xcode-settings remove HEADER_SEARCH_PATHS '/usr/local/include' ./X.xcodeproj
```


### History

This is basically a stripped down version of `mulle_xcode_utility`.

### Releasenotes

1.0.4
=====

* Adding a string to another string, creates a proper array of strings.
        (If the string isn't a duplicate).
        New command "insert" like add, but adds in front of previous value(s).

1.0.3
=====

* Fix moar compile problems that turned up in brew (why not earlier ?)

1.0.2
=====

* Fix some compile problems that turned up in brew (why not earlier ?)

1.0.1
=====

* Fixed a crasher due to multi-value settings


### Author

Coded by Nat!
