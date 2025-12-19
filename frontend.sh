#!/bin/bash

USERID=$(id -u)
R="\e[31m"
G="\e[32m"
Y="\e[33m"
N="\e[0m"

LOGS_FOLDER="/var/log/roboshop-logs"
SCRIPT_NAME=$(echo $0 | cut -d "." -f1)
LOG_FILE="$LOGS_FOLDER/$SCRIPT_NAME.log"
SCRIPT_DIR=$PWD

mkdir -p $LOGS_FOLDER
echo "Script started executing at: $(date)" | tee -a $LOG_FILE

# Root check
if [ $USERID -ne 0 ]; then
    echo -e "$R ERROR:: Please run this script with root access $N" | tee -a $LOG_FILE
    exit 1
else
    echo "You are running with root access" | tee -a $LOG_FILE
fi

# Validate function
VALIDATE() {
    if [ $1 -eq 0 ]; then
        echo -e "$2 is ... $G SUCCESS $N" | tee -a $LOG_FILE
    else
        echo -e "$2 is ... $R FAILURE $N" | tee -a $LOG_FILE
        exit 1
    fi
}

# Disable default nginx
dnf module disable nginx -y &>>$LOG_FILE
VALIDATE $? "Disabling Default Nginx"

# Enable nginx 1.24
dnf module enable nginx:1.24 -y &>>$LOG_FILE
VALIDATE $? "Enabling Nginx:1.24"

# Install nginx
dnf install nginx -y &>>$LOG_FILE
VALIDATE $? "Installing Nginx"

# Remove default content
rm -rf /usr/share/nginx/html/* &>>$LOG_FILE
VALIDATE $? "Removing default content"

# Download frontend
curl -o /tmp/frontend.zip https://roboshop-artifacts.s3.amazonaws.com/frontend-v3.zip &>>$LOG_FILE
VALIDATE $? "Downloading frontend"

cd /usr/share/nginx/html
unzip /tmp/frontend.zip &>>$LOG_FILE
VALIDATE $? "Unzipping frontend"

# Replace nginx config BEFORE starting service
rm -f /etc/nginx/nginx.conf &>>$LOG_FILE
VALIDATE $? "Removing default nginx config"

cp $SCRIPT_DIR/nginx.conf /etc/nginx/nginx.conf &>>$LOG_FILE
VALIDATE $? "Copying custom nginx config"

# Validate nginx config
nginx -t &>>$LOG_FILE
VALIDATE $? "Validating nginx configuration"

# Enable & start nginx
systemctl daemon-reload &>>$LOG_FILE
systemctl enable nginx &>>$LOG_FILE
systemctl restart nginx &>>$LOG_FILE
VALIDATE $? "Starting Nginx"
