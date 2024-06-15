# 脚本实现MySQL线上数据备份

## 一、前言

### 1.1 说明

文章是对使用Shell脚本实现MySQL线上数据备份的方式进行探究和学习。

Shell脚本用于线上或本地MySQL数据库中对数据进行备份处理的shell脚本。

相关脚本可以通过如下方式获取：

- [github地址](https://github.com/Bananayjy/scripts/tree/MySQL_BackUp_Script)

### 1.2 参考文章

> [MySQL——使用mysqldump备份与恢复数据](https://blog.csdn.net/DreamEhome/article/details/133580992)

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

### 2.1 使用说明

本脚本只支持在linux环境上使用

获取init.sh和config.txt文件后，将其放到对应的linux虚拟机中

为两个文件添加权限

```
sudo chmod +x init.sh
sudo chmod +x config.txt
```

按照自己的需求修改config.txt中的参数

在init.sh目录下，执行脚本命令

```
bash init.sh
```

执行完脚本后会生成对应的脚本文件

如果想要添加定时执行，可以按照如下方法执行

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
MYSQL_USERNAME=yjy
# MYSQL密码
MYSQL_PASSWORD=123456
# MYSQL备份脚本名称
MYSQL_BACKUP_SCRIPT_NAME=MySQL_BASE_BACKUP
# MYSQLDUMP目标位置
MYSQLDUMP_DIRECTORY=/nfadata/engine/mysql/bin/mysqldump
# MYSQL容器名称
MYSQL_CONTAINER_NAME=mysql
# 是否基于docker部署Mysql
IF_DOCKER=1
# 数据库名称
DATABASES_NAME=(hsx hsx2)
# 备份目标地址
BACKUP_ROOT=/app/mysqlbak

```

- 初始化init.sh脚本内容，用于根据配置文件`config.txt`中声明的配置，生成对应的MYSQL备份脚本

```shell
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


```

#### 2. 正常部署的MySQL实现数据库的备份脚本详情示例

```shell
#!/bin/bash

#备份目录路径
BACKUP_ROOT=/app/mysqlbak
BACKUP_FILEDIR=$BACKUP_ROOT/data

#容器名称
CONTAINER_NAME="mysql"

#MYSQL配置
MYSQL_USER="root"
MYSQL_PASSWORD="Cc123@leo"

#获取当前日期
DATE=$(date +%Y%m%d)

#备份命令
mkdir -p /app/mysqlbak/data/$DATE

#需要备份的数据表配置
DATABASES=("hsx_config" "hsx")

#备份数据表
for DB in "${DATABASES[@]}"
do
        # 执行备份命令
        /nfdata/engine/mysql/bin/mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --default-character-set=utf8 --hex-blob "$DB" > "$BACKUP_FILEDIR/$DATE/${DB}_${DATE}.sql"
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
#!/usr/bin/bash

#备份目录路径
BACKUP_ROOT=/app/mysqlbak
BACKUP_FILEDIR=$BACKUP_ROOT/data

#容器名称
CONTAINER_NAME="mysql"

#MYSQL配置
MYSQL_USER="root"
MYSQL_PASSWORD="Cc123@leo"

#获取当前日期
DATE=$(date +%Y%m%d)

#备份命令
mkdir -p /app/mysqlbak/data/$DATE

#需要备份的数据表配置
DATABASES=("hsx_config" "hsx")

#备份数据表
for DB in "${DATABASES[@]}"
do
        # 执行备份命令
        docker exec "$CONTAINER_NAME" /usr/bin/mysqldump -u"$MYSQL_USER" -p"$MYSQL_PASSWORD" --default-character-set=utf8 --hex-blob "$DB" > "$BACKUP_FILEDIR/$DATE/${DB}_${DATE}.sql"
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



