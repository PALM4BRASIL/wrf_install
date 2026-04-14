#!/bin/bash

# Definindo o diretório de instalação
DIR=$HOME/.wrf_dependencies
mkdir -p $DIR

# funcao que instala o gcc 11.5
install_gcc() {
    local url="https://ftp.gnu.org/gnu/gcc/gcc-11.5.0/gcc-11.5.0.tar.xz"
    local tar_file=${url##*/}
    local src_dir="gcc-11.5.0"
    local build_dir="build_gcc"

    echo "Baixando GCC 11.5"
    wget -q $url -O $tar_file || { echo "Erro no download"; exit 1; }
    tar -xf $tar_file || { echo "Erro ao extrair"; exit 1; }

    cd $src_dir || exit 1

    echo "Baixando dependências..."
    ./contrib/download_prerequisites

    cd ..
    mkdir -p $build_dir
    cd $build_dir

    ../$src_dir/configure \
        --prefix=$DIR/gcc115 \
        --disable-multilib \
        --enable-languages=c,c++,fortran \
        --disable-nls --disable-libsanitizer || { echo "Erro no configure"; exit 1; }

    make -j $JOBS || { echo "Erro na compilação"; exit 1; }
    make install || { echo "Erro na instalação"; exit 1; }

    cd ..
    rm -rf $tar_file $src_dir $build_dir

    echo "GCC instalado com sucesso!"
    # tornando a instalação permanente
    echo "Adicionando GCC ao ~/.bashrc..."

    # evita duplicar linhas
    if ! grep -q "$DIR/gcc115/bin" ~/.bashrc; then 
cat <<EOF >> ~/.bashrc	
# GCC 11.5
export PATH=$DIR/gcc115/bin:\$PATH
EOF
    fi
    
    source ~/.bashrc
    sleep 5
}

# Verifica a instalacao do gcc 
if [ -x "$DIR/gcc115/bin/gcc" ]; then
    GCC_VERSION=$($DIR/gcc115/bin/gcc -dumpversion | cut -d. -f1)

    if [ "$GCC_VERSION" = "11" ]; then
        echo "GCC 11 já está instalado em $DIR/gcc115"
        USE_CUSTOM_GCC=true
    else
        echo "Foi encontrada uma versão alternativa ($GCC_VERSION), reinstalando..."
        install_gcc
        USE_CUSTOM_GCC=true
    fi

else
    # Verificando gcc do sistema
    if command -v gcc >/dev/null 2>&1; then
        SYS_GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)

        if [ "$SYS_GCC_VERSION" = "11" ]; then
            echo "GCC 11 já instalado"
            USE_CUSTOM_GCC=false
        else
            echo "Sistema tem GCC $SYS_GCC_VERSION, mas precisa ter o 11.5 instalado"
            install_gcc
            USE_CUSTOM_GCC=true
        fi
    else
        echo "GCC não encontrado no sistema, instalando"
        install_gcc
        USE_CUSTOM_GCC=true
    fi
fi


# Implementando as variáveis de ambiente
export NETCDF=$DIR/netcdf
export CC=gcc
export CXX=g++
export FC=gfortran
export FCFLAGS="-m64 -fallow-argument-mismatch"
export F77=gfortran
export FFLAGS="-m64 -fallow-argument-mismatch"
export LDFLAGS="-L$NETCDF/lib -L$DIR/grib2/lib"
export CPPFLAGS="-I$NETCDF/include -I$DIR/grib2/include -fcommon"

# Numero de cores utilizados na instalação
JOBS=4

# download, extract, compile, and install
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
    echo "$(basename "$inner_dir") Tudo certo com a instalação!"

    echo
    read -p "Aperte Enter para continuar..."
}



# Instalar bibliotecas
install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/zlib-1.2.11.tar.gz" "$DIR/grib2"

install_lib "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.5/src/hdf5-1.10.5.tar.gz" "$DIR/netcdf" "--with-zlib=$DIR/grib2" #--enable-fortran --enable-shared"

install_lib "https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.7.2.tar.gz" "$DIR/netcdf" "--disable-dap --enable-netcdf4 --enable-hdf5 --enable-shared"

export LIBS="-lnetcdf -lz"
install_lib "https://github.com/Unidata/netcdf-fortran/archive/v4.5.2.tar.gz" "$DIR/netcdf" "--disable-hdf5 --enable-shared"

install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/mpich-3.0.4.tar.gz" "$DIR/mpich"

install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/libpng-1.2.50.tar.gz" "$DIR/grib2"

install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz" "$DIR/grib2"

# setar as variáveis de forma permanente no ~/.bashrc 
echo "Setting up permanent environment variables..."
cat <<EOF >> ~/.bashrc

# WRF Dependencies
export NETCDF=$DIR/netcdf
export LD_LIBRARY_PATH=\$NETCDF/lib:$DIR/grib2/lib
export PATH=\$NETCDF/bin:$DIR/mpich/bin:\$PATH
export JASPERLIB=$DIR/grib2/lib
export JASPERINC=$DIR/grib2/include
EOF
echo "Instalação completa! 'source ~/.bashrc' para aplicar."
