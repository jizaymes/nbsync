#!/bin/bash

# Temporary location on the local system
LOCALPATH="${PWD}/nbsyncdata"       		

# Temporary location within the container
INNERPATH=/syncdata              			

# Image to use to do the copying
IMAGE=ubuntu					 			

# Possible path to docker-compose  -- This is mainly here so it can work in cron -- may need to be modified on your system.
PATH=$PATH:/usr/bin:/usr/local/bin        	

# The path to the source instance -- this is expected to be a netbox-docker root folder
SRC_INSTANCE=/opt/netbox		 			

# Name of the instance, inferred by the path (/opt/netbox -> netbox)
SRC_INSTANCE_NAME=`basename $SRC_INSTANCE`  

# The path to the destination instance -- this is also expected to be a netbox-docker root folder
DST_INSTANCE=/opt/netboxlab      			

# Name of the instance..
DST_INSTANCE_NAME=`basename $DST_INSTANCE`	

## SHOULDN'T NEED TO TOUCH ANYTHING BELOW HERE

function prepare_localpath() {
	
	# Ensure the sync path exists, or die trying
	if [ ! -d $LOCALPATH ]; then
		mkdir -p $LOCALPATH

		if [ ! -d $LOCALPATH ]; then
			echo "Error making local path"
			exit 1
		fi
	fi
}

function stop_prod_netbox() {
	# Stop the production netbox instance
	cd $SRC_INSTANCE
	docker-compose stop 1>/dev/null
}

function stop_dev_netbox() {
	# Stop the development netbox instance
	cd $DST_INSTANCE
	docker-compose down -v 1>/dev/null
}

function create_dev_netbox() {
	# Create the development netbox instance 

	cd $DST_INSTANCE
	docker-compose create 1>/dev/null
}

function start_prod_netbox() {
	# Start up the prod netbox instance

	cd $SRC_INSTANCE
	docker-compose up -d 1>/dev/null
}

function start_dev_netbox() {
	# Start up the dev netbox instance

	cd $DST_INSTANCE
	docker-compose up -d 1>/dev/null
}

function sync_volumes() {
    # Wrapper function to backup and then restore volumes

	# Arguments
	#$1 SOURCE container name
	#$2 DEST container name
	#$3 SRC_PATH
  #$4 DST_PATH

	backup $1 $3 $4    # SOURCE SRC_PATH DST_PATH
	restore $2 $3 $4   # DEST   SRC_PATH DST_PATH
}

function backup() {

	# Arguments
	#$1 SOURCE Container name
	#$2 SRC_PATH  Source path within the container
  #$3 DST_PATH  Destination path on the bind mounted path for things like $INNERPATH/postgres or $INNERPATH/media

	# Uses global variables
	# LOCALPATH (syncdata at base OS level)
	# INNERPATH (mountpoint for syncdata within the container)
	# IMAGE (docker container image name)

	docker run --rm -td --name=nbsync_backup --volumes-from $1:ro -v $LOCALPATH:$INNERPATH $IMAGE 1>/dev/null
	docker exec nbsync_backup cp -Rp $2/. $3 1>/dev/null
	docker stop nbsync_backup 1>/dev/null

}

function restore() {
	
	# Arguments
	#$1 DEST Container Name
	#$2 SRC_PATH  Source path within the container like $INNERPATH/postgres
  #$3 DST_PATH  Destination path within the contaiiner


	# Uses global variables
	# LOCALPATH (syncdata at base OS level)
	# INNERPATH (mountpoint for syncdata within the container)
	# IMAGE (docker container image name)

	docker run --rm -td --name=nbsync_restore --volumes-from $1 -v $LOCALPATH:$INNERPATH $IMAGE 1>/dev/null
	docker exec nbsync_restore rm -rf $2/* 1>/dev/null
	docker exec nbsync_restore cp -Rp $3/. $2 1>/dev/null
	docker stop nbsync_restore 1>/dev/null
}

function cleanup() {

	# Clean up the data in the nbsyncdata folder
	rm -rf $LOCALPATH/* 1>/dev/null
}






## ----------------------------------------------------------- ##
##  Start
## ----------------------------------------------------------- ##

prepare_localpath
cleanup
stop_prod_netbox
stop_dev_netbox

create_dev_netbox

## ----------------------------------------------------------- ##

## Sync Postgres Data
SOURCE=$SRC_INSTANCE_NAME-postgres-1
DEST=$DST_INSTANCE_NAME-postgres-1
SRC_PATH=/var/lib/postgresql/data
DST_PATH=$INNERPATH/postgres

sync_volumes $SOURCE $DEST $SRC_PATH $DST_PATH

## ----------------------------------------------------------- ##

## Sync redis Data
SOURCE=$SRC_INSTANCE_NAME-redis-1
DEST=$DST_INSTANCE_NAME-redis-1
SRC_PATH=/data
DST_PATH=$INNERPATH/redis

sync_volumes $SOURCE $DEST $SRC_PATH $DST_PATH

## ----------------------------------------------------------- ##

## Sync netbox media Data
SOURCE=$SRC_INSTANCE_NAME-netbox-1
DEST=$DST_INSTANCE_NAME-netbox-1
SRC_PATH=/opt/netbox/netbox/media
DST_PATH=$INNERPATH/media

sync_volumes $SOURCE $DEST $SRC_PATH $DST_PATH

## ----------------------------------------------------------- ##

start_prod_netbox
start_dev_netbox
cleanup
