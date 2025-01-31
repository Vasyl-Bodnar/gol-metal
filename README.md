# gol-metal
A straightforward Game of Life implemented in a compute shader and rendered to an Appkit created surface using Metal with a colored fragment shader.

## Build & Run
If any changes are made to the `default.metal` file, with XCode installed, make sure to run `xcrun --sdk macosx metal default.metal`. 
This will produce a necessery `.metallib` which is used by the executable.

Otherwise, `swift run` to run, and `swift build` to build an executable can be used as typical.

Note that this is not made in Xcode directly.
