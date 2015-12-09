#!/bin/bash
#
# 工作目录
#
WORK_DIR=/home/www/userops/user-mobile-config
#WORK_DIR=/home/www/userops/whoops
#
# ansible host文件
#
HOST_FILE=hosts
#
# ansible config目录
#
ANSI_DIR=/home/www/userops/daily_ops_tool

#
# 存在merger_request
#
function has_merger_request(){
    read -p "has merge request?([y]/n): "
    if [ "$REPLY" != "n" ]; then
        git pull --rebase origin master
    fi
}

#
# PHP语法检查
#
function check_php_syntax() {
    fileList=`find $WORK_DIR |grep 'php'`
    for file in $fileList
    do  
    php -l $file 
#> /dev/null 2>&1
    if [[ $? -ne 0 ]]; then
        echo ${file}
        echo 'php config must be syntax error.'
        echo 'Bye'
        exit 1
    fi  
    done
    echo 'php syntax check is ok.'
}

#
# 输出所有配置改动
#
function display_changes() {
    git status
    git add --all &> /dev/null
    if [[ $? -eq 0 ]]; then
        git diff HEAD --name-status
        git diff HEAD
    else
        echo 'Not a git repository.'
        echo 'Bye'
        exit 1
    fi
}
#
# 确认提交，git提交本地更改，并同步到其他应用服务器
#
function ensure_commit() {
    NOTHING="nothing to commit (working directory clean)"
    if [[ $(git status|grep "$NOTHING") == "" ]]; then
        read -p "Commit the changes?([y]/n): "
        if [ "$REPLY" != "n" ]; then
            read -p "Enter the comments: "
            while [[ "$REPLY" == "" ]]; do
                read -p "Enter the comments: "
            done
            echo "Commiting the changes..."
           git add .
           git commit -m "$REPLY" -a
           git pull --rebase origin master
           git push origin master
           ansible-playbook -i ${ANSI_DIR}/${HOST_FILE} ${ANSI_DIR}/config-mobile.yaml -vv
           ensure_error
        else
            echo "Only the current configures has been changed."
        fi
    else
        echo "No configuration has been changed."
        read -p "Already sync?([y]/n): "
        if [ "$REPLY" != "n" ]; then
            ansible-playbook -i ${ANSI_DIR}/${HOST_FILE} ${ANSI_DIR}/config-mobile.yaml -vv
        fi
    fi
}

#
# 回滚到上次版本
# 以后可以考虑输出版本列表，回滚到任意版本
#
function revert_config() {
    echo "Reverting the config..."
    git revert HEAD --no-edit
    git push origin master
    ansible-playbook -i ${ANSI_DIR}/${HOST_FILE} ${ANSI_DIR}/config-mobile.yaml -vv
}
#
# 确认错误
#
function ensure_error() {
    echo "Please check the log file for system error."
    read -p "Is there any error?(y/[n]): "
    if [ "$REPLY" == "y" ]; then
        echo "I'll revert the configure to last commit."
        revert_config
    fi
    echo "It's done. Bye!"
}
function welcome() {
#############################################################################\n\
# 线上配置提交同步脚本\n\
# git控制配置版本，可以一键还原\n\
# 作者：张弦\n\
# 日期：2013-2-18\n\
#############################################################################\n\
echo -e "\
使用git来跟踪配置脚本，出现紧急情况时可以回滚配置。\n\
首先脚本会显示你对配置文件做出的改动，\n\
然后提交更改，同步配置（此处会同步所有文件到所有机器），\n\
最后要求你确认是否有错误，如果有错误则会自动回滚到之前的版本并抛弃所有改动。\n\n\
如果没有错误则整个过程结束。\n\
\
未尽适宜请联系kakie。\n\
"
read -p "Press [Enter] key to continue."
}
#
# 主程序
#
cd $WORK_DIR
if [ $# -eq 0 ]; then
    welcome
    has_merger_request
    check_php_syntax
    display_changes
    ensure_commit
fi
