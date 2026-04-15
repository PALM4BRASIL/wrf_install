#!/bin/bash

# Definindo o diretório de instalação
DIR=$HOME/.wrf_dependencies
mkdir -p $DIR

# funcao que instala o gcc 11.5
install_gcc() {
    local tar_file="gcc-11.5.0.tar.xz"
    local src_dir="gcc-11.5.0"
    local build_dir="build_gcc"

    echo "Baixando GCC 11.5"
    wget -q $url -O $tar_file || { echo "Erro no download"; exit 1; }
    tar -xf $tar_file || { echo "Erro ao extrair"; exit 1; }

    cd $src_dir || exit 1

    echo "Baixando dependências"
    ./contrib/download_prerequisites

    cd ..
    mkdir -p $build_dir
    cd $build_dir

    ../$src_dir/configure \
        --prefix=$DIR/gcc115 \
        --disable-multilib  --disable-default-pie\
        --enable-languages=c,c++,fortran \
        --disable-nls --disable-libsanitizer || { echo "Erro no configure"; exit 1; }

    make -j $JOBS || { echo "Erro na compilação"; exit 1; }
    make install || { echo "Erro na instalação"; exit 1; }

    cd ..
    rm -rf $tar_file $src_dir $build_dir

    echo "GCC instalado com sucesso!"
    # tornando a instalação permanente
    echo "Adicionando GCC ao ~/.bashrc"

    # evita duplicar linhas
    if ! grep -q "$DIR/gcc115/bin" ~/.bashrc; then 
cat <<EOF >> ~/.bashrc	
# GCC 11.5
export PATH=$DIR/gcc115/bin:\$PATH
# WRF Dependencies
export NETCDF=$DIR/netcdf
export LD_LIBRARY_PATH=\$NETCDF/lib:$DIR/grib2/lib
export PATH=\$NETCDF/bin:$DIR/mpich/bin:\$PATH
export JASPERLIB=$DIR/grib2/lib
export JASPERINC=$DIR/grib2/include
EOF
    fi
    
    source ~/.bashrc
    sleep 5
}

# Verifica a instalacao do gcc 
if [ -x "$DIR/gcc115/bin/gcc" ]; then
    GCC_VERSION=$($DIR/.gcc115/bin/gcc -dumpversion | cut -d. -f1)

    if [ "$GCC_VERSION" = "11" ]; then
        echo "GCC 11 já está instalado em $DIR/gcc115"       
    else
        echo "Foi encontrada uma versão alternativa para o GCC: ($GCC_VERSION), reinstalando"
        install_gcc
    fi

else
    # Verificando gcc do sistema
    if command -v gcc >/dev/null 2>&1; then
        GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)

        if [ "$GCC_VERSION" = "11" ]; then
            echo "GCC 11 já instalado"
        else
            echo "Sistema tem GCC $GCC_VERSION, mas precisa ter o 11.5 instalado"
            install_gcc
        fi
    else
        echo "GCC não encontrado no sistema, instalando"
        install_gcc
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
    set -e
    local url=$1
    local dir_prefix=$2
    local config_options=$3

    local tar_file=${url##*/}
    local base_name=${tar_file%.tar.gz}
    local extract_dir="build_${base_name}_tmp"

    mkdir -p "$extract_dir"
    tar xzvf "$tar_file" -C "$extract_dir" || { echo "Error extracting $tar_file"; exit 1; }

    local inner_dir=$(find "$extract_dir" -mindepth 1 -maxdepth 1 -type d | head -n 1)
    if [ -z "$inner_dir" ]; then
        inner_dir="$extract_dir"
    fi

    cd "$inner_dir" || { echo "Could not enter $inner_dir"; exit 1; }

    if [ ! -f configure ]; then
        echo "'configure' not found. Trying to generate it with autoreconf"
        autoreconf -i || { echo "autoreconf failed"; exit 1; }
    fi

    ./configure --prefix="$dir_prefix" $config_options || { echo "Error configuring $(basename "$inner_dir")"; exit 1; }

    echo "Compiling $(basename "$inner_dir")"
    make -j $JOBS || { echo "Compilation failed"; exit 1; }

    echo "Installing $(basename "$inner_dir")"
    make install || { echo "Install failed"; exit 1; }

    cd ../..
    rm -rf "$tar_file" "$extract_dir"
    echo "$(basename "$inner_dir") Tudo certo com a instalação!"
    sleep 2
}



# Instalar bibliotecas
install_lib "zlib-1.2.11.tar.gz" "$DIR/grib2"
install_lib "hdf5-1.10.5.tar.gz" "$DIR/netcdf" "--with-zlib=$DIR/grib2"
install_lib "v4.7.2.tar.gz" "$DIR/netcdf" "--disable-dap --enable-netcdf4 --enable-hdf5 --enable-shared"

export LIBS="-lnetcdf -lz"
install_lib "v4.5.2.tar.gz" "$DIR/netcdf" "--disable-hdf5 --enable-shared"
install_lib "mpich-3.0.4.tar.gz" "$DIR/mpich"
install_lib "libpng-1.2.50.tar.gz" "$DIR/grib2"
install_lib "jasper-1.900.1.tar.gz" "$DIR/grib2"

# setar as variáveis de forma permanente no ~/.bashrc 
echo "Setting up permanent environment variables"
cat <<EOF >> ~/.bashrc

# WRF Dependencies
export NETCDF=$DIR/netcdf
export LD_LIBRARY_PATH=\$NETCDF/lib:$DIR/grib2/lib
export PATH=\$NETCDF/bin:$DIR/mpich/bin:\$PATH
export JASPERLIB=$DIR/grib2/lib
export JASPERINC=$DIR/grib2/include
EOF
echo "Instalação completa!"
source ~/.bashrc
