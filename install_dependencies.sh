#!/bin/bash

# Define installation directory
DIR=$HOME/.wrf_dependencies
mkdir -p $DIR

# Set environment variables for the installation process
export NETCDF=$DIR/netcdf
export CC=gcc
export CXX=g++
export FC=gfortran
export FCFLAGS="-m64 -fallow-argument-mismatch"
export F77=gfortran
export FFLAGS="-m64 -fallow-argument-mismatch"
export LDFLAGS="-L$NETCDF/lib -L$DIR/grib2/lib"
export CPPFLAGS="-I$NETCDF/include -I$DIR/grib2/include -fcommon"

# Number of cores for compilation
JOBS=4

# Function to download, extract, compile, and install libraries
install_lib() {
    local url=$1
    local dir_prefix=$2
    local config_options=$3

    local tar_file=${url##*/}
    local base_name=${tar_file%.tar.gz}
    local extract_dir="build_${base_name}_tmp"

    echo "Downloading $tar_file..."
    wget -q $url -O $tar_file || { echo "Error downloading $tar_file"; exit 1; }

    echo "Creating temp dir $extract_dir and extracting $tar_file..."
    mkdir -p "$extract_dir"
    tar xzvf "$tar_file" -C "$extract_dir" || { echo "Error extracting $tar_file"; exit 1; }

    local inner_dir=$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -z "$inner_dir" ]; then
        inner_dir="$extract_dir"
    fi

    echo "Entering directory: $inner_dir"
    cd "$inner_dir" || { echo "Could not enter $inner_dir"; exit 1; }

    echo "Configuring $(basename "$inner_dir")..."
    if [ ! -f configure ]; then
        echo "'configure' not found. Trying to generate it with autoreconf..."
        autoreconf -i || { echo "autoreconf failed"; exit 1; }
    fi

    ./configure --prefix="$dir_prefix" $config_options || { echo "Error configuring $(basename "$inner_dir")"; exit 1; }

    echo "Compiling $(basename "$inner_dir")..."
    make -j $JOBS || { echo "Compilation failed"; exit 1; }

    echo "Installing $(basename "$inner_dir")..."
    make install || { echo "Install failed"; exit 1; }

    cd ../..
    rm -rf "$tar_file" "$extract_dir"
    echo "$(basename "$inner_dir") installed successfully!"

    echo
    read -p "Press Enter to continue to the next library..."
}



# Install libraries
install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/zlib-1.2.11.tar.gz" "$DIR/grib2"

install_lib "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.5/src/hdf5-1.10.5.tar.gz" "$DIR/netcdf" "--with-zlib=$DIR/grib2 --enable-fortran --enable-shared"

install_lib "https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.7.2.tar.gz" "$DIR/netcdf" "--disable-dap --enable-netcdf4 --enable-hdf5 --enable-shared"

export LIBS="-lnetcdf -lz"
install_lib "https://github.com/Unidata/netcdf-fortran/archive/v4.5.2.tar.gz" "$DIR/netcdf" "--disable-hdf5 --enable-shared"

install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/mpich-3.0.4.tar.gz" "$DIR/mpich"

install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/libpng-1.2.50.tar.gz" "$DIR/grib2"

install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz" "$DIR/grib2"

# Set permanent environment variables in .bashrc
echo "Setting up permanent environment variables..."
cat <<EOF >> ~/.bashrc

# WRF Dependencies
export NETCDF=$DIR/netcdf
export LD_LIBRARY_PATH=\$NETCDF/lib:$DIR/grib2/lib
export PATH=\$NETCDF/bin:$DIR/mpich/bin:\$PATH
export JASPERLIB=$DIR/grib2/lib
export JASPERINC=$DIR/grib2/include
EOF

echo "Installation complete! Restart your terminal or run 'source ~/.bashrc' to apply the settings."

