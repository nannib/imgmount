#!/bin/bash 
#
# ImgMount - by Nanni Bassetti - digitfor@gmail.com - http://www.nannibassetti.com 
# release: 1.0
#
# It mounts a DD/EWF image file or a block device, it needs TSK and XMount and YAD (Yet Another Dialog)
#

check_cancel()
{
	if [ $? -gt 0 ]; then
		exit 1
		break
	fi
}

if [ "$(id -ru)" != "0" ];then
	gksu -k -S -m "Enter root password to continue" -D "Xall requires root user priveleges." echo
fi

yad --title="ImgMount" --width="300" --text "Welcome to ImgMount 1.0\n by Nanni bassetti\n http://www.nannibassetti.com\n The program ends with the message 'Operation succeeded!', so wait..."
check_cancel 



get_image_type()
{
    IMG_TYPE=$(img_stat ${imm[@]} | grep "Image Type:")
    IMG_TYPE=${IMG_TYPE#*:}
    case $IMG_TYPE in
        *raw) ITYPE=dd ;;
        *ewf) ITYPE=ewf ;;
    esac
    export ITYPE
}

mount_split_image()
{
    if [ ${#imm[@]} -gt 1 ] || [ "$ITYPE" = "ewf" ]
    then
    
        MNTPNT=$outputdir/tmp
        mkdir -p $MNTPNT
        xmount --in $ITYPE --out dd ${imm[@]} $MNTPNT
        imm=$MNTPNT/$(ls $MNTPNT|grep ".dd")
        yad --title="ImgMount" --width="300" --text "Virtual dd image created at $imm\n"
        echo "Virtual dd image created at $imm" >&2
    else
        imm=$(readlink -f ${imm})
    fi
    export imm
}

while :
do
   outputdir="$(yad --file-selection --directory \
	--height 400 \
	--width 600 \
	--title "Insert destination directory mounted in rw " \
	--text " Select or create a directory (e.g. /media/sdb1/results) \n")"
	outputdir="$(echo $outputdir | tr "|" " ")"
check_cancel

   [[ "${outputdir:0:1}" = / ]] && { 
      [[ ! -d $outputdir ]] && mkdir $outputdir
      break
   }
   check_cancel
done

while :
do
   imm="$(yad --file-selection \
	--multiple \
	--height 400 \
	--width 600 \
	--title "Disk Image or Device Selection" \
	--text " Insert image file or dev (e.g. /dev/sda or disk.img)\nIf image is split, select all image segments (shift-click).\n")"
	imm="$(echo $imm | tr "|" " ")"
	
	get_image_type
	mount_split_image

imm=$imm

[[ -f $imm || -b $imm || -L $imm ]] && break
 
  check_cancel
done

(! mmls $imm 2>/dev/null 1>&2) && {
   yad --title="ImgMount " --text "The starting sector is '0'\n"
check_cancel 
   so=0
} || {

m=$(mmls -B $imm)  
p="$(yad --title="MMLS output" --width="600" --text "$m\n" \
--form \
 --field="Choose the partition number you need (e.g. 2,4,etc.)")"
 p="$(echo $p | tr "|" " ")"

echo $p | sed 's/,/\n/g' > $outputdir/parts_chosen.txt
mmls $imm | grep ^[0-9] | grep '[[:digit:]]'| awk '{print $3,$4}' > $outputdir/mmls.txt

cn=0
cat $outputdir/parts_chosen.txt | while read lineparts
do
cl=$(( $lineparts+1 ))
cat $outputdir/mmls.txt | while read line
do
cn=$(( cn+1 ))
if [ "$cn" = "$cl" ] 
then
pts=$(echo $p | awk -F, '{print $cn}')
startsect0=$(echo $line | awk '{print $1}')
so=$(echo "$startsect0" | bc)
endsect0=$(echo $line | awk '{print $2}')
endsect=$(echo "$endsect0" | bc)
endoff=$(($endsect * 512 | bc))
	
  [[ ! -d $outputdir/$lineparts/ ]] && mkdir $outputdir/$lineparts/
BASE_IMG=$outputdir/$lineparts            # mounting directory

[[ ! -d $BASE_IMG ]] && mkdir -p $BASE_IMG

off=$(( $so * 512 ))

cn=$(($cl))
 if [ "$(fsstat -o $so $imm | grep -i NTFS)" ] 
	   then
            NTFS_OPTS="show_sys_files,streams_interface=windows,allow_other"
        mount -t auto -o ro,loop,offset=$off,$NTFS_OPTS,noauto,noexec,nodev,noatime,umask=222 $imm $BASE_IMG >/dev/null 2>&1 && {
yad  --width 600 \--title "ImgMount" --text "Image file mounted in '$BASE_IMG'"
echo "Image file mounted in '$BASE_IMG'"
}
        else 
        mount -t auto -o ro,loop,noauto,noexec,nodev,noatime,offset=$off,umask=222 $imm $BASE_IMG >/dev/null 2>&1 && {
yad  --width 600 \--title "ImgMount" --text "Image file mounted in '$BASE_IMG'"
echo "Image file mounted in '$BASE_IMG'"
}
		fi

fi
done
done
rm $outputdir/parts_chosen.txt
rm $outputdir/mmls.txt
#[[ "$ITYPE" = "ewf" ]] && umount $MNTPNT
#[[ -d $MNTPNT ]] && rm  -r $MNTPNT

if [ $? == 0 ]; then
	yad  --width 600 \--title "ImgMount" --text "Operation succeeded!\n\nYour data are here  $outputdir"
else
	yad --width 600 --title "ImgMount" --text "ImgMount encountered errors.\n\nPlease check your settings and try again"
fi
echo "Done!";
}
