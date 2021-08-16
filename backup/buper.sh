#!/bin/bash

set_envs(){
  if [ -z "$STORAGE_URL" ]; then
    read -r -p "set STORAGE_URL env: " STORAGE_URL
  fi
  if [ -z "$AWS_ACCESS_KEY_ID" ]; then
    read -r -p "set AWS_ACCESS_KEY_ID env: " AWS_ACCESS_KEY_ID
  fi
  if [ -z "$AWS_SECRET_ACCESS_KEY" ]; then
    read -r -s -p "set AWS_SECRET_ACCESS_KEY env: " AWS_SECRET_ACCESS_KEY; echo
  fi
  if [ -z "$RESTIC_PASSWORD" ]; then
    read -r -s -p "set RESTIC_PASSWORD env: " RESTIC_PASSWORD; echo
  fi
  BUPER_PATH="/etc/cron.d/buper"
}
get_string_envs(){
  echo "-e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY \
        -e RESTIC_REPOSITORY=s3:$STORAGE_URL -e RESTIC_PASSWORD=$RESTIC_PASSWORD"
}
init_restic_repo(){
  docker run --rm $(get_string_envs) restic/restic init &>/dev/null
}
initialize(){
  set_envs
  init_restic_repo
}
error_echo(){
  >&2 echo -e "\e[01;31m$1\e[0m";
}

initialize

job="$1";
shift

case "$job" in
  ls|list)
    docker run --rm $(get_string_envs) restic/restic snapshots
    ;;
  a|add)
    if [[ -z $* ]]; then
      error_echo "Set directories to be backed up in commandline arguments."
      error_echo "   ./buper.sh add /path/to/dir1 [/path/to/dir2 ...] "
      exit 1
    fi

    volumes=""
    for arg; do volumes+="-v $arg:$arg "; done

    if [[ -f $BUPER_PATH ]] && [[ $(cat $BUPER_PATH) == *backup* ]]; then
      sed -i -r 's~(2>>)~'"$*"' \1~g' $BUPER_PATH
      sed -i -r 's~(-v .+[\s]*)(restic\/restic)~\1 '"$volumes"' \2~g' $BUPER_PATH
    else
      rm -f $BUPER_PATH;
      echo "* * * * * root docker run --rm $(get_string_envs) \
      $volumes restic/restic backup --host $(hostname) $* 2>>/tmp/buper_cronlogs" >$BUPER_PATH
    fi
    ;;
  rm|remove)
    if [[ -z $* ]] || [[ $# -ne 1 ]]; then
      error_echo "Set ONE directory to remove."
      error_echo "   ./buper.sh rm /path/to/dir1"
      exit 1
    fi

    if [[ -f $BUPER_PATH ]] && [[ $(grep -o "\-v" $BUPER_PATH | wc -l) -eq 1 ]]; then
      rm -f $BUPER_PATH
    elif [[ -f $BUPER_PATH ]] && [[ $(cat $BUPER_PATH) == *backup* ]]; then
      sed -i -r 's~[ ]+-v '"$1"':'"$1"'[ ]+~ ~g' $BUPER_PATH
      sed -i -r 's~[ ]+'"$1"'[ ]+~ ~g' $BUPER_PATH
    else
      echo "Done. No backup in progress to be removed."
    fi
    ;;
  forget)
    if [[ $1 == "--all" ]]; then
      docker run --rm $(get_string_envs) restic/restic snapshots | \
        cut -d' ' -f1 | head -n -2 | tail -n +4 | sed -r '/^\s*$/d' | \
        xargs docker run --rm $(get_string_envs) restic/restic forget -
    else
      docker run --rm $(get_string_envs) restic/restic forget "$@"
    fi
    ;;
  stop)
    rm -f $BUPER_PATH
    ;;
  restore)
    docker run --rm $(get_string_envs) restic/restic restore "$@"
    ;;
  *)
    echo "help"
    ;;
esac
