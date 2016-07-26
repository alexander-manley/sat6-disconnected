#!/bin/bash

# push_daemon.sh
# a script to consistently convert, split, and send stuff across portkey

WATCHDIR=/opt/test
TRANSDIR=/opt/test/transfer
TMPDIR=/opt/test/transfer/temp
BASEURL="https://10.0.93.8/file/satelite6/"
MAX_SIZE=400M

# grab the first file in the watch dir
LIST="$(find $WATCHDIR -maxdepth 1 -type f -size +1c) exit"

# check incoming directory for files, quit if none
if [ $(echo $LIST | wc -l) -eq 0 ]
then
  exit 0
fi

for THEFILE in $LIST
do
  FILEBASE=$(basename ${THEFILE})

  # check for end-of-list keyword
  if [ $THEFILE == "exit" ]
  then
    echo "No files found, exiting"
    exit 0
  fi
  
  # check to see if this file has been handled by another process...
  if [ -f $TMPDIR/${FILEBASE}.inprogress ]
  then
    #exit 0
    echo $TMPDIR/${FILEBASE}.inprogress found, skipping.
  else
    break
  fi
done

touch $TMPDIR/${FILEBASE}.inprogress

# split the file up, keeping track of what's created
echo "$(date '+%Y%m%d - %H:%M:%S') Found ${THEFILE}, splitting..." 
SPLITLIST=$(split -a2 -d -b ${MAX_SIZE} ${THEFILE} $TMPDIR/${FILEBASE}. --verbose | cut -d' ' -f3 | sed s/\’\//g | sed s/\‘//g )

# count the number of files split created, zero-based
TOTALCNT=$(echo ${SPLITLIST}.?? | wc -w)
TOTALCNT=$(( ${TOTALCNT} - 1 ))

for file in ${SPLITLIST[@]}
do
  TRANSFILE=${TRANSDIR}/${FILEBASE}.transfer.$(date +%Y%m%d)
  if [ -f ${TRANSFILE} ]
  then
    echo "$(date '+%Y%m%d - %H:%M:%S') Skipping ${file}, as it already has a transfer file present."
    continue
  fi
  echo "$(date '+%Y%m%d - %H:%M:%S') Converting Part ${file}"
  echo "This is a file generated by Red Hat in order to assist scanners, which are having trouble reading the verified Red Hat data below.  Please contact taylor@redhat.com if you have any concerns or issues." > ${file}.txt
  sha256sum ${file} >> ${file}.txt
  echo >> ${file}.txt
  cat ${file} | base64 >> ${file}.txt
# remove file part (pre-conversion)
  rm ${file}
  retval=1
  while [ $retval -ne 0 ]
  do
    echo "$(date '+%Y%m%d - %H:%M:%S') Uploading Part ${file}"
    curl -q -k -f -T ${file}.txt ${BASEURL}$(basename ${file})_of_${TOTALCNT}.txt > $TRANSFILE
    retval=$?
    if [ $retval -ne 0 ]
    then
      echo "$(date '+%Y%m%d - %H:%M:%S') Curl returned error, retrying!"
      mv $TRANSFILE $TRANSFILE-$(date +%H%M%S)
      #exit 1
    else
#     remove file conversion
      rm ${file}.txt
      rm $TRANSFILE
    fi
  done
done
# remove original from WATCHDIR
rm $THEFILE
# remove lock
#rm $TRANSDIR/push_daemon_lock
touch $TMPDIR/${FILEBASE}.inprogress
