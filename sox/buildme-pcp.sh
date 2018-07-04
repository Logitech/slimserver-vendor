#!/bin/sh

#pCP package Dependancies
tce-load -i git compiletc automake gettext-dev

FLAC=1.3.2
SOX=14.4.2
OGG=1.3.3
VORBIS=1.3.6
MAD=0.15.1b
WAVPACK=5.1.0
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
ARCH="pCP"
OUTPUT=$PWD/sox-build-$ARCH-$CHANGENO
CORES=$(grep -c ^processor /proc/cpuinfo)

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf sox-$SOX
rm -rf libogg-$OGG
rm -rf libvorbis-$VORBIS
rm -rf libmad-$MAD
rm -rf wavpack-$WAVPACK

#armv6
export CFLAGS="-O2 -pipe -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard"
export CXXFLAGS="-O2 -pipe -fno-exceptions -fno-rtti -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp"

#armv7
#export CFLAGS="-mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -O2 -pipe"
#export CXXFLAGS=" -mcpu=cortex-a7 -mfpu=neon-vfpv4 -mfloat-abi=hard -O2 -pipe -fno-exceptions -fno-rtti"

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

## Build Ogg first
#echo "Untarring libogg-$OGG.tar.gz..."
#tar -xf libogg-$OGG.tar.gz
echo "Cloning ligogg....."
[ -d libogg-$OGG ] || git clone https://github.com/xiph/ogg.git libogg-$OGG >> $LOG
cd libogg-$OGG
#. ../../CPAN/update-config.sh
[ -x configure ] || ./autogen.sh >> $LOG
echo "Configuring..."
./configure --disable-shared >> $LOG
echo "Running make..."
make -j $CORES >> $LOG
cd ..

## Build Vorbis
echo "Untarring libvorbis-$VORBIS.tar.gz..."
tar -xf libvorbis-$VORBIS.tar.gz
cd libvorbis-$VORBIS
#. ../../CPAN/update-config.sh
echo "Configuring..."
./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs --disable-shared >> $LOG
echo "Running make"
make -j $CORES >> $LOG
cd ..

## Build FLAC
#echo "Untarring flac-$FLAC.tar.gz..."
#tar -xf flac-$FLAC.tar.xz
echo "Cloning FLAC....."
[ -d flac-$FLAC ] || git clone --depth 1 https://github.com/xiph/flac.git flac-$FLAC >> $LOG
cd flac-$FLAC
patch -p1 < ../01-flac.patch
#. ../../CPAN/update-config.sh
[ -x configure ] || ./autogen.sh >> $LOG
echo "Configuring..."
./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-shared --disable-xmms-plugin --disable-cpplibs >> $LOG
echo "Running make"
make -j $CORES >> $LOG
cd ..

## Build LibMAD
echo "Untarring libmad-$MAD.tar.gz..."
tar -xf libmad-$MAD-8.tar.gz
cd libmad-$MAD
#. ../../CPAN/update-config.sh
# Remove -fforce-mem line as it doesn't work with newer gcc
sed -i 's/-fforce-mem//' configure
echo "configuring..."
./configure --disable-shared >> $LOG
echo "Running make"
make -j $CORES >> $LOG
cd ..

## Build Wavpack
echo "Untarring wavpack-$WAVPACK.tar.bz2..."
tar -xf wavpack-$WAVPACK.tar.bz2
cd wavpack-$WAVPACK
#. ../../CPAN/update-config.sh
echo "Configuring..."
./configure --disable-shared >> $LOG
echo "Running make"
make -j $CORES>> $LOG
# sox looks for wavpack/wavpack.h so we need to make a symlink
cd include
ln -s . wavpack
cd ../..

## finally, build SOX against FLAC
echo "Untarring sox-$SOX.tar.gz..."
tar -xf sox-$SOX.tar.gz >> $LOG
cd sox-sox-$SOX >> $LOG
#. ../../CPAN/update-config.sh
autoreconf -i
echo "Configuring..."
CPF="-I$PWD/../libogg-$OGG/include -I$PWD/../libvorbis-$VORBIS/include -I$PWD/../wavpack-$WAVPACK/include -I$PWD/../flac-$FLAC/include -I$PWD/../libmad-$MAD" 
export LDFLAGS="-L$PWD/../libogg-$OGG/src/.libs -L$PWD/../libvorbis-$VORBIS/lib/.libs -L$PWD/../wavpack-$WAVPACK/src/.libs -L$PWD/../libmad-$MAD/.libs -L$PWD/../flac-$FLAC/src/libFLAC/.libs"
export CFLAGS="$CFLAGS $CPF"
./configure --with-pulseaudio=no --with-flac --with-oggvorbis --with-mp3 --with-wavpack --without-id3tag --without-lame --without-ffmpeg --without-png --without-ladspa --disable-shared --without-oss --without-alsa --disable-symlinks --without-coreaudio --prefix $OUTPUT >> $LOG
echo "Running make"
make -j $CORES >> $LOG
echo "Running make install"
make install >> $LOG
cd ..

strip --strip-unneeded $OUTPUT/bin/*

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf sox-$SOX
rm -rf libogg-$OGG
rm -rf libvorbis-$VORBIS
rm -rf libmad-$MAD
rm -rf wavpack-$WAVPACK
