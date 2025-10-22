# Instalação automática do ambiente para WRF 4.6+
Este script foi desenvolvido para instalar automaticamente as dependências mínimas para a construção do WRF com o compilador GNU, mpich, zlib, hdf5, netcdf-c, netcdf-fortran, jasper e libpng.

### Como usar:

Torne o script executável:

```bash
chmod +x install_dependencies.sh
```

Execute-o com:

```
bash install_dependencies.sh
``` 

Após executar o script, o ambiente estará pronto para instalar o WRF e o WPS.

### WRF

```
git clone --recurse-submodule https://github.com/wrf-model/WRF.git
cd WRF
export WRF_DIR=$PWD
```
Como a construção é baseada em gnu, após executar o setup (escolha as opções 34 e depois 1).

```
./configure
```

Esta etapa é uma das mais demoradas e pode levar de 30 a 40 minutos.

```
./compile -j 4 em_real 2>&1 | tee compile.log
```

Verifique a instalação:

```
ls -lah main/*.exe
ls -lah run/*.exe
ls -lah test/em_real/*.exe
```
### WPS

```
cd ..
git clone https://github.com/wrf-model/WPS.git
cd WPS
```
(escolha a opção 1):

```
./configure 
```
em seguida:

```
./compile >& log.compile










