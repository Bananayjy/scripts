#!/usr/bin/env bash

# =============================变量声明=============================
# 1.配置文件名称（默认名称为config.txt）
CONFIG_FILE="config.txt"

# =============================函数声明=============================
# 1.解析配置文件函数
parse_config_file() {
	local file="$1"

	echo "开始解析配置文件【$CONFIG_FILE】……"

	# 检查配置文件是否存在
	if [[ ! -f $CONFIG_FILE ]]; then
        	echo "需要的配置文件【$CONFIG_FILE】不存在, 请先完成配置文件的配置!"
        	exit 1
	fi

	# 解析配置文件
	while IFS='=' read -r line;
	do
        	# 跳过注释和空行
        	if [[ ! $line =~ ^#.*$ ]] && [[ -n $line ]]; then
                	# 使用 eval 解析数组
                	eval "$line"
        	fi
	done < "$CONFIG_FILE"
	
	echo "解析配置文件【$CONFIG_FILE】成功！"
}

# 2.检查必要参数配置函数
check_required_params() {
	# 检查必要的参数变量是否进行配置
	if [ -z "$MYSQL_USERNAME" ]; then
  		echo "配置文件中缺少MYSQL_USERNAME配置项！"
  		exit 1
	fi
    if [ -z "$MYSQL_PASSWORD" ]; then
  		echo "配置文件中缺少MYSQL_PASSWORD配置项！"
  		exit 1
	fi
	if [ -z "$MYSQL_BACKUP_SCRIPT_NAME" ]; then
  		echo "配置文件中缺少MYSQL_BACKUP_SCRIPT_NAME配置项！"
  		exit 1
	fi
	if [ -z "$MYSQLDUMP_DIRECTORY" ]; then
  		echo "配置文件中缺少MYSQLDUMP_DIRECTORY配置项！"
  		exit 1
	fi
	if [ -z "$IF_DOCKER" ]; then
  		echo "配置文件中缺少IF_DOCKER配置项！"
  		exit 1
	fi
	if [ -z "$CLEAR_CYCLE" ]; then
  		echo "配置文件中缺少CLEAR_CYCLE配置项！"
  		exit 1
	fi
	if [ -z "$IF_DOCKER" ]; then
  		echo "配置文件中缺少IF_DOCKER配置项！"
  		exit 1
	fi
	if [ -z "$DEST_DIR" ]; then
  		echo "配置文件中缺少DEST_DIR配置项！"
  		exit 1
	fi
	if [ -z "$DATABASES_NAME" ]; then
  		echo "配置文件中缺少DATABASES_NAME配置项！"
  		exit 1
	fi
	if [ -z "$ENABLE_SCHEDULED_TASKS" ]; then
  		echo "配置文件中缺少ENABLE_SCHEDULED_TASKS配置项！"
  		exit 1
	fi
	# 如果启用了定时调用查看是否配置了cron
	if [ "$ENABLE_SCHEDULED_TASKS" = 1 ];then
		if [ -z "$CRON" ]; then
			echo "配置文件中缺少SCHEDULED_CRON配置项！"
			exit 1
		fi
  fi
	# 如果启用docker就查看是否配置了docker容器名称
  if [ "$IF_DOCKER" = 1 ];then
		if [ -z "$MYSQL_CONTAINER_NAME" ]; then
			echo "配置文件中缺少MYSQL_CONTAINER_NAME配置项！"
			exit 1
		fi
  fi
}

# 3.MySQL备份脚本创建(基本)
create_MySQL_backup_script() {
	echo "创建mysql数据备份脚本【基础版本】……"
	touch "$SCRIPTS_DIR/$MYSQL_BACKUP_SCRIPT_NAME.sh"
	#向文件中写入内容
	cat << EOF > "$SCRIPTS_DIR/$MYSQL_BACKUP_SCRIPT_NAME.sh"
#!/usr/bin/env bash

DATABASES=(${DATABASES_NAME[@]})
MYSQL_USERNAME=$MYSQL_USERNAME
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_CONTAINER_NAME=$MYSQL_CONTAINER_NAME
BACKUP_ROOT=$DEST_DIR
BACKUP_FILEDIR=$DATA_DIR
MYSQLDUMP_DIRECTORY=$MYSQLDUMP_DIRECTORY

EOF

	cat << 'EOF' >> "$SCRIPTS_DIR/$MYSQL_BACKUP_SCRIPT_NAME.sh"

#获取当前日期
DATE=$(date +%Y%m%d)

#备份命令
mkdir -p "$BACKUP_FILEDIR/$DATE"

#需要备份的数据表配置
#DATABASES=(${DATABASES_NAME[@]})

#备份数据表
for DB in "${DATABASES[@]}"
do
        # 执行备份命令
        $MYSQLDUMP_DIRECTORY -u"$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" --default-character-set=utf8 --hex-blob "$DB" > "$BACKUP_FILEDIR/$DATE/${DB}_${DATE}.sql"
        # 检查是否成功
        if [ $? -eq 0 ]; then
                echo "备份数据库 【$DB】 成功"
        else
                echo "备份数据库【$DB】 失败"
        fi

done


#打印任务结束
echo $DATE" done"
EOF

	#授予文件执行权限
	chmod +x "$SCRIPTS_DIR/$MYSQL_BACKUP_SCRIPT_NAME.sh"
	
	echo "创建mysql数据备份脚本【基础版本】成功！"

}


# 4.MySQL备份脚本创建(Docker)
create_MySQL_backup_docker_script() {
	echo "创建mysql数据备份脚本【docker版本】……"
	touch "$SCRIPTS_DIR/$MYSQL_BACKUP_SCRIPT_NAME.sh"
	#向文件中写入内容
	cat << EOF > "$SCRIPTS_DIR/$MYSQL_BACKUP_SCRIPT_NAME.sh"
#!/usr/bin/env bash

DATABASES=(${DATABASES_NAME[@]})
MYSQL_USERNAME=$MYSQL_USERNAME
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_CONTAINER_NAME=$MYSQL_CONTAINER_NAME
BACKUP_ROOT=$DEST_DIR
BACKUP_FILEDIR=$DATA_DIR
MYSQLDUMP_DIRECTORY=$MYSQLDUMP_DIRECTORY

EOF

	cat << 'EOF' >> "$SCRIPTS_DIR/$MYSQL_BACKUP_SCRIPT_NAME.sh"

#获取当前日期
DATE=$(date +%Y%m%d)

#备份命令
mkdir -p "$BACKUP_FILEDIR/$DATE"

#需要备份的数据表配置
#DATABASES=(${DATABASES_NAME[@]})

#备份数据表
for DB in "${DATABASES[@]}"
do
        # 执行备份命令
        docker exec "$MYSQL_CONTAINER_NAME" $MYSQLDUMP_DIRECTORY -u"$MYSQL_USERNAME" -p"$MYSQL_PASSWORD" --default-character-set=utf8 --hex-blob "$DB" > "$BACKUP_FILEDIR/$DATE/${DB}_${DATE}.sql"
        # 检查是否成功
        if [ $? -eq 0 ]; then
                echo "备份数据库 【$DB】 成功"
        else
                echo "备份数据库【$DB】 失败"
        fi

done


#打印任务结束
echo $DATE" done"
EOF

	#授予文件执行权限
	chmod +x "$SCRIPTS_DIR/$MYSQL_BACKUP_SCRIPT_NAME.sh"
	
	echo "创建mysql数据备份脚本【docker版本】成功！"

}


# 5.MySQL定时清除脚本创建
create_MySQL_Clear_script() {
	echo "创建mysql备份数据定时清除脚本……"
	touch "$SCRIPTS_DIR/MySQL_Clear.sh"
	#向文件中写入内容
	cat << EOF > "$SCRIPTS_DIR/MySQL_Clear.sh"
#!/usr/bin/env bash

BACKUP_ROOT=$DEST_DIR
BACKUP_FILEDIR=$DATA_DIR
CLEAR_CYCLE days=$CLEAR_CYCLE

EOF

cat << 'EOF' >> "$SCRIPTS_DIR/MySQL_Clear.sh"

DELETE_DATE=$(date -d "$CLEAR_CYCLE days ago" +%Y%m%d)
echo "当前删除任务的时间节点为：${DELETE_DATE}"

# 使用 find 命令删除早于 DELETE_DATE 的文件
find "$BACKUP_FILEDIR" -type d -regextype posix-extended -regex '.*/[0-9]{8}' | while read -r file; do
    file_date=$(basename "$file")
    if [[ "$file_date" < "$DELETE_DATE" ]]; then
        echo "Deleting $file"
        rm -r "$file"
    fi
done

# 完成日志
echo "当前删除任务的时间节点为: ${DELETE_DATE} 任务完成！"

EOF

	#授予文件执行权限
	chmod +x "$SCRIPTS_DIR/MySQL_Clear.sh"

	echo "创建mysql备份数据定时清除脚本成功！"
}

# 6.配置定时任务执行
configuring_Scheduled_Tasks() {
	echo "配置定时任务……"
	(crontab -l; echo "$CRON $SCRIPTS_DIR/$MYSQL_BACKUP_SCRIPT_NAME.sh > $LOGS_DIR/backup.log 2>&1 ") | crontab -
	(crontab -l; echo "$CRON $SCRIPTS_DIR/MySQL_Clear.sh > $LOGS_DIR/clear.log 2>&1 ") | crontab -
	echo "配置定时任务成功！"
}

# 7.初始化目录
init_dir() {
	echo "初始化目录……"
  mkdir -p "$DATA_DIR"
  echo "初始化目录$DATA_DIR"
  mkdir -p "$SCRIPTS_DIR"
  echo "初始化目录$SCRIPTS_DIR"
  mkdir -p "$LOGS_DIR"
	echo "初始化目录$LOGS_DIR"
	echo "初始化目录完成！"
}



# =============================具体调用=============================
echo "初始化……"
# 调用解析配置文件函数
parse_config_file "$CONFIG_FILE"

# 调用检查必要参数配置函数
check_required_params

# 备份数据目录
DATA_DIR="$DEST_DIR/data"
# 相关脚本目录
SCRIPTS_DIR="$DEST_DIR/scripts"
# 相关日志目录
LOGS_DIR="$DEST_DIR/logs"

# 初始化目录
init_dir

# 决策生成对应的数据备份脚本
if [ "$IF_DOCKER" = 1 ] 
then
	# 创建MYSQL备份脚本【docker】
  create_MySQL_backup_docker_script
else
	# 创建MYSQL备份脚本【基础版本】
	create_MySQL_backup_script
fi

# 生成定时清除脚本
create_MySQL_Clear_script

# 遍历打印当前备份的数据库详情
for v in "${DATABASES_NAME[@]}";
do
	echo "当前生成的脚本需要备份的数据库详情:$v"
done

# 开启了配置定时任务执行，就进行相关的配置
if [ "$ENABLE_SCHEDULED_TASKS" = 1 ] ; then
	configuring_Scheduled_Tasks
fi

# 执行MySQL备份脚本文件
# bash $MYSQL_BACKUP_SCRIPT_NAME.sh

# 打印成功消息
echo "初始化完成"


