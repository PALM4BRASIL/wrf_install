#!/bin/bash

# Definindo o diretório de instalação
DIR_WRF=$HOME/.wrf_dependencies
mkdir -p $DIR_WRF

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

    echo "Baixando dependências do GCC"
    ./contrib/download_prerequisites

    cd ..
    mkdir -p $build_dir
    cd $build_dir

    ../$src_dir/configure \
        --prefix=$DIR_WRF/gcc115 \
        --disable-multilib \ 
        --disable-default-pie\
        --enable-languages=c,c++,fortran \
        --disable-nls \
        --disable-libsanitizer || { echo "Erro no configure"; exit 1; }

    #make -j $JOBS || { echo "Erro na compilação"; exit 1; }
    # Vou modificar isso por hora, tá estourando a memoria quando roda em paralelo. É mais lento, porém resolve.
    make install || { echo "Erro na instalação"; exit 1; }

    cd ..
    rm -rf $tar_file $src_dir $build_dir

    echo "GCC instalado com sucesso!"
    
    # subindo no bashrc, para compor o sistema permanentemente
    echo "Adicionando GCC ao ~/.bashrc"

    # verifica se ja foi adicionado
    if ! grep -q "DIR_WRF/gcc115/bin" ~/.bashrc; then 
cat <<EOF >> ~/.bashrc	
# GCC 11.5
export PATH=DIR_WRF/gcc115/bin:\$PATH
# WRF Dependencies
export NETCDF=DIR_WRF/netcdf
export LD_LIBRARY_PATH=\$NETCDF/lib:DIR_WRF/grib2/lib
export PATH=\$NETCDF/bin:DIR_WRF/mpich/bin:\$PATH
export JASPERLIB=DIR_WRF/grib2/lib
export JASPERINC=DIR_WRF/grib2/include
EOF
    fi
    
    source ~/.bashrc
    sleep 5
}

# Verifica a instalacao do gcc 
if [ -x "DIR_WRF/gcc115/bin/gcc" ]; then
    GCC_VERSION=$($DIR_WRF/gcc115/bin/gcc -dumpversion | cut -d. -f1)

    if [ "$GCC_VERSION" = "11.5" ]; then
        echo "GCC 11 já está instalado em $DIR_WRF/gcc115"       
    else
        echo "Foi encontrada uma versão alternativa para o GCC: ($GCC_VERSION), reinstalando"
        install_gcc
    fi

else
    # Verificando gcc do sistema
    if command -v gcc >/dev/null 2>&1; then
        GCC_VERSION=$(gcc -dumpversion | cut -d. -f1)

        if [ "$GCC_VERSION" = "11.5" ]; then
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
export NETCDF=$DIR_WRF/netcdf
export CC=gcc
export CXX=g++
export FC=gfortran
export FCFLAGS="-m64 -fallow-argument-mismatch"
export F77=gfortran
export FFLAGS="-m64 -fallow-argument-mismatch"
export LDFLAGS="-L$NETCDF/lib -L$DIR_WRF/grib2/lib"
export CPPFLAGS="-I$NETCDF/include -I$DIR_WRF/grib2/include -fcommon"

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
    
    echo "Downloading $tar_file"
    wget -q $url -O $tar_file || { echo "Error downloading $tar_file"; exit 1; }
    
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

    echo "Compilando $(basename "$inner_dir")"
    make -j $JOBS || { echo "Compilation failed"; exit 1; }

    echo "Instalando $(basename "$inner_dir")"
    make install || { echo "Install failed"; exit 1; }

    cd ../..
    rm -rf "$tar_file" "$extract_dir"
    echo "$(basename "$inner_dir") Tudo certo com a instalação!"
    sleep 2
}



# Instalar bibliotecas
install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/zlib-1.2.11.tar.gz" "$DIR_WRF/grib2"
install_lib "https://support.hdfgroup.org/ftp/HDF5/releases/hdf5-1.10/hdf5-1.10.5/src/hdf5-1.10.5.tar.gz" "$DIR_WRF/netcdf" "--with-zlib=$DIR_WRF/grib2 --enable-fortran --enable-shared"
install_lib "https://github.com/Unidata/netcdf-c/archive/refs/tags/v4.7.2.tar.gz" "$DIR_WRF/netcdf" "--disable-dap --enable-netcdf4 --enable-hdf5 --enable-shared"

export LIBS="-lnetcdf -lz"
# estava ocorrendo alguns erros quanto a compilação do netcdf-fortran
export NETCDF=$DIR_WRF/netcdf
export LD_LIBRARY_PATH=$NETCDF/lib:$LD_LIBRARY_PATH

install_lib "https://github.com/Unidata/netcdf-fortran/archive/v4.5.2.tar.gz" "$DIR_WRF/netcdf" "--disable-hdf5 --enable-shared"
install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/mpich-3.0.4.tar.gz" "$DIR_WRF/mpich"
install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/libpng-1.2.50.tar.gz" "$DIR_WRF/grib2"
install_lib "https://www2.mmm.ucar.edu/wrf/OnLineTutorial/compile_tutorial/tar_files/jasper-1.900.1.tar.gz" "$DIR_WRF/grib2"

# setar as variáveis de forma permanente no ~/.bashrc 
echo "Setting up permanent environment variables"
cat <<EOF >> ~/.bashrc

# WRF Dependencies
export NETCDF=$DIR_WRF/netcdf
export LD_LIBRARY_PATH=\$NETCDF/lib:$DIR_WRF/grib2/lib
export PATH=\$NETCDF/bin:$DIR_WRF/mpich/bin:\$PATH
export JASPERLIB=$DIR_WRF/grib2/lib
export JASPERINC=$DIR_WRF/grib2/include
EOF
echo "Instalação completa!"
source ~/.bashrc
