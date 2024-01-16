function autoscale_clonevm() {
    SRC=$1
    NAME=$2
    PROFILE=${3:-"/home/gandalf/workspace/cloud-recipe/base"}

    if [[ -z $SRC || -z $NAME ]]; then
            echo -e "clonevm <src> <tgt> (profile): \n\t<src> eg. 'tiniest-ubuntu-cloudinit'\n\t<tgt> eg. 'tiniest-ubuntu-cloudinit-abda'\n\t(profile) cloud-init-recipe (defaults=${PROFILE})"
        return 
    fi

    VBoxManage clonevm $SRC --name $NAME --register --options=Link --snapshot=snapshot-1

    COUNTER=0
    UDATA=$(cat ${PROFILE}/userdata.yml | base64)
    IDATA="local-hostname: ${NAME}"
    if [ -f ${PROFILE}/metadata.yml ]; then
        IDATA=$(cat ${PROFILE}/metadata.yml )
    fi
    MISSINGDATA=${#UDATA}
    SEGMENT=1000
    
    VBoxManage guestproperty set ${NAME} /VirtualBox/GuestInfo/userdata  "---"
    while [ $MISSINGDATA -gt 0 ]; do
        COUNT_KEY=$(VBoxManage guestproperty get ${NAME} /VirtualBox/GuestInfo/userdata|cut -d ':' -f 2- |tr -d ' ')

        VBoxManage guestproperty set ${NAME} /VirtualBox/GuestInfo/userdata$COUNTER "${UDATA:COUNTER*SEGMENT:SEGMENT}"
        VBoxManage guestproperty set ${NAME} /VirtualBox/GuestInfo/userdata$COUNTER.encoding "binary"

        if [ $COUNT_KEY == "---" ]; then
            VBoxManage guestproperty set ${NAME} /VirtualBox/GuestInfo/userdata "userdata$COUNTER"
        else
            VBoxManage guestproperty set ${NAME} /VirtualBox/GuestInfo/userdata "$COUNT_KEY:userdata$COUNTER"
        fi

        MISSINGDATA=$((MISSINGDATA-SEGMENT))
        COUNTER=$((COUNTER+1))
    done 
    
    VBoxManage guestproperty set ${NAME} /VirtualBox/GuestInfo/metadata "${IDATA}"
    VBoxManage guestproperty set ${NAME} /VirtualBox/GuestInfo/metadata.encoding "plain"
    VBoxManage guestproperty set ${NAME} /VirtualBox/GuestInfo/userdata.encoding "list"
    VBoxManage guestproperty set ${NAME} /VirtualBox/Tags/profile ${PROFILE}
    }

function autoscale_group_members_list() {
    GROUPPREFIX=$1
    if [[ -z $GROUPPREFIX ]]; then
       echo -e "$FUNCNAME <groupprefix>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba"
       return 
    fi

    local array=("")
    GROUP=$(vboxmanage list vms |  grep "$GROUPPREFIX" |  cut -d ' ' -f 2 | tr -d '"' | tr -d '{}')
    
    for i in $GROUP; do
        array+=(${i})
    done

    echo "${array[@]}"
}

function autoscale_count_vms() {
    GROUPPREFIX=$1
    if [[ -z $GROUPPREFIX ]]; then
       echo -e "$FUNCNAME <groupprefix>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba"
       return 
    fi
    local LIST=( $(autoscale_group_members_list ${GROUPPREFIX}) )
    echo ${#LIST[@]}
}

function autoscale_group_members_select_youngest() {
    GROUPPREFIX=$1
    if [[ -z $GROUPPREFIX ]]; then
       echo -e "$FUNCNAME <groupprefix>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba"
       return 
    fi
    
    declare -A children
    local LIST=( $(autoscale_group_members_list ${GROUPPREFIX}) )
    for VALE in ${LIST[@]}; do
        PROP=$(VBoxManage guestproperty get ${VALE} /VirtualBox/Autoscale/created)
        if [[ $PROP == "No value set!" ]]; then
            DATE=$(date +'%s')
            VBoxManage guestproperty set ${VALE} /VirtualBox/Autoscale/created ${DATE}
            children["$VALE"]=${DATE}
        else
            children["$VALE"]=$PROP
        fi
    done

    for k in "${!children[@]}"; do
        echo $k ${children["$k"]}
    done | sort -rn -k2 | tail -n 1 | cut -d ' ' -f 1 
}

function autoscale_group_members_select_oldest() {
    GROUPPREFIX=$1
    if [[ -z $GROUPPREFIX ]]; then
       echo -e "$FUNCNAME <groupprefix>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba"
       return 
    fi
    
    declare -A children
    local LIST=( $(autoscale_group_members_list ${GROUPPREFIX}) )
    for VALE in ${LIST[@]}; do
        PROP=$(VBoxManage guestproperty get ${VALE} /VirtualBox/Autoscale/created)
        if [[ $PROP == "No value set!" ]]; then
            DATE=$(date +'%s')
            VBoxManage guestproperty set ${VALE} /VirtualBox/Autoscale/created ${DATE}
            children["$VALE"]=${DATE}
        else
            children["$VALE"]=$PROP
        fi
    done

    for k in "${!children[@]}"; do
        echo $k ${children["$k"]}
    done | sort -rn -k2 | head -n 1 | cut -d ' ' -f 1
}

function autoscale_group_members_select_random() {
    GROUPPREFIX=$1
    if [[ -z $GROUPPREFIX ]]; then
       echo -e "$FUNCNAME <groupprefix>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba"
       return 
    fi
    
    declare -A children
    local LIST=( $(autoscale_group_members_list ${GROUPPREFIX}) )
    for VALE in ${LIST[@]}; do
        PROP=$(VBoxManage guestproperty get ${VALE} /VirtualBox/Autoscale/created)
        if [[ $PROP == "No value set!" ]]; then
            DATE=$(date +'%s')
            VBoxManage guestproperty set ${VALE} /VirtualBox/Autoscale/created ${DATE}
            children["$VALE"]=${DATE}
        else
            children["$VALE"]=$PROP
        fi
    done

    for k in "${!children[@]}"; do
        echo $k ${children["$k"]}
    done | sort -rn -k2 | head -n $RANDOM | tail -n 1 | cut -d ' ' -f 1
}

function autoscale_readonly_library() {
   GROUPPREFIX=$1
   if [[ -z $GROUPPREFIX ]]; then
       echo -e "$FUNCNAME <id>\n\t<id> e.g tiniest-ubuntu-cloudinit-abba"
       return 
   fi

   LIBRARY=".autoscale-$GROUPPREFIX.yml"

   if [ ! -f $LIBRARY ]; then
       touch $LIBRARY
   fi

   echo $LIBRARY
}

function autoscale_write_library() {
    GROUPPREFIX=$1
    VAR=$2
    if [[ -z $GROUPPREFIX ]]; then
        echo -e "$FUNCNAME <groupprefix> <key>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba\n\t<key> e.g. '.desired=2'"
        return 
    fi

    
    LIBRARY=$(autoscale_readonly_library $GROUPPREFIX)
    jq $VAR $LIBRARY > "tmp"  && mv "tmp" $LIBRARY
}

function autoscale_desired_set() {
   GROUPPREFIX=$1
   DESIRED=$2
   if [[ -z $GROUPPREFIX || -z $DESIRED ]]; then
       echo -e "$FUNCNAME <groupprefix> <desired>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba\n\t<desired> e.g. '2'"
       return 
   fi

   autoscale_write_library "$GROUPPREFIX" ".desired=$DESIRED"
}

function autoscale_min_set() {
   GROUPPREFIX=$1
   MIN=$2
   if [[ -z $GROUPPREFIX || -z $MIN ]]; then
       echo -e "$FUNCNAME <groupprefix> <MIN>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba\n\t<MIN> e.g. '2'"
       return 
   fi

   autoscale_write_library "$GROUPPREFIX" ".min=$MIN"
}

function autoscale_max_set() {
   GROUPPREFIX=$1
   MAX=$2
   if [[ -z $GROUPPREFIX || -z $MAX ]]; then
       echo -e "$FUNCNAME <groupprefix> <MAX>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba\n\t<MAX> e.g. '2'"
       return 
   fi

   autoscale_write_library "$GROUPPREFIX" ".max=$MAX"
}

function autoscale_profile_set() {
   GROUPPREFIX=$1
   PROFILE=$2
   if [[ -z $GROUPPREFIX || -z $PROFILE ]]; then
       echo -e "$FUNCNAME <groupprefix> <PROFILE>\n\t<groupprefix> e.g tiniest-ubuntu-cloudinit-abba\n\t<PROFILE> e.g. /home/gandalf/workspace/cloud-recipe/base"
       return 
   fi

   autoscale_write_library "$GROUPPREFIX" ".profile=\"$PROFILE\""
}

function autoscale_group_list() {
    local array=("")
    GROUP=$(ls .autoscale-*.yml)
    for i in $GROUP; do
        VM=${i#*-}
        array+=(${VM%.yml})
    done

    echo "${array[@]}"
}

autoscale_group_iterator_index=0
function autoscale_group_next() {
    local LIST=( $(autoscale_group_list) )
    listsize=${#LIST[@]}
    echo ${LIST[${autoscale_group_iterator_index}]}
    autoscale_group_iterator_index=$(( ($autoscale_group_iterator_index + 1 ) % $listsize ))
}

function instance_type() {
    TYPE=$1
    if [[ -z $TYPE ]]; then
            echo -e "$FUNCNAME <type>\n\t<type> e.g t1-small => 1 vcpus, 1 gb memory"
        return 
    fi

    if [[ $TYPE == "t1-small" ]]; then
        echo "1 1024"
        return
    fi

    if [[ $TYPE == "t1-medium" ]]; then
        echo "2 2048"
        return
    fi

    if [[ $TYPE == "t1-large" ]]; then
        echo "4 4096"
        return
    fi
    echo "1 1024"
}

function autoscale_group() {
    GROUPPREFIX=$1
    if [[ -z $GROUPPREFIX ]]; then
            echo -e "autoscale <groupprefix>\n\t<id> e.g tiniest-ubuntu-cloudinit-abba"
        return 
    fi
    
    LIBRARY=$(autoscale_readonly_library $GROUPPREFIX)
    VMDESIRED=$(jq -r .desired $LIBRARY) 
    VMMAX=$(jq -r .max $LIBRARY) 
    VMMIN=$(jq -r .min $LIBRARY) 

    # required
    VMSRC=$(jq -r .src $LIBRARY) 
    if [[ $VMSRC == "null" ]]; then
        VMSRC="tiniest-ubuntu-cloudinit"
    fi

    # required
    PROFILE=$(jq -r .profile $LIBRARY)
    if [[ $PROFILE == "null" ]]; then
        PROFILE="/home/gandalf/workspace/cloud-recipe/base"
    fi

    # required
    LIFECYCLE=$(jq -r .lifecyclestrategy $LIBRARY) 
     if [[ $LIFECYCLE == "null" ]]; then
        LIFECYCLE="oldest"
    fi

    # required
    VMTYPE=$(jq -r .instancetype $LIBRARY) 
    if [[ $VMTYPE == "null" ]]; then
        VMTYPE="t1-small"
    fi

    # if volumes is specified, then MAX becomes that.
    VOLUMES=$(jq -r .volumes $LIBRARY)
    if [[ $VOLUMES != "null" ]]; then
        VMMAX=$(jq -r '.volumes | length' $LIBRARY)
    fi

    # If vms is less than vmdesired, boot new ones, but never more than max.
    # At the same time, count the current VMS
    VM_MINIMUM=$(( $VMDESIRED > $VMMIN ? $VMDESIRED : $VMMIN ))
    VM_REQ=$(($VM_MINIMUM < $VMMAX ? $VM_MINIMUM: $VMMAX))
    VMS=$(autoscale_count_vms "$GROUPPREFIX")
  
    # How much off, on desired are we
    VM_MISSING=$(($VM_REQ-$VMS))
    while [[ ${VM_MISSING} -ne 0 ]]; do

        # Scale up (or out, but protect us against abuse)
        if [[ $VMS -lt $VM_REQ && $VMS -lt 8 ]]; then

            echo "scale up $VM_MISSING (cur: $VMS, desired: $VMDESIRED, min: $VMMIN, max: $VMMAX) of $GROUPPREFIX".

            # Make a name        
            NAME="$GROUPPREFIX-$(openssl rand -hex 2)"
            echo "* candidate: $NAME, profile: ${PROFILE}, instance-type: ${VMTYPE}"

            # Autoscaling-events, come here.
            autoscale_clonevm ${VMSRC} ${NAME} ${PROFILE}
            VBoxManage guestproperty set ${NAME} /VirtualBox/Autoscale/groupid ${GROUPPREFIX}
            VBoxManage guestproperty set ${NAME} /VirtualBox/Autoscale/created $(date "+%s")

            # ModifyVM-instance size.
            PARAM=( $(instance_type ${VMTYPE}))
            VBoxManage modifyvm ${NAME} --cpus ${PARAM[0]}
            VBoxManage modifyvm ${NAME} --memory ${PARAM[1]}

            # If disk, attach it
            #vboxmanage storageattach ${NAME} --storagectl SATA --port ${PORT} --type hdd --medium ${DISK}
            if [[ $VOLUMES != "null" ]]; then
                VOLUME=$(storage_first_available $LIBRARY)
                if [[ ! -z $VOLUME ]]; then
                    storage_attach_volume $NAME $VOLUME
                fi
            fi

            # Start the vm
            VBoxManage startvm ${NAME} --type=headless  
        fi

        # Scale down (or in, but only if more than one)
        if [[ $VMS -gt $VM_REQ && $VMS > 0 ]]; then
            # Select candidate by method
            VM_CANDIDATE=$(autoscale_group_members_select_$LIFECYCLE $GROUPPREFIX)

            # How many less than desired         
            echo "scale down $VM_MISSING (cur: $VMS, desired: $VMDESIRED, min: $VMMIN, max: $VMMAX) of $GROUPPREFIX, candidate: $VM_CANDIDATE, method: $LIFECYCLE.".
            VBoxManage controlvm $VM_CANDIDATE acpipowerbutton

            # Sleep 10
            sleep 10
            
            # If disk, attach it
            #vboxmanage storageattach ${NAME} --storagectl SATA --port ${PORT} --type hdd --medium ${DISK}
            if [[ $VOLUMES != "null" ]]; then
                VOLUME=$(storage_first_available $LIBRARY)
                if [[ -z $VOLUME ]]; then
                    storage_detach_volumes $NAME
                fi
            fi

            VBoxManage unregistervm $VM_CANDIDATE --delete-all               
        fi

        # recompute
        VMS=$(autoscale_count_vms "$GROUPPREFIX")
        VM_MISSING=$(($VM_REQ-$VMS))

        # sleep abit
        sleep 1
    done  
}

function autoscale_group_refresh() {
    local LIST=( $(autoscale_group_list) )
    for VALUE in ${LIST[@]}; do
        autoscale_group ${VALUE}
    done
}

function storage_attach_volume() {
    NAME=$1
    DISK=$2
    PORT=${3:-1}

    vboxmanage storageattach ${NAME} --storagectl SATA --port ${PORT} --type hdd --medium ${DISK}
}

function storage_detach_volumes() {
    NAME=$1
    PORT=${2:-1}
    vboxmanage storageattach ${NAME} --storagectl SATA --port $PORT --type hdd --medium none
}

function storage_first_available() {
    VOLUMES=$(jq -r '.volumes[]' $1)

    for VOLUME in ${VOLUMES}; do
        if [[ -f $VOLUME ]]; then
            INUSE=$(vboxmanage showmediuminfo disk $VOLUME | grep -i "in use" | wc -l)
            if [[ $INUSE -eq 0 ]]; then
                echo $VOLUME
                break
            fi
        fi
    done
}

# Notes
# Create a new medium: vboxmanage createmedium disk --filename ${DISK} --size 64 --format VDI --variant standard