# MySQL线上数据备份脚本

## 一、前言

### 1.1 说明

文章是对使用Shell脚本实现MySQL线上数据备份的方式进行探究和学习，并实践应用。

该脚本工具用于对线上或本地MySQL数据库中的数据进行备份处理。

相关脚本可以通过github获取：[github地址](https://github.com/Bananayjy/scripts/tree/MySQL_BackUp_Script)

### 1.2 参考文章

- [MySQL——使用mysqldump备份与恢复数据](https://blog.csdn.net/DreamEhome/article/details/133580992)

### 1.3 前置知识点

#### 1. mysqldump

>  mysqldump命令可以将数据库中指定或所有的库、表导出为SQL脚本。表的结构和表中的数据将存储在生成的SQL脚本中。
>
> mysqldump备份恢复原理：通过先查出需要备份的库及表的结构，在SQL脚本中生成CREATE语句。然后将表中的所有记录转换成INSERT语句并写入SQL脚本中。这些CREATE语句和INSERT语句都是还原时使用的：还原数据时可使用其中的CREATE语句来创建表，使用INSERT语句还原数据。
>

**基本的备份用法：**

- 备份整个数据库

```shell
mysqldump -u username -p database_name > backup_file.sql
```

这将备份名为 `database_name` 的整个数据库，并将结果输出到名为 `backup_file.sql` 的文件中。`-u` 选项用于指定用户名，`-p` 选项提示用户输入密码

- 备份特定表

```shell
mysqldump -u username -p database_name table_name > backup_file.sql
```

这将备份名为 `database_name` 的数据库中名为 `table_name` 的表，并将结果输出到 `backup_file.sql` 文件中。

- 仅备份数据，不包括表结构

```shell
mysqldump -u username -p --no-create-info database_name > backup_file.sql
```

这将仅备份数据库中的数据，不包括表的结构信息

- 仅备份表结构，不包括数据

```shell
mysqldump -u username -p --no-data database_name > backup_file.sql
```

这将仅备份数据库中的表结构，不包括数据



**恢复的基本用法：**

- 恢复数据库

语法：`mysql -u[用户名] -p[密码] < /备份文件路径/备份文件名.sql`

示例：

```shell
#还原数据库
mysql -uroot -p123456 < backup_file.sql
```

- 恢复数据表

语法：`mysqldump -u[用户名] -p[密码] [database] < /备份文件路径/备份文件名.sql`

注意：恢复表的前提是表所在的库必须存在，且可任意指定库进行恢复操作

示例：

```shell
mysql -u root -p123456 database_name < backup_file.sql
```



#### 2. 关于`#!/usr/bin/env bash`和`#!/usr/bin/bash`说明

**`#!/usr/bin/env bash`**

- 这行告诉系统在哪里找到`bash`解释器，并使用它来执行脚本。
- `/usr/bin/env`是一个用来在PATH环境变量指定的目录中查找并执行程序的工具。
- `bash`是Bourne Again Shell的缩写，是Unix和Linux系统中一个常见的命令行解释器和脚本语言。

优点：

- 可以确保在不同系统上能够找到正确的`bash`解释器路径，因为`env`命令会在PATH中查找，而不是依赖于固定的路径。
- 更加灵活，不需要依赖于固定的安装路径。

缺点：

- 可能稍微慢一点，因为每次执行脚本时都要运行`env`来查找`bash`。
- 有些较老或者特殊的系统可能没有`/usr/bin/env`命令。

**`#!/usr/bin/bash`**

- 这行直接指定了`bash`解释器的路径，通常是在Unix和Linux系统中的典型安装位置之一。
- 如果确保系统中`bash`的路径不会改变，这种方式也是有效的。

优点：

- 明确指定了`bash`的路径，可以直接调用。

缺点：

- 可能会因为路径不一致而在某些系统上出现问题，尤其是在不同的发行版或操作系统版本中。
- 不够灵活，如果`bash`的安装路径变化，脚本可能会失效。

## 二、备份数据库shell脚本

### 2.1 功能支持

- 该脚本用于linux环境下的MySQL数据备份
- 通过配置文件（config.txt）自动生成对应的备份脚本/清除备份数据脚本
- 支持数据库全量数据的备份（目前未支持到数据表）
- 支持普通MySQL的数据库数据备份
- 支持Docker部署MySQL的数据库数据备份
- 支持定时调用备份脚本/清除备份数据脚本

### 2.2 使用说明

本脚本只支持在linux环境上使用

获取init.sh和config.txt文件后，将其放到对应的linux虚拟机中任意目录中

为两个文件添加权限

```
sudo chmod +x init.sh
sudo chmod +x config.txt
```

按照自己的需求修改config.txt中的参数，各参数示例如下

```txt
# MYSQL用户名
MYSQL_USERNAME=root
# MYSQL密码
MYSQL_PASSWORD=Cc123@leo
# MYSQL备份脚本名称
MYSQL_BACKUP_SCRIPT_NAME=MySQL_BASE_BACKUP
# MYSQLDUMP目标位置 【如果是docker部署，使用容器内的mysqldump地址】
MYSQLDUMP_DIRECTORY=/usr/bin/mysqldump
# MYSQL容器名称 【docker部署需要配置】
MYSQL_CONTAINER_NAME=mysql
# mysql是否是docker部署 【0：否 1：是】
IF_DOCKER=0
# 需要备份的数据库名称
DATABASES_NAME=(database1 database2)
# 生成脚本、日志、备份数据目标地址（需要是绝对路径）
DEST_DIR=/app/mysqlbak
# 清除备份日志时间间隔(单位：天)
CLEAR_CYCLE=7
# 是否自动配置定时任务执行 【0：否 1：是】
ENABLE_SCHEDULED_TASKS=1
# 定时执行的cron表达式
CRON='00 5 * * *'
```

在init.sh目录下，执行脚本命令，生成备份脚本和清除备份数据的脚本，并根据配置文件决定是否配置定时调用

```
bash init.sh
```

在生成脚本的目录下，手动使用如下命令执行生成的脚本文，备份mysql数据库

```
bash {生成的备份脚本的名称}.sh
```

使用如下命令执行生成的清除日志脚本

```
bash MySQL_Clear.sh
```

如果后续想要添加定时执行，可以按照如下方法进行配置（也可以直接在配置文件中设置ENABLE_SCHEDULED_TASKS为1，自动完成定时执行配置的添加）

```
//加入计划任务
crontab -e

00 5 * * * 【脚本位置】 > 【日志打印】 2>&1

// 示例
crontab -e

00 5 * * * /app/mysqlbak/scripts/backup.sh > /app/mysqlbak/logs/backup.log 2>&1
```



### 2.2 脚本详情

#### 1. 初始化

- 配置文件config.txt （默认名称为config.txt，可在init.sh初始化脚本中选择修改配置文件名称）

用于对一些配置参数进行声明，各个参数的信息如下所示

```txt
# MYSQL用户名
MYSQL_USERNAME=root
# MYSQL密码
MYSQL_PASSWORD=Cc123@leo
# MYSQL备份脚本名称
MYSQL_BACKUP_SCRIPT_NAME=MySQL_BASE_BACKUP
# MYSQLDUMP目标位置 【如果是docker部署，使用容器内的mysqldump地址】
MYSQLDUMP_DIRECTORY=/usr/bin/mysqldump
# MYSQL容器名称 【docker部署需要配置】
MYSQL_CONTAINER_NAME=mysql
# mysql是否是docker部署 【0：否 1：是】
IF_DOCKER=0
# 需要备份的数据库名称
DATABASES_NAME=(database1 database2)
# 生成脚本、日志、备份数据目标地址（需要是绝对路径）
DEST_DIR=/app/mysqlbak
# 清除备份日志时间间隔(单位：天)
CLEAR_CYCLE=7
# 是否自动配置定时任务执行 【0：否 1：是】
ENABLE_SCHEDULED_TASKS=1
# 定时执行的cron表达式
CRON='00 5 * * *'
```

- 初始化init.sh脚本内容，用于根据配置文件`config.txt`中声明的配置，生成对应的MYSQL备份脚本

```shell
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



```

#### 2. 正常部署的MySQL实现数据库的备份脚本详情示例

```shell
#!/usr/bin/env bash

DATABASES=(database1 database2)
MYSQL_USERNAME=root
MYSQL_PASSWORD=123456
MYSQL_CONTAINER_NAME=mysql
BACKUP_ROOT=/app/mysqlbak/banana
BACKUP_FILEDIR=/app/mysqlbak/banana/data
MYSQLDUMP_DIRECTORY=/usr/bin/mysqldump


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

```

#### 3. Docker部署的MySQL实现数据库的备份脚本详情示例

```shell
#!/usr/bin/env bash

DATABASES=(database1 database2)
MYSQL_USERNAME=root
MYSQL_PASSWORD=123456
MYSQL_CONTAINER_NAME=mysql8
BACKUP_ROOT=/app/mysqlbak/banana
BACKUP_FILEDIR=/app/mysqlbak/banana/data
MYSQLDUMP_DIRECTORY=/usr/bin/mysqldump


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

```

#### 4.定时清除脚本示例

```shell
#!/usr/bin/env bash

BACKUP_ROOT=/app/mysqlbak/banana
BACKUP_FILEDIR=/app/mysqlbak/banana/data
CLEAR_CYCLE days=7


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


```

