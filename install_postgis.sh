#!/bin/bash

DB_NAME=osm

GEOSVERSION=3.4.0
POSTGIS_VERSION=$POSTGIS_VERSION
PG_VERSION=9.3
GDAL_VERSION=1.9.2
SRC_DIR=/home/


sudo /etc/init.d/postgresql stop

function upgrade_postgis{ 

# install any missing prerequisites
sudo aptitude install gdebi build-essential checkinstall  \
  postgresql-server-dev-9.3 libjson0-dev libxml2-dev libproj-dev \
  python2.7-dev swig binutils
 
mkdir -p $SRC_DIR

echo "Downloading and compiloing GEOS" 
# download and compile geos in /opt/geos
cd $SRC_DIR
wget http://download.osgeo.org/geos/geos-$GEOSVERSION.tar.bz2
tar xvjf geos-$GEOSVERSION.tar.bz2
cd geos-$GEOSVERSION/
./configure --prefix=/opt/geos --enable-python
make -j2
sudo checkinstall  # uninstall with: dpkg -r geos
sudo gdebi geos_$GEOSVERSION-1_amd64.deb

echo "Downloading and compiloing GDAL" 
# download and compile gdal in /opt/gdal
cd $SRC_DIR
wget http://download.osgeo.org/gdal/gdal-$GDALVERSION.tar.gz
tar xvzf gdal-$GDALVERSION.tar.gz
cd gdal-$GDALVERSION/
./configure --prefix=/opt/gdal --with-geos=/opt/geos/bin/geos-config \
  --with-pg=/usr/lib/postgresql/9.3/bin/pg_config --with-python
make -j2
sudo checkinstall  # uninstall with: dpkg -r gdal
sudo gdebi gdal_$GDAL_VERSION-1_amd64.deb
 
echo "Downloading and compiloing PostGIS"
# download and compile postgis 2 in default location
cd $SRC_DIR
wget http://www.postgis.org/download/postgis-$POSTGIS_VERSION.tar.gz
tar xvzf postgis-$POSTGIS_VERSION.tar.gz
cd postgis-$POSTGIS_VERSION/
./configure --with-geosconfig=/opt/geos/bin/geos-config \
  --with-gdalconfig=/opt/gdal/bin/gdal-config
make -j2
sudo checkinstall  # uninstall with: dpkg -r postgis
sudo gdebi postgis_$POSTGIS_VERSION-1_amd64
 
# for command-line tools, append this line to .profile/.bashrc/etc.
export PATH=$PATH:/opt/geos/bin:/opt/gdal/bin
 
# so libraries are found, create /etc/ld.so.conf.d/geolibs.conf
# with these two lines:
echo "/opt/geos/lib
/opt/gdal/lib" >> geolibs.conf
 
# then
sudo ldconfig
 
sudo /etc/init.d/postgresql start
}

function restore_postgisDB{
	# Migrate a previous PostGIS DB into the newly installed version
	# supply the DB name to be used for the latest postgis DB and
	# a file path to the pg_dump -Fc backup from an earlier PostGIS version
	echo 'create database -E UTF8 $DB_NAME;' | sudo -u postgres psql
	echo 'create extension postgis; create extension postgis_topology;' \
	  | sudo -u postgres psql -d $DB_NAME
	/usr/share/postgresql/$PG_VERSION/contrib/postgis-$PG_VERSION/postgis_restore.pl \
	  /path/to/mydb.dump \
	  | sudo -u postgres psql -d $DB_NAME
}
