On Windows, using GNUstep shell and CMake, the build fails at link-time with the following type of error : 

```
undefined reference to objc_get_class 
```

The executed command by CMake is the following : 

```
/C/GNUstep/bin/gcc.exe    -Wl,--enable-auto-import -shared-libgcc -fexceptions -fgnu-runtime -L/usr/home/user/GNUstep/Library/Libraries -L/GNUstep/Local/Library/Libraries -L/GNUstep/System/Library/Libraries -lgnustep-base -lobjc -lws2_32 -ladvapi32 -lcomctl32 -luser32 -lcomdlg32 -lmpr -lnetapi32 -lm -I. -Wl,--whole-archive CMakeFiles/mulle-xcode-to-cmake.dir/objects.a -Wl,--no-whole-archive -Wl,--whole-archive libmullepbx.a -Wl,--no-whole-archive -o mulle-xcode-to-cmake.exe -Wl,--out-implib,libmulle-xcode-to-cmake.dll.a -Wl,--major-image-version,0,--minor-image-version,0 @CMakeFiles/mulle-xcode-to-cmake.dir/linklibs.rsp
```

As we can see, gcc is called with the linked libraries appearing first (-l...), then the sources appearing after them (.a).
This leads to the libraries not being linked, as the symbols in them are not yet encountered.
Using ```-Wl,--no-as-needed``` does not fix the problem.

The following manual solution fixes the issue : 

1 / Run CMake from the build directory:

```
         i.e. mkdir build && cd build 
         cmake -G"MSYS Makefiles" .. -Wno-dev -DCMAKE_VERBOSE_MAKEFILE=ON
```

2 / Go to CMakeFiles/mulle-xcode-to-cmake.dir in the build directory

3 / Open build.make 

4 / Find the last gcc call. Make sure to have .a appear before -l, something like the following : 

```
/C/GNUstep/bin/gcc.exe -Wl,--whole-archive CMakeFiles/mulle-xcode-to-cmake.dir/objects.a -Wl,--no-whole-archive -Wl,--whole-archive libmullepbx.a -Wl,--no-whole-archive   -Wl,--enable-auto-import -shared-libgcc -fexceptions -fgnu-runtime -L/usr/home/user/GNUstep/Library/Libraries -L/GNUstep/Local/Library/Libraries -L/GNUstep/System/Library/Libraries -lgnustep-base -lobjc -lws2_32 -ladvapi32 -lcomctl32 -luser32 -lcomdlg32 -lmpr -lnetapi32 -lm -I.  -o mulle-xcode-to-cmake.exe -Wl,--out-implib,libmulle-xcode-to-cmake.dll.a -Wl,--major-image-version,0,--minor-image-version,0 @CMakeFiles/mulle-xcode-to-cmake.dir/linklibs.rsp
```

5 / Open linklibs.rsp and delete libmullepbx.a 

6 / Now, call ```make```
