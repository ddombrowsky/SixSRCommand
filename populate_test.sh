#!/bin/sh

# COMPLETLY UNTESTED!!!

SIXDB_USER=$MYSQL_USER
SIXDB_PASS=$MYSQL_PASS
SIXDB_SCHEMA=sixthstreet

echo "attempting to create database"
echo "create database $SIXDB_SCHEMA;" | mysql -u $SIXDB_USER -p $SIXDB_PASS 

echo "attempting to populate database"
bzcat dbdata.bz2 | mysql -u $SIXDB_USER -p $SIXDB_PASS $SIXDB_SCHEMA
