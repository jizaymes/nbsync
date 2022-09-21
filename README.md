# nbsync
Netbox data synchronization

Synchronize netbox-docker data between instances. I use this script to copy the data from our production netbox to our development netbox
every night. It essentially wipes out the dev instance with the production data.

This is pretty basic, so you're on your own.

Modify the nbsync.sh script to reflect your local paths, and docker-compose base container names, etc before running. Good luck
