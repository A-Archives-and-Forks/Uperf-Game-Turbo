#!/system/bin/sh
#
# Copyright (C) 2021-2022 Matt Yang
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

BASEDIR="$(dirname $(readlink -f "$0"))"
. $BASEDIR/pathinfo.sh
. $BASEDIR/libsysinfo.sh

# $1:error_message
abort() {
    echo "$1"
    echo "! Uperf installation failed."
    exit 1
}

# $1:file_node $2:owner $3:group $4:permission $5:secontext
set_perm() {
    chown $2:$3 $1
    chmod $4 $1
    chcon $5 $1
}

# $1:directory $2:owner $3:group $4:dir_permission $5:file_permission $6:secontext
set_perm_recursive() {
    find $1 -type d 2>/dev/null | while read dir; do
        set_perm $dir $2 $3 $4 $6
    done
    find $1 -type f -o -type l 2>/dev/null | while read file; do
        set_perm $file $2 $3 $5 $6
    done
}

install_uperf() {
    echo "- Finding platform specified config"
    echo "- ro.board.platform=$(getprop ro.board.platform)"
    echo "- ro.product.board=$(getprop ro.product.board)"

    local target
    local cfgname
    target="$(getprop ro.board.platform)"
    cfgname="$(get_config_name $target)"
    if [ "$cfgname" == "unsupported" ]; then
        target="$(getprop ro.product.board)"
        cfgname="$(get_config_name $target)"
    fi

    if [ "$cfgname" == "unsupported" ] || [ ! -f $MODULE_PATH/config/$cfgname.json ]; then
        abort "! Target [$target] not supported."
    fi

    echo "- Uperf config is located at $USER_PATH"
    mkdir -p $USER_PATH
    mv -f $USER_PATH/uperf.json $USER_PATH/uperf.json.bak
    cp -f $MODULE_PATH/config/$cfgname.json $USER_PATH/uperf.json
    [ ! -e "$USER_PATH/perapp_powermode.txt" ] && cp $MODULE_PATH/config/perapp_powermode.txt $USER_PATH/perapp_powermode.txt
    rm -rf $MODULE_PATH/config
    set_perm_recursive $BIN_PATH 0 0 0755 0755 u:object_r:system_file:s0
}
install_sfanalysis() {
    echo "❗❗❗❗❗❗❗❗❗❗"
    echo "❗ 即将为您安装uperf子模块sfanalysis"
    echo "❗ 此模块可能导致部分系统无法正常工作"
    echo "❗ 如果您不清楚这是干什么的或者不知道其风险请取消安装！"
    echo "❗❗❗❗❗❗❗❗❗❗"
    echo "❗ 单击音量上键即可确认安装（我想试试，就要安装)"
    echo "❗ 单击音量下键取消安装sfanalysis（推荐)"
    echo "❗❗❗❗❗❗❗❗❗❗"
    key_click=""
    while [ "$key_click" = "" ]; do
        key_click="$(getevent -qlc 1 | awk '{ print $3 }' | grep 'KEY_')"
        sleep 0.2
    done
    case "$key_click" in
        "KEY_VOLUMEUP")
            echo "❗您已确认安装，请稍候"
            echo "❗正在为您安装uperf子模块sfanalysis️"
            echo "❗若不幸出现问题，卡logo界面15秒后手动重启"
            echo "❗即可正常开机"
            magisk --install-module "$MODULE_PATH"/modules/sfanalysis-magisk.zip
            echo "* 已为您安装sfanalysis️❤️"
        ;;
        *)
            echo "❗已为您取消安装sfanalysis"
    esac
    rm -rf "$MODULE_PATH"/modules/sfanalysis-magisk.zip
}

get_value() {
   echo "$(grep -E "^$1=" "$2" | head -n 1 | cut -d= -f2)"
}

install_corp() {
    if [ -d "/data/adb/modules/unity_affinity_opt" ] || [ -d "/data/adb/modules_update/unity_affinity_opt" ]; then
        rm /data/adb/modules*/unity_affinity_opt
    fi
    CUR_ASOPT_VERSIONCODE="$(get_value ASOPT_VERSIONCODE "$MODULE_PATH"/module.prop)"
    asopt_module_version="0"
    if [ -f "/data/adb/modules/asoul_affinity_opt/module.prop" ]; then
        asopt_module_version="$(get_value versionCode /data/adb/modules/asoul_affinity_opt/module.prop)"
        echo "- AsoulOpt...current:$asopt_module_version"
        echo "- AsoulOpt...embeded:$CUR_ASOPT_VERSIONCODE"
        if [ "$CUR_ASOPT_VERSIONCODE" -gt "$asopt_module_version" ]; then
            
            echo "* 您正在使用旧版asopt️"
            echo "* Uperf Game Turbo将为您更新至模块内版本️"
            killall -9 AsoulOpt
            rm -rf /data/adb/modules*/asoul_affinity_opt
            echo "- 正在为您安装asopt"
            magisk --install-module "$MODULE_PATH"/modules/asoulopt.zip
        else
            echo "* 您正在使用新版本的asopt"
            echo "* Uperf Game Turbo将不予操作️"
        fi
    else
        echo "* 您尚未安装asopt"
        echo "* Uperf Game Turbo将尝试为您第一次安装️"
        killall -9 AsoulOpt
        rm -rf /data/adb/modules*/asoul_affinity_opt
        echo "- 正在为您安装asopt"
        magisk --install-module "$MODULE_PATH"/modules/asoulopt.zip
    fi
    rm -rf "$MODULE_PATH"/modules/asoulopt.zip
}

fix_module_prop() {
    mkdir -p /data/adb/modules/uperf/
    cp -f "$MODULE_PATH/module.prop" /data/adb/modules/uperf/module.prop
}

unlock_limit(){
if [[ ! -d $MODPATH/system/vendor/etc/perf/ ]];then
  dir=$MODPATH/system/vendor/etc/perf/
  mkdir -p $dir
fi

for i in ` ls /system/vendor/etc/perf/ `
do
  touch $dir/$i 
done
}

echo ""
echo "* 原模块地址 Uperf https://github.com/yc9559/uperf/"
echo "* Author: Matt Yang ❤️吟惋兮❤️改"
echo "* Version: Game Turbo1.24 based on uperf904"
echo "* 请不要破坏Uperf运行环境"
echo "* 模块会附带安装asopt和yc子模块sfanalysis"
echo "* "
echo "* 极速模式请自备散热，删除温控体验更佳"
echo "* 本模块与限频模块、部分优化模块冲突"
echo "* 模块可能与第三方内核冲突"
echo "* 请自行事先询问内核作者"
echo "* 请不要破坏Uperf Game Turbo运行环境!!!"
echo "* 请不要自行更改/切换CPU调速器!!!"
echo "* "
echo "* dnmd.leijun.MIUI.jinfan😅"
echo "* cnm.oneplus.ColorOS.lanshuai😅"
echo "* "
echo "* ❤️吟惋兮❤️"
echo "- 正在为您安装Uperf Game Turbo❤️"
install_uperf
#unlock_limit
echo "* Uperf Game Turbo安装成功❤️"
install_corp
echo "* asopt安装成功❤️"
install_sfanalysis
echo "* 重启即可"
echo "* 欢迎使用Uperf Game Turbo"
echo "* 祝体验愉快"
fix_module_prop