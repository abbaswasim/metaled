# Metal Education

Metal Education is very simple metal learning excercise.
The project loads an animated model and displays it using glfw. Everything can be built from command line using make without going into xcode or calling xcode from command line.

## Platforms

* MacOS

## Build

This project can be built using `CMake` minimum version 3.6.

```bash
git clone --recurse-submodules https://github.com/abbaswasim/metaled.git && cd metaled && mkdir build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Debug
make -j8
```
## Third party

This project uses the following third party software as submodules.

* [Roar](https://github.com/abbaswasim/roar)
* [CImg](https://cimg.eu)
* [GLFW](https://github.com/glfw/glfw)

## License

The code is licensed under Apache 2.0.
