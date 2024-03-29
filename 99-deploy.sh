#!/bin/sh
readonly envDef=ENV_DEF
readonly workspacePath=/workspace
readonly htmlPath=/usr/share/nginx/html

# 读取 NGX_WORKER_PROC 设置 nginx.conf 中 worker_processes
NGX_WORKER_PROC_CONF=$NGX_WORKER_PROCESSES
if [ -z $NGX_WORKER_PROCESSES ]; then
    NGX_WORKER_PROC_CONF=${NGX_WORKER_PROC:-"1"}
fi


strEnvReplace() {
  # 字符串环境变量替换
  envName=$1
  eval envValue="$"$1
  filename=$2

  echo "Replace $envName with $envValue in the $filename"
  if [ "$envValue" == '/' ]; then
    # /ENV_VAR_NAME/
    envVarAllMatch=$(cat $filename | grep -E "/$envName/" | sed s/[[:space:]]//g)
    if [ ! -z "$envVarAllMatch" ]; then
      # 执行替换
      sed -i "s#/$envName/#$envValue#g" $filename
    else
      # /ENV_VAR_NAME
      envVarLiftMatch=$(cat $filename | grep -E "/$envName" | sed s/[[:space:]]//g)
      if [ ! -z "$envVarLiftMatch" ]; then
        # 执行替换
        sed -i "s#/$envName#$envValue#g" $filename
      else
        # ENV_VAR_NAME/
        envVarRightMatch=$(cat $filename | grep -E "$envName/" | sed s/[[:space:]]//g)
        if [ ! -z "$envVarRightMatch" ]; then
          # 执行替换
          sed -i "s#$envName/#$envValue#g" $filename
        else
          # ENV_VAR_NAME
          # 执行替换
          sed -i "s#$envName#$envValue#g" $filename
        fi
      fi
    fi
  else
    # 正则：/ENV_VAR_NAME
    # 环境变量值：/envValue
    envVarLiftMatch=$(cat $filename | grep -E "/$envName" | sed s/[[:space:]]//g)
    envValueLiftMatch=$(echo "$envValue" | grep -E '^/' | sed s/[[:space:]]//g)
    if [  ! -z "$envVarLiftMatch" ] && [  ! -z "$envValueLiftMatch" ]; then
      # 去掉字符串开始的/
      envValue=$(echo "$envValue" | sed '1s#^/##')
    fi
    # 正则：ENV_VAR_NAME/
    # 环境变量值：envValue/
    envVarRightMatch=$(cat $filename | grep -E "$envName/" | sed s/[[:space:]]//g)
    envValueRightMatch=$(echo "$envValue" | grep -E '/$' | sed s/[[:space:]]//g)
    if [  ! -z "$envVarRightMatch" ] && [  ! -z "$envValueRightMatch" ]; then
      # 去掉字符串末尾的/
      envValue=$(echo "$envValue" | sed '1s#/$##')
    fi
    # 执行替换
    sed -i "s#$envName#$envValue#g" $filename
  fi
}

envReplace() {
  # $1: filepath
  # $2: envName
  for path in $(ls $1); do
    filename="$1/$path"
    if [ -d $filename ]; then
      # 如果是文件夹，递归替换
      envReplace $filename $2
    elif [ -f $filename ]; then
      # 替换.js .html文件
      case $filename in
      *.html)
        strEnvReplace $2 $filename
        ;;
      *.js)
        strEnvReplace $2 $filename
        ;;
      *.css)
        strEnvReplace $2 $filename
        ;;
      *.json)
        strEnvReplace $2 $filename
        ;;
      esac
    fi
  done
}

_main() {
  echo '>>>>>>>>>>>>>>>>>>>>>>>>>>> Deploy Start <<<<<<<<<<<<<<<<<<<<<<<<<<<<'
  # 删除上次替换好的html
  echo "Clean $htmlPath"
  rm -rf $htmlPath
  # 复制原始html到public目录
  echo "Copy $workspacePath to $htmlPath"
  cp -rf $workspacePath $htmlPath
  # 读取需要替换的环境变量列表，循环替换环境变量
  eval envList="$"$envDef
  if [ -z "$envList" ]; then
    echo "ENV_DEF not exists or is empty, Ignore!"
  else
    echo "ENV_DEF List: $envList"
    for envName in $envList ; do
        if [ ! -z "$envName" ]; then
            envReplace $htmlPath $envName
        fi
    done
  fi

  cp -f /etc/nginx/nginx.conf.tpl /etc/nginx/nginx.conf
  sed -i "s/NGX_WORKER_PROCESSES/$NGX_WORKER_PROC_CONF/g" /etc/nginx/nginx.conf
  echo "Config nginx work_processes: $NGX_WORKER_PROC_CONF"
  echo '>>>>>>>>>>>>>>>>>>>>>>>>>>> Deploy End <<<<<<<<<<<<<<<<<<<<<<<<<<<<'
}

# Start
_main "$@"