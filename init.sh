#!/usr/bin/env bash

# 变量声明
# 1.配置文件
CONFIG_FILE="config.txt"

# 函数声明
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
	if [ -z "$IF_DOCKER" ]; then
  		echo "配置文件中缺少IF_DOCKER配置项！"
  		exit 1
	fi
	if [ -z "$DATABASES_NAME" ]; then
  		echo "配置文件中缺少DATABASES_NAME配置项！"
  		exit 1
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
	touch "$MYSQL_BACKUP_SCRIPT_NAME.sh"
	#向文件中写入内容
	cat << EOF > "$MYSQL_BACKUP_SCRIPT_NAME.sh"
#!/bin/usr/env bash

DATABASES=(${DATABASES_NAME[@]})
MYSQL_USERNAME=$MYSQL_USERNAME
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_CONTAINER_NAME=$MYSQL_CONTAINER_NAME
BACKUP_ROOT=$BACKUP_ROOT
BACKUP_FILEDIR=$BACKUP_ROOT/data
MYSQLDUMP_DIRECTORY=$MYSQLDUMP_DIRECTORY

EOF

	cat << 'EOF' >> "$MYSQL_BACKUP_SCRIPT_NAME.sh"

#获取当前日期
DATE=$(date +%Y%m%d)

#备份命令
mkdir -p /app/mysqlbak/data/$DATE

#需要备份的数据表配置
#DATABASES=(${DATABASES_NAME[@]})

#备份数据表
for DB in "${DATABASES[@]}"
do
        # 执行备份命令
        $MYSQLDUMP_DIRECTORY -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --default-character-set=utf8 --hex-blob "$DB" > "$BACKUP_FILEDIR/$DATE/${DB}_${DATE}.sql"
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
	chmod +x "$MYSQL_BACKUP_SCRIPT_NAME.sh"

}


# 4.MySQL备份脚本创建(Docker)
create_MySQL_backup_docker_script() {
	touch "$MYSQL_BACKUP_SCRIPT_NAME.sh"
	#向文件中写入内容
	cat << EOF > "$MYSQL_BACKUP_SCRIPT_NAME.sh"
#!/bin/usr/env bash

DATABASES=(${DATABASES_NAME[@]})
MYSQL_USERNAME=$MYSQL_USERNAME
MYSQL_PASSWORD=$MYSQL_PASSWORD
MYSQL_CONTAINER_NAME=$MYSQL_CONTAINER_NAME
BACKUP_ROOT=$BACKUP_ROOT
BACKUP_FILEDIR=$BACKUP_ROOT/data
MYSQLDUMP_DIRECTORY=$MYSQLDUMP_DIRECTORY

EOF

	cat << 'EOF' >> "$MYSQL_BACKUP_SCRIPT_NAME.sh"

#获取当前日期
DATE=$(date +%Y%m%d)

#备份命令
mkdir -p /app/mysqlbak/data/$DATE

#需要备份的数据表配置
#DATABASES=(${DATABASES_NAME[@]})

#备份数据表
for DB in "${DATABASES[@]}"
do
        # 执行备份命令
        docker exec "$MYSQL_CONTAINER_NAME" $MYSQLDUMP_DIRECTORY -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --default-character-set=utf8 --hex-blob "$DB" > "$BACKUP_FILEDIR/$DATE/${DB}_${DATE}.sql"
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
	chmod +x "$MYSQL_BACKUP_SCRIPT_NAME.sh"

}



# 具体调用
# 调用解析配置文件函数
parse_config_file "$CONFIG_FILE"

# 调用检查必要参数配置函数
check_required_params

# 决策生成对应的数据备份脚本
if [ "$IF_DOCKER" = 1 ] 
then
	echo "此时创建的mysql数据备份脚本【docker版本】"
	# 创建MYSQL备份脚本【docker】
    create_MySQL_backup_docker_script
else
	echo "此时创建的mysql数据备份脚本【基础版本】"
	# 创建MYSQL备份脚本【基础版本】
	create_MySQL_backup_script
fi



for v in "${DATABASES_NAME[@]}";
do
	echo "当前备份的数据库详情:$v"
done

# 执行MySQL备份脚本文件
# bash $MYSQL_BACKUP_SCRIPT_NAME.sh

# 打印成功消息
echo "初始化完成"


