#!/bin/bash

# push_daemon.sh
# a script to consistently convert, split, and send stuff across portkey

WATCHDIR=/opt/test
TRANSDIR=/opt/test/transfer
BASEURL="https://10.0.93.8/file/satelite6/"
MAX_SIZE=400M

if [ $(find $WATCHDIR -maxdepth 1 -type f -size +1c | wc -l) -eq 0 ]
then
  echo "No files in incoming directory, exiting"
  exit 0
fi

# grab the first file in that list
THEFILE=$(find $WATCHDIR -maxdepth 1 -type f | head -1)

# split the file up, keeping track of what's created
SPLITLIST=$(split -a2 -d -b ${MAX_SIZE} ${THEFILE} ${THEFILE}. --verbose | cut -d' ' -f3 | sed s/\’\//g | sed s/\‘//g )

# count the number of files split created
TOTALCNT=$(echo ${SPLITLIST}.?? | wc -w)
TOTALCNT=$(( ${TOTALCNT} - 1 ))

for file in ${SPLITLIST[@]}
do
  TRANSFILE=${TRANSDIR}/$(basename ${file}).transfer
  if [ -f ${TRANSFILE} ]
  then
    echo "Skipping ${file}, as it already has a transfer file present."
    continue
  fi
  echo Converting Part ${file}
  echo "This is a file generated by Red Hat in order to assist scanners, which are having trouble reading the verified Red Hat data below.  Please contact taylor@redhat.com if you have any concerns or issues." > ${file}.txt
  sha256sum ${file} >> ${file}.txt
  echo >> ${file}.txt
  cat ${file} | base64 >> ${file}.txt
# remove file part (pre-conversion)
  rm ${file}
  echo Uploading Part ${file}
#  curl -k -f -T ${file}.txt ${BASEURL}$(basename ${file})_of_${TOTALCNT}.txt > $TRANSFILE
#  remove file conversion
#  rm ${file}.txt
#  just a test mv for now:
   mv ${file}.txt /opt/test/$(basename ${file})_of_${TOTALCNT}.txt
done
# remove original from WATCHDIR
rm $THEFILE